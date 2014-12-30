## This simple script generates ragel expressions that match the utf-8 encodings of the provides ranges of unicode code-points

use strict;

use Encode;



gen([
  [ [ 0x300 .. 0x36F ], 'Combining Diacritical Marks' ],
  [ [ 0x1AB0 .. 0x1AFF ], 'Combining Diacritical Marks Extended' ],
  [ [ 0x1DC0 .. 0x1DFF ], 'Combining Diacritical Marks Supplement' ],
  [ [ 0x20D0 .. 0x20FF ], 'Combining Diacritical Marks for Symbols' ],
  [ [ 0xFE20 .. 0xFE2F ], 'Combining Half Marks' ],
]);



sub gen {
  my $blocks = shift;

  my @output;

  foreach my $block (@$blocks) {
    my $gened = gen_block($block->[0]);

    print join(' | ', @$gened);
    print " |" unless $block == $blocks->[-1];
    print " # $block->[1]\n";
  }
}

sub gen_block {
  my ($range) = @_;

  my $curr = [];
  my @output;

  foreach my $i (@$range) {
    my $encoded = encode("UTF-8", chr($i));

    if (!@$curr || (substr($encoded, 0, -1) eq substr($curr->[-1], 0, -1) && ord(substr($encoded, -1)) == ord(substr($curr->[-1], -1)) + 1)) {
      push @$curr, $encoded;
    } else {
      push @output, compress_encodings($curr);
      $curr = [ $encoded ];
    }
  }

  push @output, compress_encodings($curr);

  return \@output;
}

sub compress_encodings {
  my $recs = shift;
  my @bytes = split //, $recs->[0];
  my $last_byte_start = pop @bytes;

  my $output = '';

  $output .= (join ' ', map { "0x" . uc(sprintf("%2x", ord($_))) } @bytes);

  $output .= " 0x" . uc(sprintf("%2x", ord($last_byte_start)));

  if (@$recs > 1) {
    my @bytes2 = split //, $recs->[-1];
    my $last_byte_end = pop @bytes2;
    $output .= ".." . "0x" . uc(sprintf("%2x", ord($last_byte_end)));
  }

  return $output;
}
