package Inline::Filters::Uniprops2Ragel;

use strict;

use Encode;


our $props;

sub init_props {
  $props = {};

  open(my $fh, '<:encoding(utf-8)', 'unidata/GraphemeBreakProperty.txt')
    || die "couldn't open unidata/GraphemeBreakProperty.txt";

  while (<$fh>) {
    next if /^D800\.\.DFFF /; ## UTF-16 surrogate range is "unconditionally invalid in UTF-8"

    if (/^([A-F0-9]+)(?:\.\.([A-F0-9]+)|)\s+;\s+(\S+)/) {
      my ($start, $end, $prop) = ($1, $2, $3);

      $end ||= $start;

      $props->{$prop} ||= [];
      push @{ $props->{$prop} }, [$start, $end];
    }
  }
}

sub genragel {
  my $prop = shift;

  init_props() unless $props;

  my $ranges = $props->{$prop};

  die "unknown property '$prop'" if !defined $ranges;

  my @output;

  for my $b (@$ranges) {
    push @output, gen_block([ hex($b->[0]) .. hex($b->[1]) ]);
  }

  return '(' . join(' | ', @output) . ')';
}

sub genragel_all {
  my $output = '';

  foreach my $prop (keys %$props) {
    $output .= "  $prop = " . genragel($prop) . ";\n";
  }

  return $output;
}

sub filter {
  init_props() unless $props;

  return sub {
    my $inp = shift;

    $inp =~ s/ALL_UNIPROPS/genragel_all()/eg;

    return $inp;
  };
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

  return @output;
}



sub compress_encodings {
  my $recs = shift;
  my @bytes = split //, $recs->[0];
  my $last_byte_start = pop @bytes;

  my $output = '';

  $output .= (join ' ', map { "0x" . uc(sprintf("%02x", ord($_))) } @bytes);

  $output .= " 0x" . uc(sprintf("%02x", ord($last_byte_start)));

  $output =~ s/^ //; ## nice formatting hack

  if (@$recs > 1) {
    my @bytes2 = split //, $recs->[-1];
    my $last_byte_end = pop @bytes2;
    $output .= ".." . "0x" . uc(sprintf("%02x", ord($last_byte_end)));
  }

  return $output;
}


1;
