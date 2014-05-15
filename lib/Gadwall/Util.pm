package Gadwall::Util;

use strict;
use warnings;

use Crypt::Eksblowfish::Bcrypt qw(en_base64);
use MIME::Base64 qw(encode_base64);
use Digest::MD5 'md5';
use MIME::Lite;
use Mojo::JSON;
use Carp;

our @EXPORTS = qw(
    bcrypt hmac_md5_sum csrf_token
    mail enqueue_mail enqueue_job
);

sub import {
    my $pkg = caller;
    my $class = shift;
    my %exports = map {$_ => 1} @EXPORTS;

    foreach my $sym (@_) {
        if (exists $exports{$sym}) {
            no strict 'refs';
            *{"${pkg}::$sym"} = \&{"$sym"};
        }
    }
}

# Returns the bcrypted version of the given password. If $settings is
# not specified, a random 128-bit salt is generated and used.

sub bcrypt {
    my ($passwd, $settings) = @_;

    unless ($settings) {
        $settings = q{$2a$08$} . en_base64($main::prng->get_bits(128));
    }

    return Crypt::Eksblowfish::Bcrypt::bcrypt($passwd, $settings);
}

# A replacement for Mojo::Util's (now-removed) hmac_md5_sum. Same code,
# but no "Very insecure!" default secret.

sub hmac_md5_sum {
    my ($string, $secret) = @_;
    $secret = md5($secret) if length $secret > 64;

    my $ipad = $secret ^ (chr(0x36) x 64);
    my $opad = $secret ^ (chr(0x5c) x 64);
    return unpack 'H*', md5($opad . md5($ipad . $string));
}

# Returns a base64-encoded random 128-bit string for use as a CSRF
# protection token.

sub csrf_token {
    return encode_base64($main::prng->get_bits(128), "");
}

# Takes a hash of to/from/subject/text/cc/bcc/headers values and sends
# mail using localhost as a smarthost.

sub mail {
    my (%opts) = @_;

    %opts = _prepare_mail(%opts);

    my $m = MIME::Lite->new(
        To => delete $opts{to},
        From => delete $opts{from},
        Subject => delete $opts{subject},
        Data => delete $opts{text},
        %opts
    );

    eval {
        my $mode = $ENV{MOJO_MODE} || "";
        unless ($mode eq "testing") {
            $m->send(smtp => '127.0.0.1');
        }
    };
    return $m->last_send_successful;
}

# This function inserts a mail entry into the queue for processing by
# utils/dequeued. The real work is done by enqueue_job below. Returns
# 0 on success, or -1 on error.

sub enqueue_mail {
    my ($app, %opts) = @_;

    %opts = _prepare_mail(%opts);

    return enqueue_job($app, 'mail', \%opts);
}

sub enqueue_job {
    my ($app, $tag, $data) = @_;

    my $dbh = $app->db;
    my $signal = $app->config('dequeued_name');

    $dbh->begin_work;
    eval {
        local $dbh->{RaiseError} = 1;
        $dbh->do(
            "insert into queue (tag, data) values (?, ?)",
            {}, $tag, Mojo::JSON->encode($data)
        );
        $dbh->do(qq{NOTIFY "$signal"});
        $dbh->commit;
    } or do {
        my $msg = $@;
        $dbh->rollback;
        $app->log->error("Couldn't enqueue job $tag/'$data': $@");
        return 0;
    };

    return 1;
}

# Helper functions

sub _prepare_mail {
    my (%opts) = @_;

    unless ($opts{to}) {
        croak "No To address given";
    }
    unless ($opts{from}) {
        croak "No From address given";
    }
    unless ($opts{subject}) {
        croak "No subject given";
    }
    unless ($opts{text}) {
        croak "No body text given";
    }

    foreach my $f (qw(to cc)) {
        if (ref $opts{$f} eq 'ARRAY') {
            $opts{$f} = join ", ", @{$opts{$f}};
        }
    }

    my $text = $opts{text};
    if (ref $text && ref $text ne 'ARRAY') {
        unless ($text->can('to_string')) {
            croak "Body text must be a string or arrayref";
        }
        $opts{text} = $text->to_string;
    }

    return %opts;
}

1;
