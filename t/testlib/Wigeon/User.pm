package Wigeon::User;

use strict;
use warnings;

use parent "Gadwall::Db::User";

sub role_names {qw(
    admin cook bottlewasher birdwatcher bearfighter backstabber bitcounter
)}

1;
