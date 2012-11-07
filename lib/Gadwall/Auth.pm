# This controller handles user authentication, and provides login/logout
# actions. The login form can be changed by overriding the built-in data
# template "auth/login.html.ep" with a real file.

package Gadwall::Auth;

use Mojo::Base 'Gadwall::Controller';

use Gadwall::Util;

# This bridge function allows requests made over a secure channel to
# pass through. Otherwise, it issues a redirect to the HTTPS version
# of the request URL and returns 0.

sub allow_secure {
    my $self = shift;

    unless ($self->req->is_secure) {
        my $url = $self->req->url->clone;
        $url->scheme('https')->authority($url->base->authority);
        $self->render_plaintext("Redirecting to https");
        $self->redirect_to($url->to_abs);
        return 0;
    }

    return 1;
}

# This bridge function returns 1 only if there is an (already validated)
# session cookie that identifies a user. Otherwise it returns 0, thereby
# denying access to anything protected by the bridge. In the former case
# it stores a User object in the stash. In the latter case, it displays
# a login form.
#
# To require authentication to access /foo, you can do this:
#
# $auth = $r->bridge->to('auth#allow_users');
# $auth->route('/foo')->to(...);

sub allow_users {
    my $self = shift;

    # When authentication is involved, we'll have nothing to do with
    # requests that aren't explicitly identified as being over HTTPS.
    return 0 unless $self->allow_secure;

    my $user = $self->session('user');
    if ($user) {
        my $u = $self->table('Users')->select_by_key($user);
        if ($u) {
            $self->stash(user => $u);
            return 1;
        }
        $self->log->error("Can't load user $user despite valid cookie");
        $self->session(expires => 1);
    }

    my $source = $self->req->url;
    if ($source eq $self->url_for('logout')) {
        $self->flash(errmsg => $self->message('loggedout'));
        $self->redirect("/");
        return;
    }

    $self->session(source => $source->to_string);
    $self->session(token => Gadwall::Util->csrf_token());
    $self->render(
        status => 403,
        template => "auth/login", login => "",
        errmsg => $self->flash('errmsg') || undef
    );

    return 0;
}

# This bridge function, which depends on the above function to have run
# first and set stash('user'), allows users to pass if they have one or
# more of the specified roles. If not, it displays a rude message. For
# anything more complicated, use allow_if and a callback.
#
# $auth->bridge->to('auth#allow_roles', roles => [qw/cook dishwasher/]);
# $auth->bridge->to('auth#allow_roles', roles => "admin");

sub allow_roles {
    my $self = shift;

    my $r = $self->stash('roles');
    my @r = ref $r ? @$r : $r;
    if ($self->stash('user')->has_any_role(@r)) {
        return 1;
    }

    return $self->denied;
}

# This is just a helper function to write authentication bridges. It
# expects stash('cond') to be a callback, to which it passes the user
# object. If the callback returns 1, so does this function. Otherwise,
# it displays a rude error message (which is the convenient part).
#
# $auth->bridge->to('auth#allow_if', cond => sub { ... });

sub allow_if {
    my $self = shift;

    my $user = $self->stash('user');
    if (my $allow = $self->stash('cond')->($self, $user)) {
        return 1;
    }

    return $self->denied;
}

# This function takes a username and password and, if the password is
# valid for the named user, issues a signed cookie that will pass the
# check above. If not, it displays the login form and an error. This
# action itself must be reachable without authentication to avoid an
# infinite loop.
#
# $r->route('/login')->via('post')->to('auth#login')

