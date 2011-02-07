package Wigeon;

use strict;
use warnings;

use base 'Gadwall';

use Mojolicious::Controller;

sub config_defaults {(
    shift->SUPER::config_defaults(),
    "db-name" => "gadwall", "db-user" => "gadwall"
)}

sub startup {
    my $app = shift;
    $app->gadwall_setup();

    my $r = $app->routes();

    $r->any('/' => sub {
        shift->render_text("Quack!", format => 'txt')
    });

    $r->any(
        '/from-template' => sub {
            my $self = shift;
            $self->render(template => "foo", template_class => __PACKAGE__);
        }
    );

    $r->any('/startup' => sub {
        my $self = shift;
        my $dbh = $self->app->db;

        $dbh->begin_work;
        eval {
            local $dbh->{RaiseError} = 1;
            $dbh->do(
                "set client_min_messages to 'error'"
            );
            $dbh->do(
                "create table sprockets (sprocket_id serial primary key, ".
                "sprocket_name text, colour text, teeth integer)"
            );
            $dbh->do(
                "insert into sprockets (sprocket_name, colour, teeth) ".
                "values ('a','red',42), ('b','green',64), ('c','blue',256)"
            );
            $dbh->do(
                "create table users (user_id serial primary key, ".
                "login text unique, email text not null unique, ".
                "password text not null, is_active bool not null ".
                "default true, roles bit(31) not null default ".
                "B'0'::bit(31))"
            );
            $dbh->do(
                "insert into users (login,email,password,roles) values ".
                q{('bar', 'bar@example.org', '$2a$08$Xk7taVTzcF/jXEXwX0fnYuc/ZRr9jDQSTpGKzJKDU2UsSE7emt3gC', }.
                q{B'0000000000000000000000001011000'::bit(31))}
            );
            $dbh->commit;
        };
        if ($@) {
            $dbh->rollback;
            die $@;
        }
        $self->render(text => "Welcome!", format => 'txt');
    });

    $r->route('/widgets/:action')->to(controller => 'widgets');
    $r->route('/sprockets/:action')->to(controller => 'sprockets', action => 'list');

    $r->route('/sprockets/:sprocket_id/:action')->to(controller => 'sprockets', action => 'update');

    my $auth = $app->plugin('login');
    $auth->route('/my-token')->to(cb => sub {
        my $self = shift;
        $self->render_text($self->session('token'), format => 'txt');
    });
    $auth->route('/users-only')->to(cb => sub {
        shift->render_text("This is not a bar", format => 'txt');
    });
    my $bird = $auth->bridge->to('auth#allow_roles', namespace => "Gadwall", roles => "birdwatcher");
    $bird->route('/birdwatchers-only')->to(cb => sub {
        shift->render_text("This is not a baz", format => 'txt');
    });
    $bird->route('/su')->via('post')->to('auth#su');
    $auth->route('/my-email')->to(cb => sub {
        my $self = shift;
        $self->render_text($self->stash('user')->{email}, format => 'txt');
    });
    $auth->get('/my-roles' => sub {
        my $self = shift;
        my $u = $self->stash('user');
        $self->render(
            text => join(":",$u->roles()), format => 'txt'
        );
    });

    my $never = $auth->bridge->to('auth#allow_if', cond => sub {0});
    $never->get('/never' => sub { shift->render(text => "Sometimes", format => 'txt') });

    $auth->route('/users/create')->via('post')->to('users#create');
    $auth->route('/users/:user_id/password')->via('post')->to('users#password');

    $r->any('/shutdown' => sub {
        my $self = shift;
        $self->app->db->do("drop table sprockets");
        $self->app->db->do("drop table users");
        $self->render(text => "Goodbye!", format => 'txt');
    });

    $r->any('/(*whatever)' => sub { shift->render_not_found });
}

{
    no warnings 'redefine';
    package Mojolicious::Controller;

    sub render_not_found {
        my $self = shift;
        $self->render(
            status => 404, format => 'txt',
            text => "Not found: ".$self->req->url->path
        );
    }

    sub render_exception {
        my ($self, $e) = @_;

        return if $self->stash->{'mojo.exception'};
        $self->render(
            status => 500, format => 'txt',
            handler => undef, layout => undef, extends => undef,
            text => Mojo::Exception->new($e)->message,
            'mojo.exception' => 1
        );
    }
}

1;

__DATA__

@@ foo.html.ep
% layout 'default', title => "Foo!";
Foo bar!
