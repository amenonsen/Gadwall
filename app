#!/usr/bin/env perl

use 5.14.0;

use strict;
use warnings;

use File::Basename 'dirname';
use File::Spec::Functions 'splitdir';

use lib join '/', splitdir(dirname(__FILE__)), 'lib';
use lib join '/', splitdir(dirname(__FILE__)), 'deps';

require Mojolicious::Commands;
Mojolicious::Commands->start_app('App');
