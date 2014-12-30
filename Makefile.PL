use strict;

use ExtUtils::MakeMaker;

use lib 'inc';
use Inline::Module;
BEGIN { *Inline::Module::included_modules = sub { [] } } ## don't bundle in 100s of KBs of modules.. use build-time deps instead

my %args = (
    NAME => 'Unicode::Truncate',
    VERSION_FROM => 'lib/Unicode/Truncate.pm',
    PREREQ_PM => {
    },
    BUILD_REQUIRES => {
      'Inline::C' => 0,
      'Inline::Module' => 0,
      'Inline::Filters::Ragel' => 0, ## unfortunately... (requires ragel binary to be installed)
    },
    LIBS => [],
    DEFINE => '',
    LICENSE => 'perl',
    dist => {
      PREOP => 'pod2text $(VERSION_FROM) > $(DISTVNAME)/README',
    },
    postamble => {
      inline => {
        module => 'Unicode::Truncate',
        stub => 'Unicode::Truncate::Inline',
        ilsm => 'Inline::C',
        makestub => 1,
      },
    },
    META_MERGE => {
        resources => {
            repository => 'git://github.com/hoytech/Unicode-Truncate.git',
            bugtracker => 'https://github.com/hoytech/Unicode-Truncate/issues',
        },
    },
);

WriteMakefile(%args);
