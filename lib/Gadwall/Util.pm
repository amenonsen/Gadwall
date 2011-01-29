package Gadwall::Util;

use strict;
use warnings;

use Crypt::Eksblowfish::Bcrypt qw(en_base64);

our @EXPORTS = qw(bcrypt);

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

sub salt {
    my $fh;
    if (open($fh, "/dev/urandom") && sysread($fh, my $raw, 16)) {
        return $raw;
    }
    die "/dev/urandom: $!\n";
}

sub bcrypt {
    my ($passwd, $settings) = @_;

    unless ($settings) {
        $settings = q{$2a$08$} . en_base64(salt());
    }

    return Crypt::Eksblowfish::Bcrypt::bcrypt($passwd, $settings);
}

1;
