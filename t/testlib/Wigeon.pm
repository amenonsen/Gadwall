package Wigeon;

use Mojo::Base 'Gadwall';

sub config_defaults {(
    shift->SUPER::config_defaults(),
    "db-name" => "gadwall", "db-user" => "gadwall"
)}

sub startup {
    my $app = shift;
    $app->log->level('debug');
    $app->gadwall_setup();
    $app->defaults(template_class => __PACKAGE__);

    $app->hook(
        before_dispatch => sub {
            my $self = shift;
            $self->req->headers->add('X-Forwarded-Protocol', "https");
        }
    );

    my $r = $app->routes();

    $r->any('/' => sub {
        shift->render_plaintext("Quack!");
    });

    my $https = $r->bridge->to('auth#allow_secure');
    $https->any('/die' => sub { die "ouch\n" });

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
        $self->render_plaintext("Welcome!");
    });

    $r->route('/widgets/:action')->to(controller => 'widgets');
    $r->route('/sprockets/:action')->to(controller => 'sprockets', action => 'list');

    $r->route('/sprockets/:sprocket_id/:action')->to(controller => 'sprockets', action => 'update');

    my $auth = $app->plugin('login');
    $app->plugin('passwords');
    $auth->route('/my-token')->to(cb => sub {
        my $self = shift;
        $self->render_plaintext($self->session('token'));
    });
    $auth->route('/users-only')->to(cb => sub {
        shift->render_plaintext("This is not a bar");
    });
    my $bird = $auth->bridge->to('auth#allow_roles', namespace => "Gadwall", roles => "birdwatcher");
    $bird->route('/birdwatchers-only')->to(cb => sub {
        shift->render_plaintext("This is not a baz");
    });
    $bird->route('/su')->via('post')->to('auth#su');
    $auth->route('/my-email')->to(cb => sub {
        my $self = shift;
        $self->render_plaintext($self->stash('user')->{email});
    });
    $auth->get('/my-roles' => sub {
        my $self = shift;
        my $u = $self->stash('user');
        $self->render_plaintext(join(":",$u->roles()));
    });

    my $never = $auth->bridge->to('auth#allow_if', cond => sub {0});
    $never->get('/never' => sub { shift->render_plaintext("Sometimes") });

    $auth->route('/users/create')->via('post')->to('users#create');
    $auth->route('/users/:user_id/password')->via('post')->to('users#password');

    # We have to connect as the admin in order to delete users.
    $r->any('/shutdown' => sub {
        my $self = shift;
        $self->app->db->do("drop table sprockets");
        my $dbh = DBI->connect("dbi:Pg:database=gadwall", "mallard", "")||die $DBI::errstr;
        $dbh->do("delete from users");
        $dbh->do("alter sequence users_user_id_seq restart with 1");
        $self->render_plaintext("Goodbye!");
    });

    $r->any('/(*whatever)' => sub { shift->render_not_found });
}

sub Mojolicious::Controller::render_plaintext {
    shift->render_text(shift, format => 'txt', @_);
}

1;

__DATA__

@@ foo.html.ep
% layout 'default', title => "Foo!";
Foo bar!

@@ not_found.testing.html.ep
<%= "Not found: " . url_for =%>

@@ exception.testing.html.ep
<%= stash('exception')->message =%>

@@ password-reset.html.ep
% layout 'default', title => "Reset password";
<%= post_form forgot_password => begin %>
<%= text_field 'email' %>
<%= submit_button 'Reset password' %>
<% end %>
