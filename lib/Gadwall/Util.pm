package Gadwall::Util;

use strict;
use warnings;

use Crypt::Eksblowfish::Bcrypt qw(en_base64);
use MIME::Base64 qw(encode_base64);
use MIME::Lite;
use Carp;

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

# Takes a hash of to/from/subject/text/cc/bcc/headers values and sends
# mail using localhost as a smarthost.

sub mail {
    my (%opts) = @_;

    my $to = delete $opts{to} or croak "No To address given";
    my $from = delete $opts{from} or croak "No From address given";
    my $subject = delete $opts{subject} or croak "No subject given";
    my $text = delete $opts{text} or croak "No body text given";

    if (ref $to eq 'ARRAY') {
        $to = join ", ", @$to;
    }

    if (ref $text && ref $text ne 'ARRAY') {
        unless ($text->can('to_string')) {
            croak "Body text must be a string or arrayref";
        }
        $text = $text->to_string;
    }

    my $m = MIME::Lite->new(
        To => $to,
        From => $from,
        Subject => $subject,
        Data => $text,
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

1;
