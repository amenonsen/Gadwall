use ExtUtils::MakeMaker;
WriteMakefile(
    NAME => "Gadwall",
    PREREQ_PM => {
        'Data::Entropy' => 0,
        'DBD::Pg' => '2.18.1',
        'Crypt::Eksblowfish::Bcrypt' => 0,
        'Mojolicious' => '4.10',
        'MIME::Lite' => 0,
    }
);
