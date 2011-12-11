package Gadwall::Log;

use Mojo::Base 'Mojo::Log';

use POSIX 'strftime';

sub format {
    my ($self, $level, @msgs) = @_;
    my $msgs = join "\n",
        map { utf8::decode $_ unless utf8::is_utf8 $_; $_ } @msgs;

    my $now = strftime('%Y-%m-%d %H:%M:%S', localtime);
    return "[$now] [$level] $msgs\n";
}

1;
