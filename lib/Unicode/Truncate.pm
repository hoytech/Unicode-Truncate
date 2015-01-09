package Unicode::Truncate;

our $VERSION = '0.102';

use strict;
use utf8;

use Carp;
use Encode;

require Exporter;
use base 'Exporter';
our @EXPORT = qw(truncate_utf8);


use Unicode::Truncate::Inline C => 'DATA', FILTERS => [ [ 'Uniprops2Ragel' ], [ Ragel => '-G2' ] ];


sub truncate_utf8 {
  my ($input, $len, $ellipsis) = @_;

  croak "need to pass an input string to truncate_utf8" if !defined $input;
  croak "need to pass a positive truncation length to truncate_utf8" if !defined $len || $len < 0;

  $ellipsis = '…' if !defined $ellipsis;
  $ellipsis = encode('UTF-8', $ellipsis);

  $len -= length($ellipsis);

  croak "length of ellipsis is longer than truncation length" if $len < 0;

  my ($truncation_required, $cut_len, $error_occurred) = _scan_string($input, $len);

  croak "input string not valid UTF-8 (detected at byte offset $cut_len)" if $error_occurred;

  my $enc_input = encode('UTF-8', $input);

  if ($truncation_required) {
    my $output = substr($enc_input, 0, $cut_len) . $ellipsis;
    Encode::_utf8_on($output);
    return $output;
  }

  my $output = $enc_input;
  Encode::_utf8_on($output);
  return $output;
}



1;


__DATA__
__C__

%%{
  machine utf8_truncator;

  write data;
}%%


void _scan_string(SV *string, size_t trunc_size) {
  size_t cut_len = 0;
  int truncation_required = 0, error_occurred = 0;

  size_t len;
  char *start, *p, *pe, *eof, *ts, *te;
  int cs, act;
 
  SvUPGRADE(string, SVt_PV);
  if (!SvPOK(string)) croak("attempting to truncate_utf8 non-string object");

  len = SvCUR(string);
  ts = start = p = SvPV(string, len);
  te = eof = pe = p + len;

  %%{
    action record_cut {
      if (p - start >= trunc_size) {
        truncation_required = 1;
        goto done;
      }

      cut_len = te - start;
    }


    ## Extract properties from unidata/GraphemeBreakProperty.txt (see inc/Inline/Filters/Uniprops2Ragel.pm)

    ALL_UNIPROPS


    ## This regexp is pretty much a straight copy from the "extended grapheme cluster" row in this table:
    ## http://www.unicode.org/reports/tr29/#Table_Combining_Char_Sequences_and_Grapheme_Clusters

    CRLF = CR LF;

    RI_Sequence = Regional_Indicator+;

    Hangul_Syllable = L* V+ T* |
                      L* LV V* T* |
                      L* LVT T* |
                      L+ |
                      T+;

    main := |*
              CRLF => record_cut;

              (
                ((Any_UTF8 - Control) | Hangul_Syllable | RI_Sequence)
                (Extend | SpacingMark)*
              ) => record_cut;

              Any_UTF8 => record_cut;
            *|;


    write init;
    write exec;
  }%%

  done:

  if (cs < utf8_truncator_first_final) {
    error_occurred = 1;
    cut_len = p - start;
  }

  Inline_Stack_Vars;
  Inline_Stack_Reset;
  Inline_Stack_Push(sv_2mortal(newSViv(truncation_required)));
  Inline_Stack_Push(sv_2mortal(newSViv(cut_len)));
  Inline_Stack_Push(sv_2mortal(newSViv(error_occurred)));
  Inline_Stack_Done;
}



__END__

=encoding utf-8

=head1 NAME

Unicode::Truncate - Unicode-aware efficient string truncation

=head1 SYNOPSIS

    use Unicode::Truncate;

    truncate_utf8("hello world", 7);
    ## "hell…";

    truncate_utf8("hello world", 7, '');
    ## "hello w"

    truncate_utf8('深圳', 7);
    ## "深…"

=head1 DESCRIPTION

This module is for truncating UTF-8 encoded Unicode text to particular byte lengths while inflicting the least amount of data corruption possible. The resulting truncated string will be no longer than your specified number of bytes (after UTF-8 encoding).

With this module's C<truncate_utf8>, all truncated strings will continue to be valid UTF-8: it won't cut in the middle of a UTF-8 encoded code-point. Furthermore, if your text contains combining diacritical marks, this module will not cut in between a diacritical mark and the base character.


=head1 RATIONALE

Why not just use C<substr> on a string before UTF-8 encoding it? The main problem is that the number of bytes that an encoded string will consume is not known until after you encode it. It depends on how many "high" code-points are in the string, how "high" those code-points are, the normalisation form chosen, and (relatedly) how many combining marks are used. Even before encoding, C<substr> also may cut in front of combining marks.

