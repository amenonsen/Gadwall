# This controller deals with two situations:
#
# (a) a user must be given limited permission to perform some specific
# action without password authentication, e.g., resetting a forgotten
# password. We send them a one-time link with a signed token by email,
# and they can do whatever action the target of the link performs.
#
# (b) an authenticated user must reconfirm that they want to perform
# some sensitive action by providing information sent to them offline
# (e.g., by email or SMS).
#
# In both cases, we are making sure that the person making the request
# is the same as the user whose email address we have on file.

package Gadwall::Confirm;

use Mojo::Base 'Gadwall::Controller';

use Mojo::Util;
use MIME::Base64 qw(encode_base64);
use Gadwall::Util qw(hmac_md5_sum enqueue_mail);

# This bridge function allows access only if the request is accompanied
# by a valid confirmation token generated by us for this link and user.
# If the token has been tampered with (i.e. the signature is wrong), or
# if the token itself is invalid (most likely because it has been used
# already), or if the token has expired, it returns a 403 response.

sub by_url {
    my $self = shift;

    # Do we have a token with a valid signature?
    my $t = $self->param('t') || "";
    my ($tok, $sig) = split /:/, $t, 2;
    unless ($tok && $sig && $sig eq
            hmac_md5_sum($tok, $self->app->secrets->[0]))
    {
        return $self->denied;
    }

    my $dbh = $self->db;
    my $row;

    $dbh->begin_work;
    eval {
        local $dbh->{RaiseError} = 1;

        $row = $dbh->selectrow_hashref(<<"        SQL", {}, $tok);
            select path, user_id, remaining_uses, data,
                    age(current_timestamp,issued_at) > valid_for as expired
                from confirmation_tokens where token=?
                for update
        SQL

        if ($row) {
            unless ($row->{path} eq $self->req->url->path) {
                die "Invalid link path";
            }

            my $exp = $row->{expired} // 0;
            my $rem = $row->{remaining_uses} // 0;

            if (!$exp && $rem > 1) {
                $dbh->do(
                    "update confirmation_tokens ".
                    "set remaining_uses=remaining_uses-1 ".
                    "where token=?", {}, $tok
                );
            }
            elsif ($exp || $rem == 1) {
                $dbh->do(
                    "delete from confirmation_tokens where token=?", {}, $tok
                );
            }

            if ($exp) {
                $row = undef;
            }
        }

        $dbh->commit;
    };
    if ($@) {
        eval { $dbh->rollback };
        return $self->denied;
    }

    # We try to be lenient about using expired links.
    unless ($row) {
        return $self->expired;
    }

    # Can't find anything to complain about.
    $self->stash(user_id => $row->{user_id});
    $self->stash(link_data => $row->{data});
    return 1;
}

# This function takes a request URL and a user id and generates a link
# that the above bridge will accept.

sub generate_url {
    my ($self, $url, $uid, $data, $validity, $times) = @_;

    $validity //= 60;
    $times //= 1;

    my $path = $url->path;
    my $dbh = $self->db;

    # We delete any tokens for this (path,uid) combination that are more
    # than 15 minutes old and insert a new token. The insert may fail if
    # by some incredible chance the same pseudorandom value was inserted
    # earlier (if so, we retry with a different token), or if (much more
    # likely) there is a token for this (path,uid) that was *not* more
    # than 15 minutes old.

    my ($rv, $token);
    do {
        $dbh->begin_work;
        eval {
            local $dbh->{RaiseError} = 1;
            my $old = $dbh->do(
                "delete from confirmation_tokens where path=? and user_id=? ".
                "and age(current_timestamp,issued_at)>interval '15 minutes'",
                {}, $path, $uid
            );
            $token = encode_base64($main::prng->get_bits(128), "");
            $rv = $dbh->do(
                "insert into confirmation_tokens ".
                "(token, path, user_id, data, remaining_uses, valid_for) ".
                "values (?, ?, ?, ?, ?, (?||' minutes')::interval)",
                {}, $token, $path, $uid, $data, $times, $validity
            );
            $dbh->commit;
        };
        if ($@) {
            my $err = $dbh->errstr;
            eval { $dbh->rollback };
            return unless $err =~ /duplicate key.*confirmation_tokens_pkey/;
            $rv = undef;
        }
    }
    until defined $rv;

    my $link = $self->canonical_url('https', $path);
    $token .= ":".hmac_md5_sum($token, $self->app->secrets->[0]);
    $link->query->param(t => $token);

    return $link;
}

