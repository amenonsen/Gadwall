#!/usr/bin/env perl

use strict;
use warnings;

use File::Basename 'dirname';
use File::Spec;

use lib join '/', File::Spec->splitdir(dirname(__FILE__)), 'lib';
use lib join '/', File::Spec->splitdir(dirname(__FILE__)), 'deps';

eval 'use Mojolicious::Commands';
die <<EOF if $@;
Please install the Mojolicious framework to run this application.
See http://mojolicious.org for instructions.

EOF

$ENV{MOJO_APP} ||= 'App';

Mojolicious::Commands->start;
