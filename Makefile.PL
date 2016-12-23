use ExtUtils::MakeMaker;

WriteMakefile(
    NAME            => 'honeygen',
    VERSION         => "0.1.0",
    AUTHOR         => "Wenjun FAN",
    DISTDIR      => '/usr/share/',
    DISTNAME      => 'honeygen',
    EXE_FILES     => [qw(bin/HoneyGen)],
);
