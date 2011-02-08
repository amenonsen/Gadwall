# Suppress the odious X-Powered-By header that Mojolicious generates by
# default.

package Mojolicious::Plugin::PoweredBy;

use Mojo::Base 'Mojolicious::Plugin';

sub register {
}

1;
