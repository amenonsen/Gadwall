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

# Make sure both imported and non-imported forms of bcrypt work

ok(Gadwall::Util::bcrypt('s3kr1t', '$2a$08$Xk7taVTzcF/jXEXwX0fnYuc/ZRr9jDQSTpGKzJKDU2UsSE7emt3gC') eq '$2a$08$Xk7taVTzcF/jXEXwX0fnYuc/ZRr9jDQSTpGKzJKDU2UsSE7emt3gC', "Bcrypt");
ok(bcrypt('s3kr1t', '$2a$08$Xk7taVTzcF/jXEXwX0fnYuc/ZRr9jDQSTpGKzJKDU2UsSE7emt3gC') eq '$2a$08$Xk7taVTzcF/jXEXwX0fnYuc/ZRr9jDQSTpGKzJKDU2UsSE7emt3gC', "Bcrypt imported");

# Test the bit-twiddling code for role checking in ::User

my $x = bless {roles => 1<<6|1<<3}, "Wigeon::User";
ok($x->has_role('bitcounter'), 'has_role bitcounter');
ok($x->has_role('birdwatcher'), 'has_role birdwatcher');
ok(!$x->has_role('bearfighter'), '!has_role bearfighter');
ok(!$x->has_any_role('admin','cook'), "!has_any_roles admin,cook");
is_deeply([$x->roles()], [qw(birdwatcher bitcounter)], "list roles");
$x = bless {roles => 1}, "Wigeon::User";
ok($x->has_role("admin"), 'has_role admin');
is_deeply([$x->roles()], [qw(admin)], "list roles");

# Test the validator with a complex set of fields and values

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
    m => { required => 1, validate => Gadwall::Validator->patterns('date') },
    n => { validate => Gadwall::Validator->patterns('numeric2') },
    o => { validate => Gadwall::Validator->patterns('numeric2') },
    p => { validate => Gadwall::Validator->patterns('time') },
    q => { multiple => 1, required => 1 },
    r => { multiple => 1, required => 1, validate => sub {@_} },
    s => { multiple => 1, required => 1, validate => sub {@_} },
    t => { required => 1 }
});
ok($v);

my $r = $v->validate({
    a => 1, b => 'a', c => " ", d => 3, e => "  foo  ", f => [1," 2 "],
    G => [1,2,3], H => 4, I => 3, J => undef, K => "	", _l => "foo",
    _m => "bar", m => "2011-01-33", n => "3.53", o => 13, p => "13:21",
    q => 0, r => 2, s => [0,1], t => 0
}, all => 1);
ok($r eq 'invalid', 'validation status');

is_deeply(
    $v->errors, {
        b => "This field is invalid", c => "This field is required",
        g => "Invalid field specification (#B)",
        h => "This field is required", i => "This field is required",
        m => "This field is invalid"
    }, "validation errors"
);
is_deeply(
    {$v->values}, {
        a => 1, d => 2, e => "foo", f => [1,2], j => 3, l => "foobar",
        n => "3.53", o => 13, p => "13:21", q => [0], r => [2], s => [0,1],
        t => 0
    }, "validated values"
);

done_testing();
