package Mojolicious::Command::exec;

use Mojo::Base 'Mojolicious::Command';

has description => "Execute a command in the application's context\n";
has usage => <<"EOF";
usage: $0 exec command [arguments]

    $0 exec perl -MSome::Module -e …
EOF

sub run {
    my ($self, @args) = @_;

    die $self->usage unless @args;

    chdir($self->app->home);
    $ENV{PERL5LIB} = "lib:local/lib/perl5";
    system(@args);
}

1;

=head1 NAME

Gadwall::Command::exec - Execute a command in the application's context

=head1 SYNOPSIS

    app exec perl -MSome::Module -e …

=head1 DESCRIPTION

This command can be used to run programs with the right working
directory and PERL5LIB settings for this application. It can be
used to make sure that cron jobs, for example, run in the right
environment without having to set it up themselves.

This is analogous to "carton exec …".

=cut
