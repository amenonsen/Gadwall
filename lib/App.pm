package App;

use Mojo::Base 'Gadwall';

sub config_defaults {
    my $app = shift;

    return (
        $app->SUPER::config_defaults(),
        # ...more values here...
    );
}

sub startup {
    my $app = shift;

    $app->setup();

    my $r = $app->routes;

    my $secure = $r->bridge->to('auth#allow_secure');
    my $auth = $app->plugin('login');
    $auth->any(
        '/' => sub {
            shift->render(text => "Hello user!")
        }
    );

    $r->any(
        '/' => sub {
            shift->render(text => "Hello world!")
        }
    );
}

sub setup {
    my $app = shift;

    $app->gadwall_setup();
}

1;
