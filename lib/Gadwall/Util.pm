package Gadwall::Util;

use strict;
use warnings;

use Crypt::Eksblowfish::Bcrypt qw(en_base64);
use MIME::Base64 qw(encode_base64);
use Email::Stuff;

our @EXPORTS = qw(bcrypt csrf_token mail);

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

# Returns a base64-encoded random 128-bit string for use as a CSRF
# protection token.

sub csrf_token {
    return encode_base64($main::prng->get_bits(128), "");
}

# Takes a hash of to/from/subject/text/cc/bcc/headers/attachments values
# and sends mail using localhost as a smarthost.

sub mail {
    my (%opts) = @_;

    die "Not enough parameters to send mail"
        if grep !defined, @opts{qw(from to subject text)};

    my $e = Email::Stuff->to($opts{to})
        ->from($opts{from})
        ->subject($opts{subject})
        ->text_body($opts{text});

    foreach my $cc (qw(cc bcc)) {
        if (my $ccv = $opts{$cc}) {
            if (ref $ccv) {
                $ccv = join ", ", @$ccv;
            }
            $e->$cc($ccv);
        }
    }

    my $headers = $opts{headers} || {};
    foreach my $h (keys %$headers) {
        $e->header($h => $headers->{$h});
    }

    my $files = $opts{attachments} || [];
    foreach my $f (@$files) {
        my $file = shift @$f;
        $e->attach_file($file, @$f);
    }

    $e->send(SMTP => Host => '127.0.0.1');
}

1;
