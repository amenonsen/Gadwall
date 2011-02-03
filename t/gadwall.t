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
use_ok('Wigeon::User');
use_ok('Gadwall::Users');
use_ok('Gadwall::Validator');
use_ok('Gadwall::Util', qw(bcrypt));

# Test the support modules

ok(Gadwall::Util::bcrypt('s3kr1t', '$2a$08$Xk7taVTzcF/jXEXwX0fnYuc/ZRr9jDQSTpGKzJKDU2UsSE7emt3gC') eq '$2a$08$Xk7taVTzcF/jXEXwX0fnYuc/ZRr9jDQSTpGKzJKDU2UsSE7emt3gC', "Bcrypt");
ok(bcrypt('s3kr1t', '$2a$08$Xk7taVTzcF/jXEXwX0fnYuc/ZRr9jDQSTpGKzJKDU2UsSE7emt3gC') eq '$2a$08$Xk7taVTzcF/jXEXwX0fnYuc/ZRr9jDQSTpGKzJKDU2UsSE7emt3gC', "Bcrypt imported");

my $x = bless {roles => 1<<6|1<<3}, "Wigeon::User";
ok($x->has_role('bitcounter'), 'has_role bitcounter');
ok($x->has_role('birdwatcher'), 'has_role birdwatcher');
ok(!$x->has_role('bearfighter'), '!has_role bearfighter');
ok(!$x->has_any_role('admin','cook'), "!has_any_roles admin,cook");
is_deeply([$x->roles()], [qw(birdwatcher bitcounter)], "list roles");

my $v = Gadwall::Validator->new({
    a => {},
    b => {validate => qr/^[0-9]+$/},
    c => {validate => qr/^[a-z]+$/, required => 1},
    d => {
        validate => sub{
            my %v = @_;
            return (d => $v{d}-1)
                if $v{d} =~ Gadwall::Validator->patterns('nznumber');
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
    m => { required => 1, validate => Gadwall::Validator->patterns('date') }
});
ok($v);

my $r = $v->validate({
    a => 1, b => 'a', c => " ", d => 3, e => "  foo  ", f => [1," 2 "],
    G => [1,2,3], H => 4, I => 3, J => undef, K => "	", _l => "foo",
    _m => "bar", m => "2011-01-33"
}, all => 1);
ok($r eq 'invalid', 'validation status');

is_deeply(
    $v->errors, {
        b => "b is invalid", c => "c is required",
        g => "Invalid field specification (#B)",
        h => "h is required", i => "i is required",
        m => "m is invalid"
    }, "validation errors"
);
is_deeply(
    {$v->values}, {
        a => 1, d => 2, e => "foo", f => [1,2], j => 3, l => "foobar"
    }, "validated values"
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
    ->json_content_is({rows => [{colour => "blue", teeth => 256, sprocket_name => "c", sprocket_id => 3},{colour => "green", teeth => 64, sprocket_name => "b", sprocket_id => 2},{colour => "red", teeth => 42, sprocket_name => "a", sprocket_id => 1}]});

$t->get_ok('/sprockets/list?id=1')
    ->status_is(200)
    ->content_type_is('application/json')
    ->json_content_is({rows => [{colour => "red", teeth => 42, sprocket_name => "a", sprocket_id => 1}]});

$t->post_form_ok('/sprockets/create', {sprocket_name => "d", colour => "red", teeth => 128})
    ->status_is(200)
    ->content_type_is('application/json')
    ->content_is(qq!{"status":"ok","message":"Sprocket created"}!);

$t->get_ok('/sprockets/list?id=4')
    ->status_is(200)
    ->content_type_is('application/json')
    ->json_content_is({rows => [{colour => "red", teeth => 128, sprocket_name => "d", sprocket_id => 4}]});

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
    ->json_content_is({rows => [{colour => "blue", teeth => 128, sprocket_name => "e", sprocket_id => 4}]});

$t->post_ok('/sprockets/4/delete')
    ->status_is(200)
    ->content_type_is('application/json')
    ->content_is(qq!{"status":"ok","message":"Sprocket deleted"}!);

$t->get_ok('/sprockets/list?id=4')
    ->status_is(200)
    ->content_type_is('application/json')
    ->json_content_is({rows => []});

$t->get_ok('/widgets/sprocket_colours')
    ->status_is(200)
    ->content_type_is('text/plain')
    ->content_is("red green");

$t->get_ok('/sprockets/approximate_blueness?sprocket_id=1')
    ->status_is(200)
    ->content_type_is('text/plain')
    ->content_is("not blue");

$t->get_ok('/sprockets/approximate_blueness?sprocket_id=2')
    ->status_is(200)
    ->content_type_is('text/plain')
    ->content_is("maybe blue");

$t->get_ok('/widgets/sprocket_redness?sprocket_id=1')
    ->status_is(200)
    ->content_type_is('text/plain')
    ->content_is("red");

$t->get_ok('/widgets/sprocket_redness?sprocket_id=2')
    ->status_is(200)
    ->content_type_is('text/plain')
    ->content_is("not red");

$t->get_ok('/foo')
    ->status_is(200)
    ->content_type_is("text/html;charset=UTF-8")
    ->text_is('html head title' => 'Foo!')
    ->text_like('html body' => qr/Foo bar!/);

$t->get_ok('/bar')
    ->status_is(403)
    ->content_type_is("text/html;charset=UTF-8")
    ->text_is('html body form label', 'Login:');

$t->post_form_ok('/login', {__login => "dummy", __passwd => "user"})
    ->status_is(200)
    ->content_type_is("text/html;charset=UTF-8")
    ->text_like('#msg', qr/Incorrect username or password/);

$t->post_form_ok('/login', {__login => "bar", __passwd => "s3kr1t", __source => "/bar"})
    ->status_is(302)
    ->content_type_is("text/plain")
    ->content_is("Redirecting to /bar");

$t->get_ok('/bar')
    ->status_is(200)
    ->content_type_is("text/plain")
    ->content_is("This is not a bar");

$t->get_ok('/baz')
    ->status_is(200)
    ->content_type_is("text/plain")
    ->content_is("This is not a baz");

$t->get_ok('/quux')
    ->status_is(200)
    ->content_type_is("text/plain")
    ->content_is('bar@example.org');

$t->post_form_ok('/su', {user_id => 1})
    ->status_is(302)
    ->content_type_is("text/plain")
    ->content_is("Redirecting to /");

$t->get_ok('/quux')
    ->status_is(200)
    ->content_type_is("text/plain")
    ->content_is('foo@example.org');

$t->get_ok('/logout')
    ->status_is(302)
    ->content_type_is("text/plain")
    ->content_is("Redirecting to /");

$t->get_ok('/quux')
    ->status_is(200)
    ->content_type_is("text/plain")
    ->content_is('bar@example.org');

$t->get_ok('/baz')
    ->status_is(200)
    ->content_type_is("text/plain")
    ->content_is("This is not a baz");

$t->get_ok('/flirbl')
    ->status_is(403)
    ->content_type_is("text/plain")
    ->content_is("Permission denied");

$t->get_ok('/logout')
    ->status_is(200)
    ->content_type_is("text/html;charset=UTF-8")
    ->text_like('#msg', qr/You have been logged out/);

$t->get_ok('/bar')
    ->status_is(403)
    ->content_type_is("text/html;charset=UTF-8")
    ->text_is('html body form label', 'Login:');

$t->get_ok('/nonesuch')
    ->status_is(404);

$t->get_ok('/shutdown')
    ->status_is(200)
    ->content_type_is('text/plain')
    ->content_is("Goodbye!");

done_testing();
