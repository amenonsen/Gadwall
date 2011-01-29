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

sub new_cache {
    my ($port, $namespace) = @_;

    return unless $port;

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

    return $class->new({
        servers => ["127.0.0.1:$port"],
        namespace => "$namespace:"
    });
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
}

1;
