package Wigeon;

use Mojo::Base 'Gadwall';

sub config_defaults {(
    shift->SUPER::config_defaults(),
    db_name => "gadwall", db_user => "gadwall"
)}

sub startup {
    my $app = shift;
    $app->log->level('debug');
    $app->gadwall_setup();
    push @{$app->renderer->classes}, __PACKAGE__;

    if ($app->mode eq 'testing') {
        $app->log->path(undef);
    }

    $app->hook(
        before_dispatch => sub {
            my $self = shift;
            $self->req->headers->add('X-Forwarded-HTTPS', "1");
        }
    );

    my $r = $app->routes();

    $r->any('/' => sub {
        shift->render_text("Quack!");
    });

    $r->get('/t/1' => sub {
        return shift->render("1");
    });

    my $https = $r->bridge->to('auth#allow_secure');
    $https->any('/die' => sub { die "ouch\n" });

    $r->any(
        '/from-template' => sub {
            my $self = shift;
            $self->render(template => "foo");
        }
    );

    $r->any(
        '/helpers' => sub {
            my $self = shift;
            $self->render(template => "helpers");
        }
    );

    $r->any('/wrapped-json')->to('users#wrapped_json');

    $r->any('/startup' => sub {
        my $self = shift;
        my $dbh = $self->app->db;

        my $sdbh = DBI->connect("dbi:Pg:database=gadwall", "mallard", "")||die $DBI::errstr;
        $sdbh->do("set client_min_messages to 'error'");
        $sdbh->do("delete from users");
        $sdbh->do("alter sequence users_user_id_seq restart with 1");
        $sdbh->disconnect;

        $dbh->begin_work;
        eval {
            local $dbh->{RaiseError} = 1;
            $dbh->do(
                "set client_min_messages to 'error'"
            );
            $dbh->do(
                "drop table if exists sprockets"
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
                "insert into users (login,email,roles,password) values ".
                q{('bar', 'bar@example.org', B'0000000000000000000000001011000'::bit(31), }.
                q{'$2a$08$Xk7taVTzcF/jXEXwX0fnYuc/ZRr9jDQSTpGKzJKDU2UsSE7emt3gC')}
            );
            $dbh->commit;
        };
        if ($@) {
            $dbh->rollback;
            die $@;
        }
        $self->render_text("Welcome!");
    });

    $r->route('/widgets/:action')->to(controller => 'widgets');
    $r->route('/sprockets/:action')->to(controller => 'sprockets', action => 'list');

    $r->route('/sprockets/:sprocket_id/:action')->to(controller => 'sprockets', action => 'update');

    my $auth = $app->plugin('login');
    $app->plugin('user');
    $auth->route('/my-token')->to(cb => sub {
        my $self = shift;
        $self->render_text($self->session('token'));
    });
    $auth->route('/users-only')->to(cb => sub {
        shift->render_text("This is not a bar");
    });
    my $bird = $auth->allow_roles("birdwatcher");
    $bird->route('/birdwatchers-only')->to(cb => sub {
        shift->render_text("This is not a baz");
    });
    $bird->route('/su')->via('post')->to('auth#su');
    $auth->route('/my-email')->to(cb => sub {
        my $self = shift;
        $self->render_text($self->stash('user')->{email});
    });
    $auth->get('/my-roles' => sub {
        my $self = shift;
        my $u = $self->stash('user');
        $self->render_text(join(":",$u->roles()));
    });
    $auth->get('/my-email-confirm-token' => sub {
        my $self = shift;
        my $rv = $self->app->db->selectrow_hashref(
            "select token from confirmation_tokens where path='/confirm-email' ".
            "and user_id=\$1", {}, 1
        );
        return $self->render_text($rv->{token});
    });

    my $never = $auth->bridge->to('auth#allow_if', cond => sub {0});
    $never->get('/never' => sub { shift->render_text("Sometimes") });

    $auth->route('/users/list')->via('get')->to('users#list');
    $auth->route('/users/create')->via('post')->to('users#create');

    $auth->get('/p1' => sub {
        my $self = shift;
        $self->render(
            inline => q{<%= post_form '/p2' => begin %><%= text_field 'a' %><%= submit_button %><% end %>}
        );
    });

    my $sms = $auth->bridge->to('confirm#by_token');
    $sms->post('/p2' => sub {
        my $self = shift;
        $self->render_text("a is ".$self->param('a'));
    });

    # We have to connect as the admin in order to delete users.
    $r->any('/shutdown' => sub {
        my $self = shift;
        $self->app->db->do("drop table sprockets");
        my $dbh = DBI->connect("dbi:Pg:database=gadwall", "mallard", "")||die $DBI::errstr;
        $dbh->do("delete from users");
        $dbh->do("alter sequence users_user_id_seq restart with 1");
        $self->render_text("Goodbye!");
    });

    $r->any('/(*whatever)' => sub { shift->render_not_found });
}

sub Mojolicious::Controller::render_text {
    shift->render(format => 'txt', text => @_);
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

@@ widgets/wrapdiv.html.ep
<div>
<%= $content %>
<%= stash('x') || '' %>
</div>

@@ helpers.html.ep
% layout 'elaborate', title => "helpers";
% requires '/foo.js', '/foo.css', 'jquery-ui';
<% css begin %>
 foo { bar: 1; }
<% end %>
<% ready begin %>
 $("x").click(function(){return false});
<% end %>
foo bar
<% js begin %>
 var x = 1;
<% end %>
foo bar
<% ready begin %>
 var x = 2;
<% end %>
foo bar
<%= widget wrapdiv => (x=>3) => begin %>
 this should be <em>in</em> a div
<% end %>
<%= widget wrapdiv => begin %>
 this <b>should</b> be in a div
<% end %>
<%= stash('x') || "foo" %>
