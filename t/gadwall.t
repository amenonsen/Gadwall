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

# Test the application itself

$ENV{MOJO_MODE} = "testing";
my $t = Test::Mojo->new("Wigeon");
$t->ua->app_url('http');

$t->get_ok('/nonesuch')
    ->status_is(404);

$t->get_ok('/')
    ->status_is(200)
    ->content_type_is('text/plain')
    ->content_is("Quack!");

$t->get_ok('/die')
    ->status_is(302)
    ->content_type_is("text/plain")
    ->content_is("Redirecting to https");

my $loc = $t->tx->res->headers->location();
ok $loc =~ /^https:\/\//, 'redirected to ' . $loc;

$t->get_ok('/startup')
    ->status_is(200)
    ->content_type_is('text/plain')
    ->content_is("Welcome!");

$t->get_ok('/from-template')
    ->status_is(200)
    ->content_type_is("text/html;charset=UTF-8")
    ->text_is('html head title' => 'Foo!')
    ->text_like('html body' => qr/Foo bar!/);

$t->get_ok('/wrapped-json')
    ->status_is(200)
    ->content_type_is("text/html;charset=UTF-8")
    ->text_is(textarea => qq[{"status":"ok","message":"Foo"}]);

$t->get_ok('/users-only', {"X-Bypass-Security" => 1})
    ->status_is(302)
    ->content_type_is("text/plain")
    ->content_is("Redirecting to https");

$loc = $t->tx->res->headers->location();
ok $loc =~ /^https:\/\//, 'redirected to ' . $loc;

$t->ua->app_url('https');

$t->get_ok('/die')
    ->status_is(500)
    ->content_type_is('text/html;charset=UTF-8')
    ->content_is("ouch\n");

$t->get_ok('/users-only')
    ->status_is(403)
    ->content_type_is("text/html;charset=UTF-8")
    ->text_is('html body form label', 'Login:');

my $token = $t->tx->res->dom('input[name="__token"]')->[0]->attrs->{value};
ok($token, "CSRF token");

$t->post_form_ok('/login', {__login => "dummy", __passwd => "user", __token => $token})
    ->status_is(200)
    ->content_type_is("text/html;charset=UTF-8")
    ->text_like('#msg', qr/Incorrect username or password/);

$t->post_form_ok('/login', {__login => "bar", __passwd => "s3kr1t", __token => $token})
    ->status_is(302)
    ->content_type_is("text/plain")
    ->content_is("Redirecting to /users-only");

$t->get_ok('/my-token')
    ->status_is(200)
    ->content_type_is("text/plain");

my $newtoken = $t->tx->res->body;
ok($newtoken ne $token, "CSRF token changed");
$token = $newtoken;

$t->get_ok('/users-only')
    ->status_is(200)
    ->content_type_is("text/plain")
    ->content_is("This is not a bar");

$t->get_ok('/my-email')
    ->status_is(200)
    ->content_type_is("text/plain")
    ->content_is('bar@example.org');

$t->get_ok('/my-roles')
    ->status_is(200)
    ->content_type_is("text/plain")
    ->content_is("birdwatcher:bearfighter:bitcounter");

$t->get_ok('/birdwatchers-only')
    ->status_is(200)
    ->content_type_is("text/plain")
    ->content_is("This is not a baz");

$t->post_form_ok('/users/create', {
        email => 'foo@example.org', pass1 => 's3kr1t', pass2 => 's3kr1t',
        is_admin => 1, is_backstabber => 1, __token => $token
    })
    ->status_is(200)
    ->content_type_is("application/json")
    ->json_content_is({status => "ok", message => "User created"});

$t->get_ok('/users/list?user_id=2')
    ->status_is(200)
    ->content_type_is("application/json")
    ->json_content_is({
            status => "ok",
            table => { name => "users", key => "user_id", page => 1, limit => 0, total => 1 },
            users => [{
                user_id=>2, email=>'foo@example.org', login=>undef,
                is_backstabber=>1, is_admin=>1,is_active=>1,
                roles => [qw/Administrator backstabber/],
                last_login=>undef, last_failed_login=>undef,
                last_password_change=>undef, consecutive_failures=>0,
                password_expired=>0, second_last_login=>undef
            }]
        });

$t->post_form_ok('/su', {username => 'foo@example.org', __token => $token})
    ->status_is(302)
    ->content_type_is("text/plain")
    ->content_is("Redirecting to /");

