use ExtUtils::MakeMaker;
WriteMakefile(
    NAME => "Gadwall",
    PREREQ_PM => {
        'DBI' => 0,
        'Data::Entropy' => 0,
        'DBD::Pg' => '2.18.1',
        'Mojolicious' => '2.40',
        'Crypt::Eksblowfish::Bcrypt' => 0,
        'Crypt::Rijndael' => 0,
        'MIME::Lite' => 0,
    }
);
