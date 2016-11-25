# Copyright (C) 2015-2016 Yoann Le Garff, Nicolas Boquet and Yann Le Bras
# navel-base-daemon is licensed under the Apache License, Version 2.0

#-> BEGIN

#-> initialization

use strict;
use warnings;

use ExtUtils::MakeMaker;

#-> main

my $min_perl_version = '5.18.0';

WriteMakefile(
    NAME => 'Navel::Base::Daemon',
    VERSION_FROM => 'lib/Navel/Base/Daemon.pm',
    ABSTRACT => 'navel-base-daemon',
    AUTHOR => 'Yoann Le Garff, Nicolas Boquet and Yann Le Bras',
    LICENSE => 'Apache License, Version 2.0',
    META_MERGE => {
        requires => {
            perl => $min_perl_version
        },
        resources => {
            license => 'http://www.apache.org/licenses/LICENSE-2.0.html',
            repository => 'http://github.com/Navel-IT/navel-base-daemon'
        }
    },
    MIN_PERL_VERSION => $min_perl_version,
    PREREQ_PM => {
        'Navel::Base' => 0,
        'Navel::Base::Definition' => 0,
        'Navel::Logger' => 0,
        'Getopt::Long::Descriptive' => 0,
        'Sys::Hostname' => 0,
        'Mojolicious' => 0,
        'Mojolicious::Plugin::OpenAPI' => 0,
        'Mojo::JSON::MaybeXS' => 0,
        'IO::Socket::SSL' => 1.84,
        'AnyEvent' => 0,
        'EV' => 0,
        'IO::AIO' => 0,
        'Promises' => 0
    },
    CONFIGURE_REQUIRES => {
        'ExtUtils::MakeMaker' => 6.64
    },
    TEST_REQUIRES => {
        'Test::More' => 0
    },
    test => {
        TESTS => 't/*.t'
    }
);

#-> END

__END__
