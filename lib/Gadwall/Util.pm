package Gadwall::Util;

use strict;
use warnings;

use Crypt::Eksblowfish::Bcrypt qw(en_base64);
use MIME::Base64 qw(encode_base64);

our @EXPORTS = qw(bcrypt csrf_token);

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

sub csrf_token {
    return encode_base64($main::prng->get_bits(128), "");
}

sub bcrypt {
    my ($passwd, $settings) = @_;

    unless ($settings) {
        $settings = q{$2a$08$} . en_base64($main::prng->get_bits(128));
    }

    return Crypt::Eksblowfish::Bcrypt::bcrypt($passwd, $settings);
}

1;