$t->get_ok('/my-email')
    ->status_is(200)
    ->content_type_is("text/plain")
    ->content_is('foo@example.org');

$t->get_ok('/my-roles')
    ->status_is(200)
    ->content_type_is("text/plain")
    ->content_is("admin:backstabber");

$t->get_ok('/birdwatchers-only')
    ->status_is(403)
    ->content_type_is("text/plain")
    ->content_is("Permission denied");

$t->post_form_ok('/logout', {__token => $token})
    ->status_is(302)
    ->content_type_is("text/plain")
    ->content_is("Redirecting to /");

$t->get_ok('/my-email')
    ->status_is(200)
    ->content_type_is("text/plain")
    ->content_is('bar@example.org');

$t->get_ok('/my-roles')
    ->status_is(200)
    ->content_type_is("text/plain")
    ->content_is("birdwatcher:bearfighter:bitcounter");

$t->get_ok('/birdwatchers-only')
    ->status_is(200)
    ->content_type_is("text/plain")
    ->content_is("This is not a baz");

$t->get_ok('/never')
    ->status_is(403)
    ->content_type_is("text/plain")
    ->content_is("Permission denied");

$t->post_form_ok('/users/1/password', {
        password => "s3kr1t", pass1 => "secret", pass2 => "secret",
        __token => $token
    })
    ->status_is(200)
    ->content_type_is("application/json")
    ->json_content_is({status => "ok", message => "Password changed"});

$t->post_form_ok('/users/2/password', {
        password => "s3kr1t", pass1 => "secret", pass2 => "secret",
        __token => $token
    })
    ->status_is(403)
    ->content_type_is('text/plain')
    ->content_is("Permission denied");

$t->post_form_ok('/users/1/email', {
        password => "secret", email => q{new@example.org},
        __token => $token
    })
    ->status_is(200)
    ->content_type_is("application/json")
    ->json_content_is({status => "ok", message => "Confirmation link sent to new address"});

$t->get_ok('/confirm-email')
    ->status_is(403)
    ->content_type_is('text/plain')
    ->content_is("Permission denied");

$t->get_ok('/my-email-confirm-token')
    ->status_is(200)
    ->content_type_is("text/plain");

my $etoken = $t->tx->res->body;
$etoken .= ":".Mojo::Util::hmac_md5_sum($etoken, $t->app->secret);
my $cnf = Mojo::URL->new('/confirm-email');
$cnf->query->param(t => $etoken);

