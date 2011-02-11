package Gadwall;

use Mojo::Base 'Mojolicious';

use DBI;
use Crypt::Rijndael;
use MIME::Base64 qw(encode_base64);
use Data::Entropy qw(with_entropy_source entropy_source);
use Data::Entropy::RawSource::CryptCounter;
use Data::Entropy::RawSource::Local;
use Data::Entropy::Source;

sub development_mode {
    my $app = shift;
    $app->log->path(undef);
}

sub config_defaults {
    my $self = shift;
    my $name = lc ref $self;

    return (
        "db-name" => $name, "db-user" => $name, "db-pass" => "",
        "memcached-namespace" => $name,
        secret => $main::random_secret
    );
}

sub gadwall_setup {
    my $app = shift;

    $app->setup_random_source;

    my $conf = $app->plugin(
        json_config => { ext => 'conf', default => { $app->config_defaults } }
    );

    $app->secret($conf->{secret});
    $app->sessions->secure(1);

    (ref $app)->attr(
        db => sub { new_dbh(@$conf{qw/db-name db-user db-pass/}) }
    );

    (ref $app)->attr(
        cache => sub { new_cache(@$conf{qw/memcached-port memcached-namespace/}) }
    );

    delete @$conf{qw/secret db-pass/};

    $app->plugin('gadwall_helpers');

    # If we're running behind a reverse proxy, we rewrite the base
    # request URL so that we can generate canonical redirects.

    $app->hook(before_dispatch => sub {
        my $self = shift;

        my @proto = $self->req->headers->header('X-Forwarded-Protocol');
        if (@proto && pop @proto eq 'https') {
            $self->req->url->base->scheme('https');
        }

        my @host = $self->req->headers->header('X-Forwarded-Host');
        if (my $host = $conf->{"canonical-host"} || pop @host) {
            $self->req->url->base->authority($host);
        }

        my $scheme = $self->req->url->base->scheme;
        if (my $port = $conf->{"canonical-$scheme-port"}) {
            $self->req->url->base->port($port);
        }
    });

    $app->_shadow_controllers(qw(Auth Users));
}

# This function sets $main::prng to an AES CTR generator keyed with 256
# bits of hard-earned entropy from /dev/random. It really should be run
# only once per server, because the initial read may block for several
# seconds. (For convenience, it uses /dev/urandom if we're not running
# in production mode.)

sub setup_random_source {
    my $app = shift;

    my $production = $app->mode eq 'production';
    unless (defined $main::prng) {
        $app->log->debug(
            "Seeding ".($production ? "secure " : "")."PRNG..."
        );
        with_entropy_source(
            Data::Entropy::Source->new(
                Data::Entropy::RawSource::Local->new(
                    $production ? "/dev/random" : "/dev/urandom"
                ), "sysread"
            ), sub {
                $main::prng = Data::Entropy::Source->new(
                    Data::Entropy::RawSource::CryptCounter->new(
                        Crypt::Rijndael->new(entropy_source->get_bits(256))
                    ), "sysread"
                );
            }
        );
        $main::random_secret => encode_base64($main::prng->get_bits(128), ""),
    }
}

# This function returns a new database handle.

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
# by the derived application. If not, it creates a dummy package in the
# App:: namespace that inherits from the Gadwall:: module. All this is
# so that one can refer to foo#bar in routes, no matter whether foo is
# App::Foo or Gadwall::Foo.
#
# This is a hack because it depends on the derived class names being the
# same as the native ones. But given that people who derive into another
# class on purpose are unlikely to write routes using the native name,
# its convenience outweighs the hackishness.

sub _shadow_controllers {
    my ($app, @names) = @_;
    my @done;

    my $class = ref $app;
    foreach my $name (@names) {
        my $full = "${class}::$name";
        my $e = Mojo::Loader->load($full);
        next unless $e; die $e if ref $e;

        push @INC, sub {
            return unless $_[1] eq "$class/$name.pm";
            $INC{$_[1]} = 0;

            my $i = 0;
            return (sub {
                my @lines = (
                    "package $full; use parent 'Gadwall::$name'; 1;"
                );
                return defined ($_ = $lines[${$_[1]}++]) ? 1 : 0;
            }, \$i)
        };

        push @done, $name;
    }

    $app->log->debug(
        "Created shadow classes under ${class}:: for Gadwall::".
        join(", ", @done)
    ) if @done;
}

1;
