package Mojolicious::Command::schema;

use Mojo::Base 'Mojolicious::Command';

use IPC::Run3 'run3';
use Getopt::Long qw(GetOptionsFromArray :config no_auto_abbrev);

has description => "Install or upgrade the application's database schema.";
has usage => sub { shift->extract_usage };

my $psql;
my $schema;

sub run {
    my ($self, @args) = @_;

    my $cmd = shift @args || die $self->usage;
    unless ($cmd eq "install" || $cmd eq "upgrade") {
        die $self->usage;
    }

    unless (-d "schema") {
        chdir($self->app->home);
        unless (-d "schema") {
            die "$0: Can't find schema directory\n";
        }
    }

    GetOptionsFromArray(\@args,
        'psql=s' => \$psql,
        's|schema=s' => \$schema,
    );

    if ($psql && ! -x $psql) {
        die "$0: Can't execute psql command: $psql\n";
    }
    $psql ||= "psql";

    $self->$cmd(@args);
}

sub install {
    my ($self, @args) = @_;

    my $app = $self->app;

    my ($database, $owner, $user) =
        @{$app->config}{qw/db_name db_owner db_user/};

    my @files = map {"\\i $_\n"} <schema/*.sql>, @args;

    my $create_extensions = shift @files;

    my $create_users = <<"    USERS";
        CREATE USER $user;
        CREATE USER $owner;
        CREATE DATABASE $database WITH OWNER $owner;
    USERS

    my $create_schema = "";
    if ($schema) {
        $create_schema = <<"        SCHEMA";
            CREATE SCHEMA $schema;
            GRANT USAGE ON SCHEMA $schema TO $user;
            SET search_path TO $schema, public;
        SCHEMA
        $create_users .= <<"        USERS";
            ALTER USER $user SET search_path TO $schema, public;
            ALTER USER $owner SET search_path TO $schema, public;
        USERS
    }

    (my $script = <<"    CMD") =~ s/^\s*//;
        \\set user $user
        \\set ON_ERROR_STOP
        SET client_min_messages TO 'error';

        $create_users

        \\c $database
        SET client_min_messages TO 'error';

        $create_extensions

        SET SESSION AUTHORIZATION $owner;
        BEGIN;
            $create_schema
            @files
        COMMIT;
    CMD

    my @psql = ($psql);
    unless (getpwuid($<) eq "postgres") {
        unshift @psql, qw[su -m postgres -c];
    }

    say "Creating users, database, and schema...";
    run3 \@psql, \$script;
}

sub upgrade {
    my ($self, @args) = @_;

    my $app = $self->app;

    my ($database, $owner, $user) =
        @{$app->config}{qw/db_name db_owner db_user/};

    my $dbh = $app->dbh($app->config('db_name'), $app->config('db_owner'));

    my $tags = $dbh->selectall_arrayref(
        "select name, version from schema", {Slice => {}}
    );

    (my $template = <<"    CMD") =~ s/^\s*//;
        \\set user $user
        \\set ON_ERROR_STOP
        SET client_min_messages TO 'error';
        UPDATE schema SET version='%d' WHERE name='%s';
        \\i %s
    CMD

    foreach my $tag (@$tags) {
        my $name = $tag->{name};
        my $version = $tag->{version};
        my $next = $version+1;

        while (-f (my $file = "schema/upgrades/$name/${version}-to-${next}.sql")) {
            say ">>> $name: $file";

            my $script = sprintf $template, $next, $name, $file;
            run3 [$psql, '-q1f', '-', $database, $owner], \$script;
            exit if $?;

            $next = 1 + ++$version;
        }
    }
}

1;

=head1 NAME

Gadwall::Command::schema - Install or upgrade the application's database schema

=head1 SYNOPSIS

    Usage: ./app schema <install|upgrade> [options]

        sudo [-u postgres] ./app schema install
        ./app schema upgrade

    Options:
        --psql <path>           Specify path to psql executable (default: "psql")
        -s, --schema <name>     First create a schema and add it to search_path

=head1 DESCRIPTION

This command can install or upgrade the application's database schema.

The "schema install" command must be run either as the postgres user, or
as root, so as to be able to su to the postgres user without a password.

=cut