# This bridge allows POST requests through only if they are accompanied
# by a valid confirmation token. Otherwise it calls a method to send the
# token by some out-of-band means, and displays a form that asks for the
# token to be entered.

sub by_token {
    my $self = shift;
    my $dbh = $self->db;

    # Do we have a valid token for this request?
    my $t = $self->param('t');
    if ($t) {
        my $row = $dbh->selectrow_hashref(
            "delete from confirmation_tokens where token=? returning *, ".
            "age(current_timestamp,issued_at)>interval '15 minutes' as ".
            "expired", {}, $t
        );
        unless ($row && !$row->{expired} &&
                $row->{path} eq $self->req->url->path)
        {
            return $self->denied;
        }
        return 1;
    }

    # If not, we have to send a token to the user and ask for it in a
    # form that will recreate the current request when submitted.

    my $token = $self->generate_token;
    if ($token && !$self->send_token($token)) {
        if ($token) {
            $dbh->do(
                "delete from confirmation_tokens where token=?", {}, $token
            );
        }
        $self->render(
            template => "confirm/token-error",
            format => 'html'
        );
        return 0;
    }

    my $p = $self->req->params->to_hash;
    delete $p->{__token};

    my @hidden;
    foreach my $k (keys %$p) {
        my $v = $p->{$k};
        foreach my $val (@{ref $v ? $v : [$v]}) {
            Mojo::Util::xml_escape($val);
            push @hidden, qq{<input type=hidden name="$k" value="$val">};
        }
    }

    $self->render(
        template => "confirm/get-token",
        url => $self->req->url->path, hidden => \@hidden,
        format => 'html'
    );

    return 0;
}

# The next two functions are methods, but not actions.

# This function generates and returns a confirmation token for the
# current request.

sub generate_token {
    my $self = shift;

    my $dbh = $self->db;
    my $path = $self->req->url->path;
    my $user = $self->stash('user');
    my $uid = $user->{user_id};

    # Same basic strategy as generate_url above:
    #
    # We delete any tokens for this (path,uid) combination that are more
    # than 5 minutes old and insert a new token. The insert may fail if
    # the same token value was inserted earlier (if so, we retry with a
    # different value), or if (much more likely) there is a token for
    # this (path,uid) that was *not* more than 5 minutes old.

    my ($rv, $token);
    do {
        $dbh->begin_work;
        eval {
            local $dbh->{RaiseError} = 1;
            my $old = $dbh->do(
                "delete from confirmation_tokens where path=? and user_id=? ".
                "and age(current_timestamp,issued_at)>interval '5 minutes'",
                {}, $path, $uid
            );
            $token = join "", map {$main::prng->get_int(10)} 1..6;
            $rv = $dbh->do(
                "insert into confirmation_tokens (token, path, user_id) ".
                "values (?, ?, ?)", {}, $token, $path, $uid
            );
            $dbh->commit;
        };
        if ($@) {
            my $err = $dbh->errstr;
            eval { $dbh->rollback };
            return unless $err =~ /duplicate key.*confirmation_tokens_pkey/;
            $rv = undef;
        }
    }
    until defined $rv;

    return $token;
}

# This function takes a confirmation token and sends it to the logged-in
# user by some means (in this case, email).

sub send_token {
    my ($self, $token) = @_;

    my $host = $self->canonical_url->host;
    my $from = $self->config("owner_email");
    my $to = $self->stash('user')->{email};

    enqueue_mail(
        $self->app,
        from => $from, to => $to,
        subject => "Confirmation code for $host: $token",
        text => $self->render(
            template => "confirm/token-mail",
            from => $from, to => $to, host => $host, token => $token,
            format => 'txt', partial => 1
        )
    );

    $self->log->info("Sent confirmation token to $to");
    return 1;
}

sub expired {
    return shift->denied;
}

1;

__DATA__

@@ confirm/token-error.html.ep
% layout 'minimal', title => 'Confirmation error';
<p>
An error occurred while sending you the confirmation code for this
action. Please try again.

@@ confirm/get-token.html.ep
% layout 'minimal', title => 'Confirm action';
<p>
To proceed, you must enter a valid confirmation code in the form below.
The code has been sent to you by email.
<%= post_form $url => begin %>
<%== join "\n", @$hidden %>
<label for=t>Enter confirmation code:</label><br>
<%= text_field 't' %><br>
<%= submit_button 'Confirm' %>
<% end %>

@@ confirm/token-mail.txt.ep
Your confirmation code at <%= $host %> is the following number:

<%= $token %>

This code is valid for fifteen minutes.

--
Administrator
<%= $from %>
