package Mojolicious::Command::adduser;

use Mojo::Base 'Mojolicious::Command';

use Gadwall::Util 'bcrypt';

has description => "Create an application user\n";
has usage => <<"EOF";
usage: $0 adduser <email> ["full name"] [login=name] [roles=r1,r2,r3,...]

    $0 adduser foo\@example.com "Foo Bar" login=foo roles=admin
EOF

sub run {
    my ($self, @args) = @_;

    my %f;

    $f{email} = shift @args || die $self->usage;

    if (@args && $args[0] !~ /=/) {
        $f{name} = shift @args;
    }

    while (@args) {
        my $w = shift @args;

        if ($w =~ s/^login=//) {
            $f{login} = $w or die "No login name specified\n";
        }
        elsif ($w =~ s/^roles=//) {
            my $class;
            for my $p (ref $self->app, "Gadwall") {
                my $s = "${p}::User";
                unless (my $e = Mojo::Loader->load($s)) {
                    $class = $s;
                    last;
                }
                else {
                    die $e if ref $e;
                }
            }

            my %known = map {($_=>1)} $class->role_names();

            my %wanted;
            for my $r (split /,/, $w) {
                unless (exists $known{$r}) {
                    die "Unrecognised role name: $r\n";
                }
                $wanted{"is_$r"} = 1;
            }

            $f{roles} = $class->roles_from_set(%wanted);
        }
        else {
            die "Unrecognised parameter: $w\n";
        }
    }

    # A quick hack to read a password
    system "stty", "-echo";
    print "Password: "; chomp(my $p1 = <STDIN>);
    print "\n";
    print "Password again: "; chomp(my $p2 = <STDIN>);
    print "\n";
    system "stty", "echo";

    $f{password} = bcrypt($p1);

    unless ($p1 eq $p2) {
        die "ERROR: Passwords do not match\n";
    }

    local $" = ",";
    my $dbh = $self->app->db;
    $dbh->do(<<"    SQL", {}, values %f) || die $dbh->errstr;
        insert into users (@{[keys %f]})
            values (@{[map "?", keys %f]})
    SQL
}

1;

=head1 NAME

Gadwall::Command::adduser - Create an application user

=head1 SYNOPSIS

    app adduser foo@example.org "Foo Bar" login=foo roles=admin

=head1 DESCRIPTION

This command can be used to create an application user in the database.

=cut
