package Mojolicious::Command::schema;

use Mojo::Base 'Mojolicious::Command';

use IPC::Run3 'run3';

has description => "Install or upgrade the application's database schema\n";
has usage => <<"EOF";
usage: $0 schema <install|upgrade> [options]

    $0 schema install
EOF

my $psql = "psql";

sub run {
    my ($self, @args) = @_;

    my $cmd = shift @args || die $self->usage;
    unless ($cmd eq "install") {
        die $self->usage;
    }

    chdir($self->app->home);

    $self->$cmd(@args);
}

sub install {
    my ($self, @args) = @_;

    my ($database, $owner, $user) =
        @{$self->app->config}{qw/db_name db_owner db_user/};

    my @files = map {"\\i $_\n"} <schema/*.sql>, @args;
    shift @files;

    (my $CMD = <<"    CMD") =~ s/^\s*//;
        \\set ON_ERROR_STOP
        SET client_min_messages TO 'error';

        CREATE USER $user;
        CREATE USER $owner;
        CREATE DATABASE $database WITH OWNER $owner;

        \\c $database
        \\set user $user
        SET client_min_messages TO 'error';
        CREATE OR REPLACE LANGUAGE plpgsql;
        \\i schema/000-extensions.sql
        SET SESSION AUTHORIZATION $owner;

        BEGIN;
        @files
        COMMIT;
    CMD

    say "Creating users, database, and schema...";
    run3 [qw[su -m postgres -c], $psql], \$CMD;
}

1;

=head1 NAME

Gadwall::Command::schema - Install or upgrade the application's database schema

=head1 SYNOPSIS

    app schema install
    app schema upgrade

=head1 DESCRIPTION

This command can install or upgrade the application's database schema.

=cut
