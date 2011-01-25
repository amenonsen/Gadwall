package Wigeon;

use strict;
use warnings;

use base 'Gadwall';

sub config_defaults {+{
    %{ shift->SUPER::config_defaults() },
    "db-name" => "gadwall", "db-user" => "gadwall"
}}

sub startup {
    my $app = shift;
    $app->gadwall_setup();

    my $r = $app->routes();

    $r->any('/' => sub {
        shift->render_text("Quack!", format => 'txt')
    });

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
            $dbh->commit;
        };
        if ($@) {
            $dbh->rollback;
            die $@;
        }
        $self->render(text => "Welcome!", format => 'txt');
    });

    $r->route('/sprockets/:action')->to(controller => 'sprockets', action => 'list');

    $r->route('/sprockets/:sprocket_id/:action')->to(controller => 'sprockets', action => 'update');

    $r->any('/shutdown' => sub {
        my $self = shift;
        $self->app->db->do("drop table sprockets");
        $self->render(text => "Goodbye!", format => 'txt');
    });

    $r->any('/(*whatever)' => sub { shift->render_not_found });
}

1;
