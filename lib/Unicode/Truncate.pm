package Unicode::Truncate;

our $VERSION = '0.102';

use strict;
use utf8;

use Carp;
use Encode;

require Exporter;
use base 'Exporter';
our @EXPORT = qw(truncate_egc);


use Unicode::Truncate::Inline C => 'DATA', FILTERS => [ [ 'Uniprops2Ragel' ], [ Ragel => '-G2' ] ];


1;


__DATA__
__C__


SV *truncate_egc(SV *input, long trunc_size_long, ...) {
  Inline_Stack_Vars;

  size_t trunc_size;
  SV *ellipsis;
  char *input_p, *ellipsis_p;
  size_t input_len, ellipsis_len;
  size_t cut_len;
  int truncation_required, error_occurred;
  SV *output;
  char *output_p;
  size_t output_len;

  SvUPGRADE(input, SVt_PV);
  if (!SvPOK(input)) croak("need to pass a string in as first argument to truncate_egc");

  input_len = SvCUR(input);
  input_p = SvPV(input, input_len);

  if (trunc_size_long < 0) croak("trunc size argument to truncate_egc must be >= 0");
  trunc_size = (size_t) trunc_size_long;

  if (Inline_Stack_Items == 2) {
    ellipsis_len = 3;
    ellipsis_p = "\xE2\x80\xA6";
  } else if (Inline_Stack_Items == 3) {
    ellipsis = Inline_Stack_Item(2);

    SvUPGRADE(ellipsis, SVt_PV);
    if (!SvPOK(ellipsis)) croak("ellipsis must be a string in 3rd argument to truncate_egc");

    ellipsis_len = SvCUR(ellipsis);
    ellipsis_p = SvPV(ellipsis, ellipsis_len);

    if (!is_utf8_string(ellipsis_p, ellipsis_len)) croak("ellipsis must be utf-8 encoded in 3rd argument to truncate_egc");
  } else if (Inline_Stack_Items > 3) {
    croak("too many items passed to truncate_egc");
  }

  if (ellipsis_len > trunc_size) croak("length of ellipsis is longer than truncation length");
  trunc_size -= ellipsis_len;

  _scan_egc(input_p, input_len, trunc_size, &truncation_required, &cut_len, &error_occurred);

  if (error_occurred) croak("input string not valid UTF-8 (detected at byte offset %lu)", cut_len);

  if (truncation_required) {
    output_len = cut_len + ellipsis_len;

    output = newSVpvn("", 0);

    SvGROW(output, output_len);
    SvCUR_set(output, output_len);

    output_p = SvPV(output, output_len);

    memcpy(output_p, input_p, cut_len);
    memcpy(output_p + cut_len, ellipsis_p, ellipsis_len);
  } else {
    output = newSVpvn(input_p, input_len);
  }

  SvUTF8_on(output);

  return output;
}



%%{
  machine egc_scanner;

  write data;
}%%


void _scan_egc(char *input, size_t len, size_t trunc_size, int *truncation_required_out, size_t *cut_len_out, int *error_occurred_out) {
  size_t cut_len = 0;
  int truncation_required = 0, error_occurred = 0;

  char *start, *p, *pe, *eof, *ts, *te;
  int cs, act;
 
  ts = start = p = input;
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

    Hangul_Syllable = L* V+ T*    |
                      L* LV V* T* |
                      L* LVT T*   |
                      L+          |
                      T+;

    main := |*
              CRLF => record_cut;

              (
                ## No Prepend characters in unicode 7.0
                (RI_Sequence | Hangul_Syllable | (Any_UTF8 - Control))
                (Extend | SpacingMark)*
              ) => record_cut;

              Any_UTF8 => record_cut;
            *|;


    write init;
    write exec;
  }%%

  done:

  if (cs < egc_scanner_first_final) {
    error_occurred = 1;
    cut_len = p - start;
  }

  *truncation_required_out = truncation_required;
  *cut_len_out = cut_len;
  *error_occurred_out = error_occurred;
}



__END__

=encoding utf-8

=head1 NAME

Unicode::Truncate - Unicode-aware efficient string truncation

=head1 SYNOPSIS

    use Unicode::Truncate;

    truncate_egc("hello world", 7);
    ## returns "hell…";

    truncate_egc("hello world", 7, '');
    ## returns "hello w"

    truncate_egc('深圳', 7);
    ## returns "深…"

    truncate_egc("née Jones", 5)'
    ## returns "n…" (not "ne…", even in NFD)

=head1 DESCRIPTION

This module is for truncating UTF-8 encoded Unicode text to particular byte lengths while inflicting the least amount of data corruption possible. The resulting truncated string will be no longer than your specified number of bytes (after UTF-8 encoding).

All truncated strings will continue to be valid UTF-8: it won't cut in the middle of a UTF-8 encoded code-point. Furthermore, if your text contains combining diacritical marks, this module will not cut in between a diacritical mark and the base character.

The C<truncate_egc> function truncates only between L<extended grapheme clusters|> (as defined by L<Unicode TR29|http://www.unicode.org/reports/tr29/#Grapheme_Cluster_Boundaries>).


=head1 RATIONALE

Why not just use C<substr> on a string before UTF-8 encoding it? The main problem is that the number of bytes that an encoded string will consume is not known until after you encode it. It depends on how many "high" code-points are in the string, how "high" those code-points are, the normalisation form chosen, and (relatedly) how many combining marks are used. Even before encoding, C<substr> also may cut in front of combining marks.

Truncating post-encoding may result in invalid UTF-8 partials at the end of your string, as well as cutting in front of combining marks.

I knew I had to write this module after I asked Tom Christiansen about the best way to truncate unicode to fit in fixed-byte fields and he got angry and told me to never do that. :)

Of course in a perfect world we would only need to worry about the amount of space some text takes up on the screen, in the real world we often have to or want to make sure things fit within certain byte size capacity limits. Many data-bases, network protocols, and file-formats require honouring byte-length restrictions. Even if they automatically truncate for you, are they doing it properly and consistently? On many file-systems, file and directory names are subject to byte-size limits. Many APIs that use C structs have fixed limits as well. You may even wish to do things like guarantee that a collection of news headlines will fit in a single ethernet packet.

One interesting aspect of unicode's combining marks is that there is no specified limit to the number of combining marks that can be applied. So in some interpretations a single decomposed unicode character can take up an arbitrarily large number of bytes in its UTF-8 encoding. However, there are various recommendations such as the unicode standard L<UAX15-D3|http://www.unicode.org/reports/tr15/#UAX15-D3> "stream-safe" limit of 30. Reportedly the largest known "legitimate" use is a 1 base + 8 combining marks grapheme used in a Tibetan script.


=head1 ELLIPSIS

When a string is truncated, C<truncate_egc> indicates this by appending an ellipsis. By default this is the character U+2026 (…) however you can use any other string by passing it in as the third argument. Note that in UTF-8 encoding the default ellipsis consumes 3 bytes (the same as 3 periods in a row). The length of the truncated content *including* the ellipsis is guaranteed to be no greater than the byte size limit you specified.


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
