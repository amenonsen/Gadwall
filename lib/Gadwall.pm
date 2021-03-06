package Gadwall;

BEGIN {
    $ENV{MOJO_REVERSE_PROXY} = 1;
    $ENV{MOJO_MODE} ||= "production";
}

use Mojo::Base 'Mojolicious';

use DBI;
use Crypt::Rijndael;
use MIME::Base64 qw(encode_base64);
use Data::Entropy qw(with_entropy_source entropy_source);
use Data::Entropy::RawSource::CryptCounter;
use Data::Entropy::RawSource::Local;
use Data::Entropy::Source;
use POSIX "strftime";

sub config_defaults {
    my $self = shift;
    my $name = lc ref $self;

    return (
        db_name => $name, db_user => $name, db_pass => "",
        db_owner => "${name}admin", db_owner_pass => "",
        dequeued_name => $name,
        memcached_namespace => $name,
        owner_email => q{admin@localhost},
        secret => $main::random_secret,
        static_expiry_seconds => 60*60*24*365,
    );
}

sub gadwall_setup {
    my $app = shift;
    my $name = lc ref $app;

    # Format log messages with compact [YYYY-MM-DD HH:MM:SS] timestamps.
    $app->log->format(sub {
        '['. strftime('%Y-%m-%d %H:%M:%S', localtime(shift)) .']'.
        ' ['. shift .'] '. join("\n", @_, '');
    });

    $app->resolve_controllers(qw(Auth Users Confirm));

    my $path = undef;
    if ($app->mode eq 'production') {
        $path = "logs/${name}.log";
    }
    $app->log->path($path);

    $app->setup_random_source;

    my $conf = $app->plugin(
        config => { file => "${name}.conf", default => { $app->config_defaults } }
    );

    # We expect secrets.conf to contain configuration data that ought
    # not to be in version control (e.g. the cookie signing secret, or
    # database password).

    my $secrets = "secrets.conf";
    if (-f $app->home->rel_file($secrets)) {
        $conf = $app->plugin(
            config => { file => $secrets }
        );
    }

    my @secrets;
    foreach my $skey ("secrets", "secret") {
        if (exists $conf->{$skey}) {
            my $v = $conf->{$skey};
            push @secrets, (ref $v eq 'ARRAY' ? @$v : $v);
            last;
        }
    }
    delete @$conf{qw/secrets secret/};
    $app->secrets(\@secrets);

    (ref $app)->attr(database => sub {
        $app->dbh(map $app->config($_), qw(db_name db_user db_pass))
    });

    (ref $app)->attr(
        cache => sub { new_cache(@$conf{qw/memcached_port memcached_namespace/}) }
    );

    $app->sessions->secure(1);
    $app->allow_static_caching;
    $app->disallow_dynamic_caching;
    $app->detect_forwarded_https;

    $app->plugin('csrf');
    $app->plugin('page_construction');

    push @{$app->renderer->classes},
        map { "Gadwall::$_" } qw(Auth Users Confirm);
}

# Takes the name of a class, like Sprockets, and returns its full name,
# like Wigeon::Sprockets (or Gadwall::Sprockets, if that is not found).
# Returns undef if neither is found. If found, the module is loaded.

sub load {
    my ($self, $name) = @_;

    return unless defined $name;

    my $class;
    for my $p ("", ref $self, "Gadwall") {
        my $s = $p ? "${p}::$name" : $name;
        unless (my $e = Mojo::Loader->load($s)) {
            $class = $s;
            last;
        }
        else {
            die $e if ref $e;
        }
    }

    return $class;
}

# This function allows routes to refer to 'users#email', for example,
# regardless of whether Users refers to Gadwall::Users or App::Users
# (the latter being an application-defined subclass of the former).
#
# It takes a list of class names and creates App::$classname packages
# that inherit from Gadwall::$classname for any application subclasses
# that do not already exist. This is a hack, both because of how these
# packages are created, and because it depends on the derived classes
# having the same name as their parents (save the Gadwall:: prefix).
#
# Nevertheless, its convenience outweighs is strictly limited ugliness.

