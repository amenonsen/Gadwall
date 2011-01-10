#!/usr/bin/env perl

use strict;
use warnings;

use Test::More;
use Test::Mojo;

use_ok('Gadwall');

my $t = Test::Mojo->new(app => "Gadwall");

$t->get_ok('/')
    ->status_is(200)
    ->content_type_is('text/plain')
    ->content_is("Quack!");

$t->get_ok('/nonesuch')
    ->status_is(404);

done_testing();
