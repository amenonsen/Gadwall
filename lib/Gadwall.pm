package Gadwall;

use strict;
use warnings;

use DBI;

use base 'Mojolicious';

sub development_mode {
    my $app = shift;
    $app->log->path(undef);
}

sub config_defaults {
    my $self = shift;
    my $name = lc ref $self;

    return {
        "db-name" => $name, "db-user" => $name, "db-pass" => "",
        "memcached-namespace" => $name,
        secret => $main::random_secret
    };
}

sub new_dbh {
    my ($db, $user, $pass) = @_;
    my $dbh = DBI->connect(
        "dbi:Pg:database=$db", $user, $pass,
        {RaiseError => 0}
    ) or die $DBI::errstr;
    return $dbh;
}

# This function returns a Cache::Memcached-compatible object. Whether
# this object actually talks to a running memcached depends on whether
# memcached-port is set in the config file and whether Cache::Memcached
# (or an equivalent) is available.

sub new_cache {
    my ($port, $namespace) = @_;

    # Is caching explicitly disabled?
    return if defined $port && $port == 0;

    my @options = qw(
        Cache::Memcached::libmemcached
        Cache::Memcached
    );

    my $class;
    foreach (@options) {
        eval "require $_;";
        unless ($@) {
            $class = $_;
            last;
        }
    }
    unless ($class) {
        die "Cache::Memcached::libmemcached (or equivalent) is not available\n";
    }

    # Create a cache object: real if port is specified, dummy otherwise
    my $cache = $class->new({servers => [], namespace => "$namespace:"});
    if ($port) {
        $cache->set_servers(["127.0.0.1:$port"]);
    }

    return $cache;
}

# This function takes a list of controller names (e.g. "Users", "Auth").
# It looks for App::$name to see if any of them have been reimplemented
# by the derived application. If not, it loads our module and creates a
# dummy package inheriting from it in the App:: namespace. All this is
# so that one can refer to foo#bar in routes, no matter whether foo is
# App::Foo or Gadwall::Foo.
#
# This is a hack because it depends on the derived class names being the
# same as the native ones. But given that people who derive into another
# class on purpose are unlikely to write routes using the native name,
# its convenience outweighs the hackishness.

sub _shadow_controllers {
    my ($app, @names) = @_;

    my $class = ref $app;
    foreach my $name (@names) {
        if (my $e = Mojo::Loader->load("${class}::$name")) {
            die $e if ref $e;
            my $ours = "Gadwall::$name";
            Mojo::Loader->load($ours);
            {
                no strict 'refs';
                @{"${class}::${name}::ISA"} = ($ours);
            }
        }
    }
}

sub gadwall_setup {
    my $app = shift;

    my $conf = $app->plugin(
        json_config => { ext => 'conf', default => $app->config_defaults }
    );

    $app->secret($conf->{secret});

    (ref $app)->attr(
        db => sub { new_dbh(@$conf{qw/db-name db-user db-pass/}) }
    );

    (ref $app)->attr(
        cache => sub { new_cache(@$conf{qw/memcached-port memcached-namespace/}) }
    );

    $app->_shadow_controllers(qw(Auth Users));
}

1;
