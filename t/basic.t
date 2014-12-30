use strict;

use utf8;

use Test::More qw(no_plan);
use Test::Exception;

use Unicode::Truncate;


## synopsis

is(truncate_bytes('hello world', 7), 'hell…');
is(truncate_bytes('hello world', 7, ''), 'hello w');

## basic unicode

is(truncate_bytes('深圳', 5), '…');
is(truncate_bytes('深圳', 6), '深…');
is(truncate_bytes('深圳', 7), '深…');
is(truncate_bytes('深圳', 8), '深…');
is(truncate_bytes('深圳', 9), '深圳');

is(truncate_bytes('深圳', 0, ''), '');
is(truncate_bytes('深圳', 1, ''), '');
is(truncate_bytes('深圳', 2, ''), '');
is(truncate_bytes('深圳', 3, ''), '深');
is(truncate_bytes('深圳', 4, ''), '深');
is(truncate_bytes('深圳', 5, ''), '深');
is(truncate_bytes('深圳', 6, ''), '深圳');
is(truncate_bytes('深圳', 7, ''), '深圳');

is(truncate_bytes('До свидания', 14, ''), 'До свид');
is(truncate_bytes('До свидания', 15, ''), 'До свида');
is(truncate_bytes('До свидания', 16, ''), 'До свида');
is(truncate_bytes('До свидания', 17, ''), 'До свидан');

## malformed error reporting

throws_ok { truncate_bytes("\xFF", 100) } qr/not valid UTF-8 .*detected at byte offset 0\b/;
throws_ok { truncate_bytes("cbs\xCE\x80dd\xFFasdff", 100) } qr/not valid UTF-8 .*detected at byte offset 7\b/;

throws_ok { truncate_bytes("blah", 0) } qr/length of ellipsis is longer than truncation length/;
throws_ok { truncate_bytes("blah", 1) } qr/length of ellipsis is longer than truncation length/;
throws_ok { truncate_bytes("blah", 2) } qr/length of ellipsis is longer than truncation length/;
lives_ok { truncate_bytes("blah", 3) };

## overlong encodings

throws_ok { truncate_bytes("\xC0\x80", 10) } qr/not valid UTF-8/;
throws_ok { truncate_bytes("\xC0\xa0", 10) } qr/not valid UTF-8/;
throws_ok { truncate_bytes("\xF0\x82\x82\xAC", 10) } qr/not valid UTF-8/;

## combining characters

is(truncate_bytes("ne\x{301}e", 0, ''), '');
is(truncate_bytes("ne\x{301}e", 1, ''), 'n');
is(truncate_bytes("ne\x{301}e", 2, ''), 'n');
is(truncate_bytes("ne\x{301}e", 3, ''), 'n');
is(truncate_bytes("ne\x{301}e", 4, ''), 'né');
is(truncate_bytes("ne\x{301}e", 5, ''), 'née');

is(truncate_bytes("ne\x{301}\x{1DD9}\x{FE26}e", 2, ''), 'n');
is(truncate_bytes("ne\x{301}\x{1DD9}\x{FE26}e", 8, ''), "n");
is(truncate_bytes("ne\x{301}\x{1DD9}\x{FE26}e", 9, ''), "n");
is(truncate_bytes("ne\x{301}\x{1DD9}\x{FE26}e", 10, ''), "ne\x{301}\x{1DD9}\x{FE26}");
is(truncate_bytes("ne\x{301}\x{1DD9}\x{FE26}e", 11, ''), "ne\x{301}\x{1DD9}\x{FE26}e");
is(truncate_bytes("ne\x{301}\x{1DD9}\x{FE26}e", 12, ''), "ne\x{301}\x{1DD9}\x{FE26}e");