sub login {
    my $self = shift;
    my $ip = $self->tx->remote_address;

    my ($login, $passwd);
    if ($self->req->method eq 'POST') {
        $login = $self->param("__login");
        $passwd = $self->param("__passwd");
    }

    if ($login && $passwd) {
        my $dbh = $self->db;
        my $u = $self->table('Users')->select_one(
            "is_active and coalesce(login,email)=?" => $login
        );
        if ($u && $u->has_password($passwd)) {
            $dbh->do(
                "update users set consecutive_failures=0, ".
                "second_last_login=last_login, ".
                "last_login=current_timestamp where user_id=?",
                {}, $u->{user_id}
            );
            $self->stash(user => $u);
            $self->session(user => $u->{user_id});
            $self->session(token => Gadwall::Util->csrf_token());
            $self->log->info("Login: " . $u->username . " (from $ip)");
            $self->after_login(delete $self->session->{source} || '/');
            return;
        }
        else {
            my $delay = 0;
            if ($u) {
                my $rv = $dbh->selectrow_arrayref(
                    "update users set ".
                    "consecutive_failures=consecutive_failures+1, ".
                    "last_failed_login=current_timestamp where user_id=? ".
                    "returning consecutive_failures", {}, $u->{user_id}
                );
                $delay = 2*($rv->[0]-1);
                $delay = 10 if $delay > 10;
                $self->log->info("Login failed: $login (from $ip)");
            }
            else {
                $self->log->debug("Login ignored: $login (from $ip)");
            }

            if ($delay) {
                $self->render_later;
                my $id; $id = Mojo::IOLoop->timer(
                    $delay => sub {
                        $self->render(
                            login => $login,
                            errmsg => $self->message('badlogin')
                        );
                    }
                );
                $self->on(finish => sub { Mojo::IOLoop->remove($id) });
                return;
            }
        }
    }

    $self->render(
        login => $login,
        errmsg => $self->message('badlogin')
    );
}

# This method, called by login after the user is successfully
# authenticated, must do whatever is needed to allow the user to
# continue to use the site; by default, that just means redirecting
# to the source URL (which is passed as a parameter).

sub after_login {
    my $self = shift;

    my ($source) = @_;
    $self->redirect($source);

    return;
}

# This function allows a user to act as another user. For obvious
# reasons, it should be exposed through an admin-only route.

sub su {
    my $self = shift;

    my ($where, @v);
    if ($self->req->method eq 'POST' &&
        (my $v = $self->param("username")))
    {
        $where = "login=? or email=?";
        push @v, $v, $v;
    }

    unless (@v) {
        return $self->denied;
    }

    my $u = $self->table('Users')->select_one($where, @v);
    if ($u) {
        my $ip = $self->tx->remote_address;
        $self->log->info(
            "su: ". $self->stash('user')->username .
            " to ". $u->username ." (from $ip)"
        );
        $self->session(suser => $self->session('user'));
        $self->session(user => $u->{user_id});
    }
    else {
        $self->flash(errmsg => $self->message('badsu'));
    }

    $self->redirect('/');
}

# This function revokes the cookie issued by login.

sub logout {
    my $self = shift;

    my $u = $self->stash('user');

    if ($self->session('suser')) {
        $self->log->info("Logout (su): " . $u->username);
        my $suser = delete $self->session->{suser};
        foreach (keys %{$self->session}) {
            delete $self->session->{$_} unless $_ eq "token";
        }
        $self->session(user => $suser);
        $self->redirect('/');
        return;
    }

    $self->log->info("Logout: " . $u->username);

    $self->db->do(
        "update users set last_failed_login=null where ".
        "user_id=?", {}, $u->{user_id}
    );

    delete $self->session->{$_} foreach keys %{$self->session};
    $self->session(token => Gadwall::Util->csrf_token());
    $self->flash(errmsg => $self->message('loggedout'));
    $self->redirect('/');
}

sub messages {
    my $self = shift;
    return (
        $self->SUPER::messages(),
        badsu => "Sorry, you can't act as that user",
        badlogin => "Incorrect username or password",
        loggedout => "You have been logged out",
    );
}

1;

__DATA__

@@ auth/login.html.ep
% layout 'minimal', title => "Login";
<%= post_form login => (class => 'login') => begin %>
  <label for="__login">Login:</label><br>
  <%= text_field '__login', value => stash 'login' %><br>
  <label for="__passwd">Password:</label><br>
  <%= password_field '__passwd' %><br>
  <%= submit_button 'Login', class => 'submit' %>
<% end %>
% if (stash 'errmsg') {
<p id=msg class=error>
<%= stash 'errmsg' %>
</p>
% }