sub resolve_controllers {
    my ($app, @names) = @_;
    my @done;

    my $class = ref $app;
    foreach my $name (@names) {
        my $full = "${class}::$name";
        my $e = Mojo::Loader->load($full);
        next unless $e; die $e->message if ref $e;

        push @INC, sub {
            return unless $_[1] eq "$class/$name.pm";
            $INC{$_[1]} = 0;

            my $i = 0;
            return (sub {
                my @lines = (
                    "package $full; use Mojo::Base 'Gadwall::$name'; 1;"
                );
                return defined ($_ = $lines[${$_[1]}++]) ? 1 : 0;
            }, \$i)
        };

        require "$class/$name.pm";
        push @done, $name;
    }
}

# This function sets $main::prng to an AES CTR generator keyed
# with 256 bits of randomness from /dev/urandom.

sub setup_random_source {
    my $app = shift;

    unless (defined $main::prng) {
        with_entropy_source(
            Data::Entropy::Source->new(
                Data::Entropy::RawSource::Local->new("/dev/urandom"),
                "sysread"
            ), sub {
                $main::prng = Data::Entropy::Source->new(
                    Data::Entropy::RawSource::CryptCounter->new(
                        Crypt::Rijndael->new(entropy_source->get_bits(256))
                    ), "sysread"
                );
            }
        );
        $main::random_secret = encode_base64($main::prng->get_bits(128), "");
    }
}

# This function returns a database handle. It pings the server to find
# out if the current database handle is usable; and if not, replaces it
# with a new connection.

sub db {
    my $app = shift;

    unless ($app->database->ping) {
        $app->database($app->dbh(
            map $app->config($_), qw(db_name db_user db_pass)
        ));
    }

    return $app->database;
}

# This function returns a database handle created using the supplied
# database, username, and password, or dies if it cannot create one.

sub dbh {
    my $self = shift;
    my ($db, $user, $pass, $attrs) = @_;

    $attrs ||= {
        AutoCommit => 1, RaiseError => 0, PrintError => 0
    };
    $attrs->{pg_enable_utf8} = 1;

    my $dbh = DBI->connect("dbi:Pg:database=$db", $user, $pass, $attrs)
        or die $DBI::errstr;

    return $dbh;
}

# This function returns a Cache::Memcached-compatible object. Whether
# this object actually talks to a running memcached depends on whether
# memcached_port is set in the config file and whether Cache::Memcached
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

# This function causes static responses to be served with cache-friendly
# Expires and Cache-Control headers. The static_expiry_seconds parameter
# controls expiration; if set to undef, no changes are made to static
# responses.

sub allow_static_caching {
    my $app = shift;
    $app->hook(after_static => sub {
        my $c = shift;
        my $tx = $c->tx;

        my $s = $c->config('static_expiry_seconds');
        return unless defined $s;

        my $e = Mojo::Date->new(time+$s);

        $tx->res->headers->remove('Set-Cookie');
        $tx->res->headers->remove('Cache-Control');
        $tx->res->headers->header('Cache-Control' => "public");
        $tx->res->headers->header('Expires' => $e);
    });
}

# This function sets an Expiry time in the past and cache-unfriendly
# headers on outgoing responses (unless an Expiry time is defined in
# the response already).

sub disallow_dynamic_caching {
    my $app = shift;
    $app->hook(after_dispatch => sub {
        my $tx = shift;

        return if $tx->res->headers->header('Expires');
        $tx->res->headers->header(
            Expires => Mojo::Date->new(time-365*86400)
        );
        $tx->res->headers->header(
            'Cache-Control' => "max-age=1, no-cache"
        );
    });
}

# This function installs a hook to set the scheme of the request's base
# URL to https if X-Forwarded-HTTPS is set to 1 or X-Forwarded-Proto is
# set to https. (Recent versions of Mojolicious prefer the latter, but
# we accept both for compatibility with deployed applications.)

sub detect_forwarded_https {
    my $app = shift;
    $app->hook(before_dispatch => sub {
        my $c = shift;
        my $h = $c->req->headers;

        if (($h->header('X-Forwarded-HTTPS') // '') eq "1" ||
            lc($h->header('X-Forwarded-Proto') // '') eq "https")
        {
            $c->req->url->base->scheme('https');
        }
    });
}

# This is a shortcut to help register a bunch of content types.

sub register_types {
    my ($app, %types) = @_;

    foreach my $k (keys %types) {
        $app->types->type($k => $types{$k});
    }
}

1;
