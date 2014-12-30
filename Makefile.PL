use strict;

use ExtUtils::MakeMaker;


my %args = (
    NAME => 'Unicode::Truncate',
    VERSION_FROM => 'lib/Unicode/Truncate.pm',
    PREREQ_PM => {
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
);


my $eummv = eval ($ExtUtils::MakeMaker::VERSION);
if ($eummv >= 6.45) {
    $args{META_MERGE} = {
        resources => {
            repository => 'git://github.com/hoytech/Unicode-Truncate.git',
            bugtracker => 'https://github.com/hoytech/Unicode-Truncate/issues',
        },
    };
}

WriteMakefile(%args);
