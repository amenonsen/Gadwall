#!/usr/bin/env perl

use strict;
use warnings;

use Test::More;
use Test::Mojo;
use Data::Dumper;
use File::Basename 'dirname';
use File::Spec;

use lib join '/', File::Spec->splitdir(dirname(__FILE__)), 'testlib';

use_ok('Wigeon');
use_ok('Gadwall::Validator');

# Test the support modules

my $v = Gadwall::Validator->new({
    a => {},
    b => {validate => qr/^[0-9]+$/},
    c => {validate => qr/^[a-z]+$/, required => 1},
    d => {
        validate => sub{
            my %v = @_;
            return (d => $v{d}-1) if $v{d} =~ /^[1-9][0-9]*$/;
        }},
    e => {validate => qr/^[a-z]+$/},
    f => {multiple => 1, validate => qr/^\d+$/, required => 1},
    g => {multiple => 1, validate => qr/^\d+$/, fields => [qw/G H/]},
    h => {multiple => 1, required => 1},
    i => {fields => [qw/I J/], required => 1},
    j => {fields => [qw/I J/]},
    k => {fields => [qw/J K/]},
    l => {
        fields => qr/^_/,
        validate => sub {
            my %v = @_;
            return (l => $v{_l}.$v{_m});
        }},
});
ok($v);

my $r = $v->validate({
    a => 1, b => 'a', c => " ", d => 3, e => "  foo  ", f => [1," 2 "],
    G => [1,2,3], H => 4, I => 3, J => undef, K => "	", _l => "foo",
    _m => "bar"
}, all => 1);
ok($r eq 'invalid', 'validation status');

is_deeply(
    $v->errors, {
        b => "b is invalid", c => "c is required",
        g => "Invalid field specification (#B)",
        h => "h is required", i => "i is required"
    }
);
is_deeply(
    {$v->values}, {
        a => 1, d => 2, e => "foo", f => [1,2], j => 3, l => "foobar"
    }
);

# Test the application itself

my $t = Test::Mojo->new(app => "Wigeon");

$t->get_ok('/')
    ->status_is(200)
    ->content_type_is('text/plain')
    ->content_is("Quack!");

$t->get_ok('/startup')
    ->status_is(200)
    ->content_type_is('text/plain')
    ->content_is("Welcome!");

$t->get_ok('/sprockets')
    ->status_is(200)
    ->content_type_is('application/json')
    ->content_is(qq!{"rows":[{"colour":"red","teeth":42,"sprocket_name":"a","sprocket_id":1},{"colour":"green","teeth":64,"sprocket_name":"b","sprocket_id":2},{"colour":"blue","teeth":256,"sprocket_name":"c","sprocket_id":3}]}!);

$t->get_ok('/sprockets/list?id=1')
    ->status_is(200)
    ->content_type_is('application/json')
    ->content_is(qq!{"rows":[{"colour":"red","teeth":42,"sprocket_name":"a","sprocket_id":1}]}!);

$t->post_form_ok('/sprockets/create', {sprocket_name => "d", colour => "red", teeth => 128})
    ->status_is(200)
    ->content_type_is('application/json')
    ->content_is(qq!{"status":"ok","message":"Sprocket created"}!);

$t->get_ok('/sprockets/list?id=4')
    ->status_is(200)
    ->content_type_is('application/json')
    ->content_is(qq!{"rows":[{"colour":"red","teeth":128,"sprocket_name":"d","sprocket_id":4}]}!);

$t->post_form_ok('/sprockets/4/update', {sprocket_name => "q", colour => "black"})
    ->status_is(200)
    ->content_type_is('application/json')
    ->content_is(qq!{"errors":{"colour":"colour is invalid"},"status":"error","message":"Please correct the following errors"}!);

$t->post_form_ok('/sprockets/4/update', {sprocket_name => "e", colour => "blue", teeth => 128})
    ->status_is(200)
    ->content_type_is('application/json')
    ->content_is(qq!{"status":"ok","message":"Sprocket updated"}!);

$t->get_ok('/sprockets/list?id=4')
    ->status_is(200)
    ->content_type_is('application/json')
    ->content_is(qq!{"rows":[{"colour":"blue","teeth":128,"sprocket_name":"e","sprocket_id":4}]}!);

$t->post_ok('/sprockets/4/delete')
    ->status_is(200)
    ->content_type_is('application/json')
    ->content_is(qq!{"status":"ok","message":"Sprocket deleted"}!);

$t->get_ok('/sprockets/list?id=4')
    ->status_is(200)
    ->content_type_is('application/json')
    ->content_is(qq!{"rows":[]}!);

$t->get_ok('/shutdown')
    ->status_is(200)
    ->content_type_is('text/plain')
    ->content_is("Goodbye!");

$t->get_ok('/nonesuch')
    ->status_is(404);

done_testing();
