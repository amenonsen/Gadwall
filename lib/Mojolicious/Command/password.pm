package Mojolicious::Command::password;

use Mojo::Base 'Mojolicious::Command';

use Gadwall::Util 'bcrypt';

has description => "Change an application user's password\n";
has usage => <<"EOF";
usage: $0 password <email or login>

    $0 password foo\@example.com
EOF

sub run {
    my ($self, @args) = @_;

    my $name = shift @args || die $self->usage;

    # A quick hack to read a password
    system "stty", "-echo";
    print "Password: "; chomp(my $p1 = <STDIN>);
    print "\n";
    print "Password again: "; chomp(my $p2 = <STDIN>);
    print "\n";
    system "stty", "echo";

    my $password = bcrypt($p1);

    unless ($p1 eq $p2) {
        die "ERROR: Passwords do not match\n";
    }

    my $dbh = $self->app->db;
    $dbh->do(<<"    SQL", {}, $password, $name) || die $dbh->errstr;
        update users set password=?
            where coalesce(login, email)=?
    SQL
}

1;

=head1 NAME

Gadwall::Command::password - Change an application user's password

=head1 SYNOPSIS

    app password foo@example.org

=head1 DESCRIPTION

This command can be used to forcibly change an application user's
password in the database.

=cut