$t->get_ok($cnf)
    ->status_is(200)
    ->content_type_like(qr#text/html#)
    ->element_exists('p.msg');

$t->get_ok('/my-email')
    ->status_is(200)
    ->content_type_is("text/plain")
    ->content_is('new@example.org');

$t->post_form_ok('/logout', {__token => $token})
    ->status_is(302)
    ->content_type_is("text/plain")
    ->content_is("Redirecting to /");

$t->get_ok('/')
    ->status_is(200)
    ->content_type_is("text/plain")
    ->content_is("Quack!");

$t->get_ok('/users-only')
    ->status_is(403)
    ->content_type_is("text/html;charset=UTF-8")
    ->text_is('html body form label', 'Login:');

$newtoken = $t->tx->res->dom('input[name="__token"]')->[0]->attrs->{value};
ok($newtoken ne $token, "New CSRF token");

$t->post_form_ok('/login', {__login => "bar", __passwd => "s3kr1t", __token => $token})
    ->status_is(403)
    ->content_type_is("text/plain")
    ->content_is("Permission denied");

$token = $newtoken;

$t->post_form_ok('/login', {__login => "bar", __passwd => "s3kr1t", __token => $token})
    ->status_is(200)
    ->content_type_is("text/html;charset=UTF-8")
    ->text_like('#msg', qr/Incorrect username or password/);

$t->post_form_ok('/login', {__login => "bar", __passwd => "secret", __token => $token})
    ->status_is(302)
    ->content_type_is("text/plain")
    ->content_is("Redirecting to /users-only");

$t->get_ok('/my-token')
    ->status_is(200)
    ->content_type_is("text/plain");

$newtoken = $t->tx->res->body;
ok($newtoken ne $token, "CSRF token changed");
$token = $newtoken;

$t->get_ok('/sprockets')
    ->status_is(200)
    ->content_type_is('application/json')
    ->json_content_is({
            status => "ok",
            table => { name => "sprockets", key => "sprocket_id", page => 1, limit => 0, total => 3 },
            sprockets => [
                {colour => "blue", teeth => 256, sprocket_name => "c", sprocket_id => 3},
                {colour => "green", teeth => 64, sprocket_name => "b", sprocket_id => 2},
                {colour => "red", teeth => 42, sprocket_name => "a", sprocket_id => 1}
            ]
        });

$t->get_ok('/sprockets/list?sprocket_id=1')
    ->status_is(200)
    ->content_type_is('application/json')
    ->json_content_is({
            status => "ok",
            table => { name => "sprockets", key => "sprocket_id", page => 1, limit => 0, total => 1 },
            sprockets => [
                {colour => "red", teeth => 42, sprocket_name => "a", sprocket_id => 1}
            ]
        });

$t->post_form_ok('/sprockets/create', {sprocket_name => "d", colour => "red", teeth => 128, __token => $token})
    ->status_is(200)
    ->content_type_is('application/json')
    ->content_is(qq!{"status":"ok","message":"Sprocket created"}!);

$t->get_ok('/sprockets/list?sprocket_id=4')
    ->status_is(200)
    ->content_type_is('application/json')
    ->json_content_is({
            status => "ok",
            table => { name => "sprockets", key => "sprocket_id", page => 1, limit => 0, total => 1 },
            sprockets => [
                {colour => "red", teeth => 128, sprocket_name => "d", sprocket_id => 4}
            ]
        });

$t->post_form_ok('/sprockets/4/update', {sprocket_name => "q", colour => "black", __token => $token})
    ->status_is(200)
    ->content_type_is('application/json')
    ->content_is(qq!{"errors":{"colour":"This field is invalid"},"status":"error","message":"Please correct the following errors"}!);

$t->post_form_ok('/sprockets/4/update', {sprocket_name => "e", colour => "blue", teeth => 128, __token => $token})
    ->status_is(200)
    ->content_type_is('application/json')
    ->content_is(qq!{"status":"ok","message":"Sprocket updated"}!);

$t->get_ok('/sprockets/list?sprocket_id=4')
    ->status_is(200)
    ->content_type_is('application/json')
    ->json_content_is({
            status => "ok",
            table => { name => "sprockets", key => "sprocket_id", page => 1, limit => 0, total => 1 },
            sprockets => [
                {colour => "blue", teeth => 128, sprocket_name => "e", sprocket_id => 4}
            ]
        });

$t->get_ok('/sprockets/list?p=2;n=2')
    ->status_is(200)
    ->content_type_is('application/json')
    ->json_content_is({
            status => "ok",
            table => { name => "sprockets", key => "sprocket_id", page => 2, limit => 2, total => 4 },
            sprockets => [
                {colour => "green", teeth => 64, sprocket_name => "b", sprocket_id => 2},
                {colour => "red", teeth => 42, sprocket_name => "a", sprocket_id => 1}
            ]
        });

$t->post_form_ok('/sprockets/4/delete', {__token => $token})
    ->status_is(200)
    ->content_type_is('application/json')
    ->content_is(qq!{"status":"ok","message":"Sprocket deleted"}!);

$t->get_ok('/sprockets/list?sprocket_id=4')
    ->status_is(200)
    ->content_type_is('application/json')
    ->json_content_is({
            status => "ok",
            table => { name => "sprockets", key => "sprocket_id", page => 1, limit => 0, total => 0 },
            sprockets => []
        });

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

$t->get_ok('/p1')
    ->status_is(200)
    ->content_type_like(qr#text/html#)
    ->element_exists('form')
    ->element_exists('form input[name=__token]');

$t->get_ok('/forgot-password')
    ->status_is(200)
    ->content_type_like(qr#text/html#)
    ->element_exists('form')
    ->element_exists('form input[name=email]');

$t->post_form_ok('/logout', {__token => $token})
    ->status_is(302)
    ->content_type_is("text/plain")
    ->content_is("Redirecting to /");

$t->get_ok('/users-only')
    ->status_is(403)
    ->content_type_is("text/html;charset=UTF-8")
    ->text_like('#msg', qr/You have been logged out/);

$t->get_ok('/shutdown')
    ->status_is(200)
    ->content_type_is('text/plain')
    ->content_is("Goodbye!");

done_testing();
