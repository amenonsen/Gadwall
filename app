#!/usr/bin/env perl

use strict;
use warnings;

use MIME::Base64 qw(encode_base64);
use File::Basename 'dirname';
use File::Spec;

use lib join '/', File::Spec->splitdir(dirname(__FILE__)), 'lib';
use lib join '/', File::Spec->splitdir(dirname(__FILE__)), 'deps';

eval 'use Mojolicious::Commands';
die <<EOF if $@;
Please install the Mojolicious framework to run this application.
See http://mojolicious.org for instructions.

EOF

our $random_secret = sub {
    my $fh;
    if (open($fh, "/dev/urandom") && sysread($fh, my $raw, 16)) {
        return encode_base64($raw, "");
    }
    die "/dev/urandom: $!\n";
}->();

$ENV{MOJO_APP} ||= 'App';

Mojolicious::Commands->start;