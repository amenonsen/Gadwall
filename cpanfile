requires 'Mojolicious', '>= 5.00';
requires 'DBD::Pg', '>= 2.18.1';
requires 'Crypt::Eksblowfish::Bcrypt';
requires 'Data::Entropy';
requires 'MIME::Lite';

test_requires 'IO::Socket::SSL', '1.84';
test_requires 'IO::Socket::IP', '0.20';
test_requires 'Cache::Memcached';