Truncating post-encoding may result in invalid UTF-8 partials at the end of your string, as well as cutting in front of combining marks.

I knew I had to write this module after I asked Tom Christiansen about the best way to truncate unicode to fit in fixed-byte fields and he got angry and told me to never do that. :)

Of course in a perfect world we would only need to worry about the amount of space some text takes up on the screen, in the real world we often have to or want to make sure things fit within certain byte size capacity limits. Many data-bases, network protocols, and file-formats require honouring byte-length restrictions. Even if they automatically truncate for you, are they doing it properly and consistently? On many file-systems, file and directory names are subject to byte-size limits. Many APIs that use C structs have fixed limits as well. You may even wish to do things like guarantee that a collection of news headlines will fit in a single ethernet packet.

One interesting aspect of unicode's combining marks is that there is no specified limit to the number of combining marks that can be applied. So in some interpretations a single decomposed unicode character can take up an arbitrarily large number of bytes in its UTF-8 encoding. However, there are various recommendations such as the unicode standard L<UAX15-D3|http://www.unicode.org/reports/tr15/#UAX15-D3> "stream-safe" limit of 30. Reportedly the largest known "legitimate" use is a 1 base + 8 combining marks grapheme used in a Tibetan script.


=head1 ELLIPSIS

When a string is truncated, C<truncate_utf8> indicates this by appending an ellipsis. By default this is the character U+2026 (…) however you can use any other string by passing it in as the third argument. Note that in UTF-8 encoding the default ellipsis consumes 3 bytes (the same as 3 periods in a row). The length of the truncated content *including* the ellipsis is guaranteed to be no greater than the byte size limit you specified.


=head1 IMPLEMENTATION

This module uses the L<ragel|http://www.colm.net/open-source/ragel/> state machine compiler to parse/validate UTF-8 and to determine the presence of combining characters. Ragel is nice because we can determine the truncation location with a single pass through the data in an optimised C loop.

One feature of this design is that it will not scan further than it needs to in order to determine the truncation location. So creating short truncations of really long strings doesn't even require traversing the long strings.

Another purpose of this module is to be a "proof of concept" for the L<Inline::Filters::Ragel> source filter as well as a demonstration of the really cool L<Inline::Module> system.


=head1 SEE ALSO

L<Unicode-Truncate github repo|https://github.com/hoytech/Unicode-Truncate>

Although very efficient, as discussed above, C<substr> will not be able to give you a guaranteed byte-length output (if done pre-encoding) and/or will potentially corrupt text (if done post-encoding).

There are several similar modules such as L<Text::Truncate>, L<String::Truncate>, L<Text::Elide> but they are all essentially wrappers around C<substr> and are subject to its limitations.

A reasonable "99%" solution is to encode your string as UTF-8, truncate at the byte-level with C<substr>, decode with C<Encode::FB_QUIET>, and then re-encode it to UTF-8. This will ensure that the output is always valid UTF-8, but will still risk corrupting unicode text that contains combining marks.

Ricardo Signes suggested an algorithm using L<Unicode::GCString> which would be very correct but likely less efficient.

It may be possible to use the regexp engine's C<\X> combined with C<(?{})> in some way but I haven't been able to figure that out.


=head1 BUGS

This module currently only implements a sub-set of unicode's L<grapheme cluster boundary rules|http://www.unicode.org/reports/tr29/#Grapheme_Cluster_Boundaries>. Eventually I plan to extend this so the module "does the right thing" in more cases. Of course I can't test this on all the writing systems of the world so I don't know the severity of the corruption in all situations. It's possible that the corruption can be minimised in additional ways without sacrificing the simplicity or efficiency of the algorithm. If you have any ideas please let me know and I'll try to incorporate them.

One obvious enhancement for languages that use white-space is to chop off the last (potentially partial) word up to the next whitespace block: C<s/\S+$//> (note you'll have to worry about the ellipsis yourself in this case).

Currently building this module requires L<Inline::Filters::Ragel> to be installed. I'd like to add an option to L<Inline::Module> that has ragel run at dist time instead.

Perl internally supports characters outside what is officially unicode. This module only works with the official UTF-8 range so if you are using this perl extension (perhaps for some sort of non-unicode sentinel value) this module will throw an exception indicating invalid UTF-8 encoding.


=head1 AUTHOR

Doug Hoyte, C<< <doug@hcsw.org> >>

=head1 COPYRIGHT & LICENSE

Copyright 2014 Doug Hoyte.

This module is licensed under the same terms as perl itself.

=cut
