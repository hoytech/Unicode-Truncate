use strict;

use utf8;

use Test::More qw(no_plan);
use Test::Exception;
use Test::ZeroCopy;

use Unicode::Truncate;


{
  my $str = "asdf";
  truncate_egc_inplace($str, 2, ".");
  is($str, "a.");
}

{
  my $str = "asd";
  truncate_egc_inplace($str, 4, "ABC");
  is($str, "aABC");
}

for my $i (0..10) {
  throws_ok { truncate_egc_inplace("asdfj", $i, '') } qr/input string can't be read-only/;
}


{
  my $str = "hello world";
  my $addr = Test::ZeroCopy::get_pv_address($str);

  truncate_egc_inplace($str, 6);

  is($str, 'hel…');
  is(Test::ZeroCopy::get_pv_address($str), $addr);
}

{
  ## This "test" just prints some info on perl internals

  my $limit = 130;

  my $reallocs = 0;
  my $non_reallocs = 0;

  for my $i (1 .. $limit) {
    my $str = "h" x $i;
    my $addr = Test::ZeroCopy::get_pv_address($str);

    truncate_egc_inplace($str, $i + 2);

    if ($addr == Test::ZeroCopy::get_pv_address($str)) {
      $non_reallocs++;
    } else {
      $reallocs++;
      diag("re-alloc detected at $i");
    }
  }

  diag("Re-alloc summary up to $limit: $reallocs / $non_reallocs");
}
