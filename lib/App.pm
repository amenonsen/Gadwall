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

    $app->gadwall_setup();

    my $r = $app->routes;

    $r->any(
        '/' => sub { shift->render_plaintext("Hello world!") }
    );
}

1;
