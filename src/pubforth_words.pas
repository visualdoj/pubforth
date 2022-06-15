unit pubforth_words;
// Author:  Doj
// License: Public domain or MIT

//
//  Static database of all known words with some metadata and functions for
//  manipulating word names.
//
//  Possible usages
//  * Better error printing: e.g. with this library we can check if a word is not
//    yet implemented or it is unknown at all
//  * Generating words lists, e.g. for plan in the README.md
//

{$MODE FPC}
{$MODESWITCH DEFAULTPARAMETERS}
{$MODESWITCH OUT}
{$MODESWITCH RESULT}

interface

uses
  ddateprimitives;

const
  // Flags
  FLAG_FORTH2012                = 1 shl 16; // the word in the Forth 2012 Specification set
  FLAG_FORTH2012_EXTENSION      = FLAG_FORTH2012 or (1 shl 17);  // the word is from some Extension word set
  FLAG_FORTH2012_CORE           = FLAG_FORTH2012 or (1 shl 0);   // the word is from Core word set
  FLAG_FORTH2012_BLOCK          = FLAG_FORTH2012 or (1 shl 1);
  FLAG_FORTH2012_DOUBLE         = FLAG_FORTH2012 or (1 shl 2);
  FLAG_FORTH2012_EXCEPTION      = FLAG_FORTH2012 or (1 shl 3);
  FLAG_FORTH2012_FACILITY       = FLAG_FORTH2012 or (1 shl 4);
  FLAG_FORTH2012_FILE           = FLAG_FORTH2012 or (1 shl 5);
  FLAG_FORTH2012_FLOAT          = FLAG_FORTH2012 or (1 shl 6);
  FLAG_FORTH2012_LOCALS         = FLAG_FORTH2012 or (1 shl 7);
  FLAG_FORTH2012_MEMORY         = FLAG_FORTH2012 or (1 shl 8);
  FLAG_FORTH2012_TOOLS          = FLAG_FORTH2012 or (1 shl 9);
  FLAG_FORTH2012_SEARCH         = FLAG_FORTH2012 or (1 shl 10);
  FLAG_FORTH2012_STRING         = FLAG_FORTH2012 or (1 shl 11);
  FLAG_FORTH2012_XCHAR          = FLAG_FORTH2012 or (1 shl 12);
  FLAG_FORTH2012_CORE_EXT       = FLAG_FORTH2012_CORE      or FLAG_FORTH2012_EXTENSION;
  FLAG_FORTH2012_BLOCK_EXT      = FLAG_FORTH2012_BLOCK     or FLAG_FORTH2012_EXTENSION;
  FLAG_FORTH2012_DOUBLE_EXT     = FLAG_FORTH2012_DOUBLE    or FLAG_FORTH2012_EXTENSION;
  FLAG_FORTH2012_EXCEPTION_EXT  = FLAG_FORTH2012_EXCEPTION or FLAG_FORTH2012_EXTENSION;
  FLAG_FORTH2012_FACILITY_EXT   = FLAG_FORTH2012_FACILITY  or FLAG_FORTH2012_EXTENSION;
  FLAG_FORTH2012_FILE_EXT       = FLAG_FORTH2012_FILE      or FLAG_FORTH2012_EXTENSION;
  FLAG_FORTH2012_FLOAT_EXT      = FLAG_FORTH2012_FLOAT     or FLAG_FORTH2012_EXTENSION;
  FLAG_FORTH2012_LOCALS_EXT     = FLAG_FORTH2012_LOCALS    or FLAG_FORTH2012_EXTENSION;
  FLAG_FORTH2012_MEMORY_EXT     = FLAG_FORTH2012_MEMORY    or FLAG_FORTH2012_EXTENSION;
  FLAG_FORTH2012_TOOLS_EXT      = FLAG_FORTH2012_TOOLS     or FLAG_FORTH2012_EXTENSION;
  FLAG_FORTH2012_SEARCH_EXT     = FLAG_FORTH2012_SEARCH    or FLAG_FORTH2012_EXTENSION;
  FLAG_FORTH2012_STRING_EXT     = FLAG_FORTH2012_STRING    or FLAG_FORTH2012_EXTENSION;
  FLAG_FORTH2012_XCHAR_EXT      = FLAG_FORTH2012_XCHAR     or FLAG_FORTH2012_EXTENSION;
  FLAG_EXPERIMENT               = 1 shl 18; // the word has experimental support
  FLAG_PUBFORTH_REPL            = 1 shl 19; // the word is used only in PubForth REPL mode
  FLAG_PUBFORTH_MILESTONE       = 1 shl 20; // not a word, but pubforth release
  FLAG_IMPLEMENTED              = 1 shl 21;
  FLAG_OBSOLESCENT              = 1 shl 22; // Forth 2012 marks some words as obsolescent

type
PWordInfo = ^TWordInfo;
TWordInfo = record
  N: PAnsiChar; // Name of the word
  E: PAnsiChar; // Escaped name in form letter (letter|digit|_)*
  T: UInt32;    // Timestamp of implemented date or planned date
  F: UInt32;    // Set of flags, see constants above
end;

procedure PrintDevelopmentPlan;

function PatchReadmeFile(const FileName: AnsiString): Boolean;
      // Rewrites plan in the README.md file.



implementation

//  ---------------------------------------------------------------------------
//  This software is available under 2 licenses -- choose whichever you prefer.
//  ---------------------------------------------------------------------------
//  ALTERNATIVE A - MIT License
//
//  Copyright (c) 2022 Viktor Matuzenko aka Doj
//
//  Permission is hereby granted, free of charge, to any person obtaining a
//  copy of this software and associated documentation files (the "Software"),
//  to deal in the Software without restriction, including without limitation
//  the rights to use, copy, modify, merge, publish, distribute, sublicense,
//  and/or sell copies of the Software, and to permit persons to whom the
//  Software is furnished to do so, subject to the following conditions:
//
//  The above copyright notice and this permission notice shall be included in
//  all copies or substantial portions of the Software.
//
//  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
//  IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
//  FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
//  AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
//  LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING
//  FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER
//  DEALINGS IN THE SOFTWARE.
//
//  ---------------------------------------------------------------------------
//  ALTERNATIVE B - Public Domain (www.unlicense.org)
//
//  This is free and unencumbered software released into the public domain.
//
//  Anyone is free to copy, modify, publish, use, compile, sell, or distribute
//  this software, either in source code form or as a compiled binary, for any
//  purpose, commercial or non-commercial, and by any means.
//
//  In jurisdictions that recognize copyright laws, the author or authors of
//  this software dedicate any and all copyright interest in the software to
//  the public domain. We make this dedication for the benefit of the public at
//  large and to the detriment of our heirs and successors. We intend this
//  dedication to be an overt act of relinquishment in perpetuity of all
//  present and future rights to this software under copyright law.
//
//  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
//  IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
//  FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
//  AUTHORS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN
//  ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN
//  CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
//
//  For more information, please refer to <http://unlicense.org/>
//  ---------------------------------------------------------------------------

const
STATIC_WORDS_ARRAY: array[0 .. 480 - 1] of TWordInfo = (
  // Words should be ordered by the planned sequence of implementation

  (N: '[Initial repository, build, test](docs/news/initial.md)';         E: nil; T: 1655177154; F: FLAG_PUBFORTH_MILESTONE),
  (N: '[GitHub workflow](docs/news/workflow.md)';                        E: nil; T: 1655325933; F: FLAG_PUBFORTH_MILESTONE),
  (N: '`PubForth 0.0.0`: Zero-day release with effectively no words supported';     E: nil; T: 0; F: FLAG_PUBFORTH_MILESTONE),

  (N: ':';                  E: 'colon';               T: 0; F: FLAG_FORTH2012_CORE),
  (N: ';';                  E: 'semicolon';           T: 0; F: FLAG_FORTH2012_CORE),
  (N: '."';                 E: 'dot_quote';           T: 0; F: FLAG_FORTH2012_CORE),
  (N: 'CR';                 E: nil;                   T: 0; F: FLAG_FORTH2012_CORE),
  (N: '(';                  E: 'paren';               T: 0; F: FLAG_FORTH2012_CORE),
  (N: '\';                  E: 'backslash';           T: 0; F: FLAG_FORTH2012_CORE_EXT),
  (N: '`PubForth 0.1.0`: "Hello world" starter pack';    E: nil; T: 0; F: FLAG_PUBFORTH_MILESTONE),

  (N: '.';                  E: 'dot';                 T: 0; F: FLAG_FORTH2012_CORE),
  (N: 'SWAP';               E: nil;                   T: 0; F: FLAG_FORTH2012_CORE),
  (N: 'OVER';               E: nil;                   T: 0; F: FLAG_FORTH2012_CORE),
  (N: 'DROP';               E: nil;                   T: 0; F: FLAG_FORTH2012_CORE),
  (N: 'DUP';                E: nil;                   T: 0; F: FLAG_FORTH2012_CORE),
  (N: 'NIP';                E: nil;                   T: 0; F: FLAG_FORTH2012_CORE_EXT),
  (N: 'ROT';                E: nil;                   T: 0; F: FLAG_FORTH2012_CORE),
  (N: '+';                  E: 'plus';                T: 0; F: FLAG_FORTH2012_CORE),
  (N: '-';                  E: 'minus';               T: 0; F: FLAG_FORTH2012_CORE),
  (N: '*';                  E: 'star';                T: 0; F: FLAG_FORTH2012_CORE),
  (N: '/';                  E: 'slash';               T: 0; F: FLAG_FORTH2012_CORE),
  (N: '0<';                 E: 'zero_less';           T: 0; F: FLAG_FORTH2012_CORE),
  (N: '0=';                 E: 'zero_equals';         T: 0; F: FLAG_FORTH2012_CORE),
  (N: '0<>';                E: 'zero_not_equals';     T: 0; F: FLAG_FORTH2012_CORE_EXT),
  (N: '0>';                 E: 'zero_greater';        T: 0; F: FLAG_FORTH2012_CORE_EXT),
  (N: '1+';                 E: 'one_plus';            T: 0; F: FLAG_FORTH2012_CORE),
  (N: '1-';                 E: 'one_minus';           T: 0; F: FLAG_FORTH2012_CORE),
  (N: '<';                  E: 'less_than';           T: 0; F: FLAG_FORTH2012_CORE),
  (N: '>';                  E: 'greater_than';        T: 0; F: FLAG_FORTH2012_CORE),
  (N: '=';                  E: 'equals';              T: 0; F: FLAG_FORTH2012_CORE),
  (N: '<>';                 E: 'not_equals';          T: 0; F: FLAG_FORTH2012_CORE_EXT),
  (N: 'M*';                 E: 'm_star';              T: 0; F: FLAG_FORTH2012_CORE),
  (N: '*/';                 E: 'star_slash';          T: 0; F: FLAG_FORTH2012_CORE),
  (N: '/MOD';               E: 'slash_mod';           T: 0; F: FLAG_FORTH2012_CORE),
  (N: '*/MOD';              E: 'star_slash_mod';      T: 0; F: FLAG_FORTH2012_CORE),
  (N: 'FM/MOD';             E: 'f_m_slash_mod';       T: 0; F: FLAG_FORTH2012_CORE),
  (N: 'SM/REM';             E: 's_m_slash_rem';       T: 0; F: FLAG_FORTH2012_CORE),
  (N: 'MAX';                E: nil;                   T: 0; F: FLAG_FORTH2012_CORE),
  (N: 'MIN';                E: nil;                   T: 0; F: FLAG_FORTH2012_CORE),
  (N: 'MOD';                E: nil;                   T: 0; F: FLAG_FORTH2012_CORE),
  (N: '?DUP';               E: 'question_dupe';       T: 0; F: FLAG_FORTH2012_CORE),
  (N: 'NEGATE';             E: nil;                   T: 0; F: FLAG_FORTH2012_CORE),
  (N: 'FALSE';              E: nil;                   T: 0; F: FLAG_FORTH2012_CORE_EXT),
  (N: 'TRUE';               E: nil;                   T: 0; F: FLAG_FORTH2012_CORE_EXT),
  (N: 'INVERT';             E: nil;                   T: 0; F: FLAG_FORTH2012_CORE),
  (N: 'AND';                E: nil;                   T: 0; F: FLAG_FORTH2012_CORE),
  (N: 'OR';                 E: nil;                   T: 0; F: FLAG_FORTH2012_CORE),
  (N: 'XOR';                E: nil;                   T: 0; F: FLAG_FORTH2012_CORE),
  (N: 'LSHIFT';             E: nil;                   T: 0; F: FLAG_FORTH2012_CORE),
  (N: 'RSHIFT';             E: nil;                   T: 0; F: FLAG_FORTH2012_CORE),
  (N: 'U.';                 E: 'u_dot';               T: 0; F: FLAG_FORTH2012_CORE),
  (N: 'U<';                 E: 'u_less_than';         T: 0; F: FLAG_FORTH2012_CORE),
  (N: 'UM*';                E: 'u_m_star';            T: 0; F: FLAG_FORTH2012_CORE),
  (N: 'UM/MOD';             E: 'u_m_slash_mod';       T: 0; F: FLAG_FORTH2012_CORE),
  (N: 'U>';                 E: 'u_greater_than';      T: 0; F: FLAG_FORTH2012_CORE_EXT),
  (N: 'BASE';               E: nil;                   T: 0; F: FLAG_FORTH2012_CORE),
  (N: 'DECIMAL';            E: nil;                   T: 0; F: FLAG_FORTH2012_CORE),
  (N: 'HEX';                E: nil;                   T: 0; F: FLAG_FORTH2012_CORE_EXT),
  (N: '`PubForth 0.2.0`: "Stack calculator" edition';    E: nil; T: 0; F: FLAG_PUBFORTH_MILESTONE),

  (N: '!';                  E: 'store';               T: 0; F: FLAG_FORTH2012_CORE),
  (N: '#';                  E: 'number_sign';         T: 0; F: FLAG_FORTH2012_CORE),
  (N: '#>';                 E: 'number_sign_greater'; T: 0; F: FLAG_FORTH2012_CORE),
  (N: '#S';                 E: 'number_sign_s';       T: 0; F: FLAG_FORTH2012_CORE),
  (N: '''';                 E: 'tick';                T: 0; F: FLAG_FORTH2012_CORE),
  (N: '+!';                 E: 'plus_store';          T: 0; F: FLAG_FORTH2012_CORE),
  (N: '+LOOP';              E: 'plus_loop';           T: 0; F: FLAG_FORTH2012_CORE),
  (N: ',';                  E: 'comma';               T: 0; F: FLAG_FORTH2012_CORE),
  (N: '2!';                 E: 'two_store';           T: 0; F: FLAG_FORTH2012_CORE),
  (N: '2*';                 E: 'two_star';            T: 0; F: FLAG_FORTH2012_CORE),
  (N: '2/';                 E: 'two_slash';           T: 0; F: FLAG_FORTH2012_CORE),
  (N: '2@';                 E: 'two_fetch';           T: 0; F: FLAG_FORTH2012_CORE),
  (N: '2DROP';              E: 'two_drop';            T: 0; F: FLAG_FORTH2012_CORE),
  (N: '2DUP';               E: 'two_dup';             T: 0; F: FLAG_FORTH2012_CORE),
  (N: '2OVER';              E: 'two_over';            T: 0; F: FLAG_FORTH2012_CORE),
  (N: '2SWAP';              E: 'two_swap';            T: 0; F: FLAG_FORTH2012_CORE),
  (N: '<#';                 E: 'less_number_sign';    T: 0; F: FLAG_FORTH2012_CORE),
  (N: '>BODY';              E: 'to_body';             T: 0; F: FLAG_FORTH2012_CORE),
  (N: '>IN';                E: 'to_in';               T: 0; F: FLAG_FORTH2012_CORE),
  (N: '>NUMBER';            E: 'to_number';           T: 0; F: FLAG_FORTH2012_CORE),
  (N: '>R';                 E: 'to_r';                T: 0; F: FLAG_FORTH2012_CORE),
  (N: '@';                  E: 'fetch';               T: 0; F: FLAG_FORTH2012_CORE),
  (N: 'ABORT';              E: nil;                   T: 0; F: FLAG_FORTH2012_CORE),
  (N: 'ABORT"';             E: nil;                   T: 0; F: FLAG_FORTH2012_CORE),
  (N: 'ABS';                E: nil;                   T: 0; F: FLAG_FORTH2012_CORE),
  (N: 'ACCEPT';             E: nil;                   T: 0; F: FLAG_FORTH2012_CORE),
  (N: 'ALIGN';              E: nil;                   T: 0; F: FLAG_FORTH2012_CORE),
  (N: 'ALIGNED';            E: nil;                   T: 0; F: FLAG_FORTH2012_CORE),
  (N: 'ALLOT';              E: nil;                   T: 0; F: FLAG_FORTH2012_CORE),
  (N: 'BEGIN';              E: nil;                   T: 0; F: FLAG_FORTH2012_CORE),
  (N: 'BL';                 E: nil;                   T: 0; F: FLAG_FORTH2012_CORE),
  (N: 'C!';                 E: 'c_store';             T: 0; F: FLAG_FORTH2012_CORE),
  (N: 'C,';                 E: 'c_comma';             T: 0; F: FLAG_FORTH2012_CORE),
  (N: 'C@';                 E: 'c_fetch';             T: 0; F: FLAG_FORTH2012_CORE),
  (N: 'CELL+';              E: 'cell_plus';           T: 0; F: FLAG_FORTH2012_CORE),
  (N: 'CELLS';              E: nil;                   T: 0; F: FLAG_FORTH2012_CORE),
  (N: 'CHAR';               E: nil;                   T: 0; F: FLAG_FORTH2012_CORE),
  (N: 'CHAR+';              E: 'char_plus';           T: 0; F: FLAG_FORTH2012_CORE),
  (N: 'CHARS';              E: nil;                   T: 0; F: FLAG_FORTH2012_CORE),
  (N: 'CONSTANT';           E: nil;                   T: 0; F: FLAG_FORTH2012_CORE),
  (N: 'COUNT';              E: nil;                   T: 0; F: FLAG_FORTH2012_CORE),
  (N: 'CREATE';             E: nil;                   T: 0; F: FLAG_FORTH2012_CORE),
  (N: 'DEPTH';              E: nil;                   T: 0; F: FLAG_FORTH2012_CORE),
  (N: 'DO';                 E: nil;                   T: 0; F: FLAG_FORTH2012_CORE),
  (N: 'DOES>';              E: 'does';                T: 0; F: FLAG_FORTH2012_CORE),
  (N: 'ELSE';               E: nil;                   T: 0; F: FLAG_FORTH2012_CORE),
  (N: 'EMIT';               E: nil;                   T: 0; F: FLAG_FORTH2012_CORE),
  (N: 'ENVIRONMENT?';       E: 'environment_query';   T: 0; F: FLAG_FORTH2012_CORE or FLAG_OBSOLESCENT),
  (N: 'EVALUATE';           E: nil;                   T: 0; F: FLAG_FORTH2012_CORE),
  (N: 'EXECUTE';            E: nil;                   T: 0; F: FLAG_FORTH2012_CORE),
  (N: 'EXIT';               E: nil;                   T: 0; F: FLAG_FORTH2012_CORE),
  (N: 'FILL';               E: nil;                   T: 0; F: FLAG_FORTH2012_CORE),
  (N: 'FIND';               E: nil;                   T: 0; F: FLAG_FORTH2012_CORE),
  (N: 'HERE';               E: nil;                   T: 0; F: FLAG_FORTH2012_CORE),
  (N: 'HOLD';               E: nil;                   T: 0; F: FLAG_FORTH2012_CORE),
  (N: 'I';                  E: nil;                   T: 0; F: FLAG_FORTH2012_CORE),
  (N: 'IF';                 E: nil;                   T: 0; F: FLAG_FORTH2012_CORE),
  (N: 'IMMEDIATE';          E: nil;                   T: 0; F: FLAG_FORTH2012_CORE),
  (N: 'J';                  E: nil;                   T: 0; F: FLAG_FORTH2012_CORE),
  (N: 'KEY';                E: nil;                   T: 0; F: FLAG_FORTH2012_CORE),
  (N: 'LEAVE';              E: nil;                   T: 0; F: FLAG_FORTH2012_CORE),
  (N: 'LITERAL';            E: nil;                   T: 0; F: FLAG_FORTH2012_CORE),
  (N: 'LOOP';               E: nil;                   T: 0; F: FLAG_FORTH2012_CORE),
  (N: 'MOVE';               E: nil;                   T: 0; F: FLAG_FORTH2012_CORE),
  (N: 'POSTPONE';           E: nil;                   T: 0; F: FLAG_FORTH2012_CORE),
  (N: 'QUIT';               E: nil;                   T: 0; F: FLAG_FORTH2012_CORE),
  (N: 'R>';                 E: 'r_from';              T: 0; F: FLAG_FORTH2012_CORE),
  (N: 'R@';                 E: 'r_fetch';             T: 0; F: FLAG_FORTH2012_CORE),
  (N: 'RECURSE';            E: nil;                   T: 0; F: FLAG_FORTH2012_CORE),
  (N: 'REPEAT';             E: nil;                   T: 0; F: FLAG_FORTH2012_CORE),
  (N: 'S"';                 E: 's_quote';             T: 0; F: FLAG_FORTH2012_CORE),
  (N: 'S>D';                E: 's_to_d';              T: 0; F: FLAG_FORTH2012_CORE),
  (N: 'SIGN';               E: nil;                   T: 0; F: FLAG_FORTH2012_CORE),
  (N: 'SOURCE';             E: nil;                   T: 0; F: FLAG_FORTH2012_CORE),
  (N: 'SPACE';              E: nil;                   T: 0; F: FLAG_FORTH2012_CORE),
  (N: 'SPACES';             E: nil;                   T: 0; F: FLAG_FORTH2012_CORE),
  (N: 'STATE';              E: nil;                   T: 0; F: FLAG_FORTH2012_CORE),
  (N: 'THEN';               E: nil;                   T: 0; F: FLAG_FORTH2012_CORE),
  (N: 'TYPE';               E: nil;                   T: 0; F: FLAG_FORTH2012_CORE),
  (N: 'UNLOOP';             E: nil;                   T: 0; F: FLAG_FORTH2012_CORE),
  (N: 'UNTIL';              E: nil;                   T: 0; F: FLAG_FORTH2012_CORE),
  (N: 'VARIABLE';           E: nil;                   T: 0; F: FLAG_FORTH2012_CORE),
  (N: 'WHILE';              E: nil;                   T: 0; F: FLAG_FORTH2012_CORE),
  (N: 'WORD';               E: nil;                   T: 0; F: FLAG_FORTH2012_CORE),
  (N: '[';                  E: 'left_bracket';        T: 0; F: FLAG_FORTH2012_CORE),
  (N: '['']';               E: 'bracket_tick';        T: 0; F: FLAG_FORTH2012_CORE),
  (N: '[CHAR]';             E: 'bracket_char';        T: 0; F: FLAG_FORTH2012_CORE),
  (N: ']';                  E: 'right_bracket';       T: 0; F: FLAG_FORTH2012_CORE),
  (N: '`PubForth 0.3.0`: Core word set';    E: nil; T: 0; F: FLAG_PUBFORTH_MILESTONE),
  (N: '.(';                 E: 'dot_paren';           T: 0; F: FLAG_FORTH2012_CORE_EXT),
  (N: '.R';                 E: 'dot_r';               T: 0; F: FLAG_FORTH2012_CORE_EXT),
  (N: '2>R';                E: 'two_to_r';            T: 0; F: FLAG_FORTH2012_CORE_EXT),
  (N: '2R>';                E: 'two_r_from';          T: 0; F: FLAG_FORTH2012_CORE_EXT),
  (N: '2R@';                E: 'two_r_fetch';         T: 0; F: FLAG_FORTH2012_CORE_EXT),
  (N: ':NONAME';            E: 'colon_no_name';       T: 0; F: FLAG_FORTH2012_CORE_EXT),
  (N: '?DO';                E: 'question_do';         T: 0; F: FLAG_FORTH2012_CORE_EXT),
  (N: 'ACTION-OF';          E: 'action_of';           T: 0; F: FLAG_FORTH2012_CORE_EXT),
  (N: 'AGAIN';              E: nil;                   T: 0; F: FLAG_FORTH2012_CORE_EXT),
  (N: 'BUFFER:';            E: nil;                   T: 0; F: FLAG_FORTH2012_CORE_EXT),
  (N: 'C"';                 E: 'c_quote';             T: 0; F: FLAG_FORTH2012_CORE_EXT),
  (N: 'CASE';               E: nil;                   T: 0; F: FLAG_FORTH2012_CORE_EXT),
  (N: 'COMPILE,';           E: nil;                   T: 0; F: FLAG_FORTH2012_CORE_EXT),
  (N: 'DEFER';              E: nil;                   T: 0; F: FLAG_FORTH2012_CORE_EXT),
  (N: 'DEFER!';             E: 'defer_store';         T: 0; F: FLAG_FORTH2012_CORE_EXT),
  (N: 'DEFER@';             E: 'defer_fetch';         T: 0; F: FLAG_FORTH2012_CORE_EXT),
  (N: 'ENDCASE';            E: nil;                   T: 0; F: FLAG_FORTH2012_CORE_EXT),
  (N: 'ENDOF';              E: nil;                   T: 0; F: FLAG_FORTH2012_CORE_EXT),
  (N: 'ERASE';              E: nil;                   T: 0; F: FLAG_FORTH2012_CORE_EXT),
  (N: 'HOLDS';              E: nil;                   T: 0; F: FLAG_FORTH2012_CORE_EXT),
  (N: 'IS';                 E: nil;                   T: 0; F: FLAG_FORTH2012_CORE_EXT),
  (N: 'MARKER';             E: nil;                   T: 0; F: FLAG_FORTH2012_CORE_EXT),
  (N: 'OF';                 E: nil;                   T: 0; F: FLAG_FORTH2012_CORE_EXT),
  (N: 'PAD';                E: nil;                   T: 0; F: FLAG_FORTH2012_CORE_EXT),
  (N: 'PARSE';              E: nil;                   T: 0; F: FLAG_FORTH2012_CORE_EXT),
  (N: 'PARSE-NAME';         E: nil;                   T: 0; F: FLAG_FORTH2012_CORE_EXT),
  (N: 'PICK';               E: nil;                   T: 0; F: FLAG_FORTH2012_CORE_EXT),
  (N: 'REFILL';             E: nil;                   T: 0; F: FLAG_FORTH2012_CORE_EXT),
  (N: 'RESTORE-INPUT';      E: nil;                   T: 0; F: FLAG_FORTH2012_CORE_EXT),
  (N: 'ROLL';               E: nil;                   T: 0; F: FLAG_FORTH2012_CORE_EXT),
  (N: 'S\"';                E: 's_backslash_quote';   T: 0; F: FLAG_FORTH2012_CORE_EXT),
  (N: 'SAVE-INPUT';         E: 'save_input';          T: 0; F: FLAG_FORTH2012_CORE_EXT),
  (N: 'SOURCE-ID';          E: 'source_id';           T: 0; F: FLAG_FORTH2012_CORE_EXT),
  (N: 'TO';                 E: nil;                   T: 0; F: FLAG_FORTH2012_CORE_EXT),
  (N: 'TUCK';               E: nil;                   T: 0; F: FLAG_FORTH2012_CORE_EXT),
  (N: 'U.R';                E: 'u_dot_r';             T: 0; F: FLAG_FORTH2012_CORE_EXT),
  (N: 'UNUSED';             E: nil;                   T: 0; F: FLAG_FORTH2012_CORE_EXT),
  (N: 'VALUE';              E: nil;                   T: 0; F: FLAG_FORTH2012_CORE_EXT),
  (N: 'WITHIN';             E: nil;                   T: 0; F: FLAG_FORTH2012_CORE_EXT),
  (N: '[COMPILE]';          E: 'bracket_compile';     T: 0; F: FLAG_FORTH2012_CORE_EXT or FLAG_OBSOLESCENT),
  (N: '.S';                 E: 'dot_s';               T: 0; F: FLAG_FORTH2012_TOOLS),
  (N: '?';                  E: 'question';            T: 0; F: FLAG_FORTH2012_TOOLS),
  (N: 'DUMP';               E: nil;                   T: 0; F: FLAG_FORTH2012_TOOLS),
  (N: 'SEE';                E: nil;                   T: 0; F: FLAG_FORTH2012_TOOLS),
  (N: 'WORDS';              E: nil;                   T: 0; F: FLAG_FORTH2012_TOOLS),
  (N: 'ALLOCATE';           E: nil;                   T: 0; F: FLAG_FORTH2012_MEMORY),
  (N: 'FREE';               E: nil;                   T: 0; F: FLAG_FORTH2012_MEMORY),
  (N: 'RESIZE';             E: nil;                   T: 0; F: FLAG_FORTH2012_MEMORY),
  (N: '-TRAILING';          E: 'dash_trailing';       T: 0; F: FLAG_FORTH2012_STRING),
  (N: '/STRING';            E: 'slash_string';        T: 0; F: FLAG_FORTH2012_STRING),
  (N: 'BLANK';              E: nil;                   T: 0; F: FLAG_FORTH2012_STRING),
  (N: 'CMOVE';              E: nil;                   T: 0; F: FLAG_FORTH2012_STRING),
  (N: 'CMOVE>';             E: nil;                   T: 0; F: FLAG_FORTH2012_STRING),
  (N: 'COMPARE';            E: nil;                   T: 0; F: FLAG_FORTH2012_STRING),
  (N: 'SEARCH';             E: nil;                   T: 0; F: FLAG_FORTH2012_STRING),
  (N: 'SLITERAL';           E: nil;                   T: 0; F: FLAG_FORTH2012_STRING),
  (N: 'REPLACES';           E: nil;                   T: 0; F: FLAG_FORTH2012_STRING_EXT),
  (N: 'SUBSTITUTE';         E: nil;                   T: 0; F: FLAG_FORTH2012_STRING_EXT),
  (N: 'UNESCAPE';           E: nil;                   T: 0; F: FLAG_FORTH2012_STRING_EXT),
  (N: 'BIN';                E: nil;                   T: 0; F: FLAG_FORTH2012_FILE),
  (N: 'CLOSE-FILE';         E: 'close_file';          T: 0; F: FLAG_FORTH2012_FILE),
  (N: 'CREATE-FILE';        E: 'create_file';         T: 0; F: FLAG_FORTH2012_FILE),
  (N: 'DELETE-FILE';        E: 'delete_file';         T: 0; F: FLAG_FORTH2012_FILE),
  (N: 'FILE-POSITION';      E: 'file_position';       T: 0; F: FLAG_FORTH2012_FILE),
  (N: 'FILE-SIZE';          E: 'file_size';           T: 0; F: FLAG_FORTH2012_FILE),
  (N: 'INCLUDE-FILE';       E: 'include_file';        T: 0; F: FLAG_FORTH2012_FILE),
  (N: 'INCLUDED';           E: nil;                   T: 0; F: FLAG_FORTH2012_FILE),
  (N: 'OPEN-FILE';          E: 'open_file';           T: 0; F: FLAG_FORTH2012_FILE),
  (N: 'R/O';                E: 'r_o';                 T: 0; F: FLAG_FORTH2012_FILE),
  (N: 'R/W';                E: 'r_w';                 T: 0; F: FLAG_FORTH2012_FILE),
  (N: 'READ-FILE';          E: 'read_file';           T: 0; F: FLAG_FORTH2012_FILE),
  (N: 'READ-LINE';          E: 'read_line';           T: 0; F: FLAG_FORTH2012_FILE),
  (N: 'REPOSITION-FILE';    E: 'reposition_file';     T: 0; F: FLAG_FORTH2012_FILE),
  (N: 'RESIZE-FILE';        E: 'resize_file';         T: 0; F: FLAG_FORTH2012_FILE),
  (N: 'S"';                 E: 's_quote';             T: 0; F: FLAG_FORTH2012_FILE),
  (N: 'SOURCE-ID';          E: 'source_id';           T: 0; F: FLAG_FORTH2012_FILE),
  (N: 'W/O';                E: 'w_o';                 T: 0; F: FLAG_FORTH2012_FILE),
  (N: 'WRITE-FILE';         E: 'write_file';          T: 0; F: FLAG_FORTH2012_FILE),
  (N: 'WRITE-LINE';         E: 'write_line';          T: 0; F: FLAG_FORTH2012_FILE),
  (N: 'FILE-STATUS';        E: 'file_status';         T: 0; F: FLAG_FORTH2012_FILE_EXT),
  (N: 'FLUSH-FILE';         E: 'flush_file';          T: 0; F: FLAG_FORTH2012_FILE_EXT),
  (N: 'INCLUDE';            E: nil;                   T: 0; F: FLAG_FORTH2012_FILE_EXT),
  (N: 'REFILL';             E: nil;                   T: 0; F: FLAG_FORTH2012_FILE_EXT),
  (N: 'RENAME-FILE';        E: 'rename_file';         T: 0; F: FLAG_FORTH2012_FILE_EXT),
  (N: 'REQUIRE';            E: nil;                   T: 0; F: FLAG_FORTH2012_FILE_EXT),
  (N: 'REQUIRED';           E: nil;                   T: 0; F: FLAG_FORTH2012_FILE_EXT),
  (N: 'S\"';                E: 's_backslash_quote';   T: 0; F: FLAG_FORTH2012_FILE_EXT),
  (N: 'CATCH';              E: nil;                   T: 0; F: FLAG_FORTH2012_EXCEPTION),
  (N: 'THROW';              E: nil;                   T: 0; F: FLAG_FORTH2012_EXCEPTION),
  (N: 'ABORT';              E: nil;                   T: 0; F: FLAG_FORTH2012_EXCEPTION_EXT),
  (N: 'ABORT"';             E: 'abort_quote';         T: 0; F: FLAG_FORTH2012_EXCEPTION_EXT),
  (N: '(LOCAL)';            E: 'paren_local_paren';   T: 0; F: FLAG_FORTH2012_LOCALS),
  (N: 'LOCALS|';            E: 'locals_bar';          T: 0; F: FLAG_FORTH2012_LOCALS_EXT or FLAG_OBSOLESCENT),
  (N: '{:';                 E: 'brace_colon';         T: 0; F: FLAG_FORTH2012_LOCALS_EXT),
  (N: 'DEFINITIONS';        E: nil;                   T: 0; F: FLAG_FORTH2012_SEARCH),
  (N: 'FIND';               E: nil;                   T: 0; F: FLAG_FORTH2012_SEARCH),
  (N: 'FORTH-WORDLIST';     E: 'forth_wordlist';      T: 0; F: FLAG_FORTH2012_SEARCH),
  (N: 'GET-CURRENT';        E: 'get_current';         T: 0; F: FLAG_FORTH2012_SEARCH),
  (N: 'GET-ORDER';          E: 'get_order';           T: 0; F: FLAG_FORTH2012_SEARCH),
  (N: 'SEARCH-WORDLIST';    E: 'search_wordlist';     T: 0; F: FLAG_FORTH2012_SEARCH),
  (N: 'SET-CURRENT';        E: 'set_current';         T: 0; F: FLAG_FORTH2012_SEARCH),
  (N: 'SET-ORDER';          E: 'set_order';           T: 0; F: FLAG_FORTH2012_SEARCH),
  (N: 'WORDLIST';           E: nil;                   T: 0; F: FLAG_FORTH2012_SEARCH),
  (N: 'ALSO';               E: nil;                   T: 0; F: FLAG_FORTH2012_SEARCH_EXT),
  (N: 'FORTH';              E: nil;                   T: 0; F: FLAG_FORTH2012_SEARCH_EXT),
  (N: 'ONLY';               E: nil;                   T: 0; F: FLAG_FORTH2012_SEARCH_EXT),
  (N: 'ORDER';              E: nil;                   T: 0; F: FLAG_FORTH2012_SEARCH_EXT),
  (N: 'PREVIOUS';           E: nil;                   T: 0; F: FLAG_FORTH2012_SEARCH_EXT),
  (N: '>FLOAT';             E: 'to_float';            T: 0; F: FLAG_FORTH2012_FLOAT),
  (N: 'D>F';                E: 'd_to_f';              T: 0; F: FLAG_FORTH2012_FLOAT),
  (N: 'F!';                 E: 'f_store';             T: 0; F: FLAG_FORTH2012_FLOAT),
  (N: 'F*';                 E: 'f_star';              T: 0; F: FLAG_FORTH2012_FLOAT),
  (N: 'F+';                 E: 'f_plus';              T: 0; F: FLAG_FORTH2012_FLOAT),
  (N: 'F-';                 E: 'f_minus';             T: 0; F: FLAG_FORTH2012_FLOAT),
  (N: 'F/';                 E: 'f_slash';             T: 0; F: FLAG_FORTH2012_FLOAT),
  (N: 'F0<';                E: 'f_zero_less_than';    T: 0; F: FLAG_FORTH2012_FLOAT),
  (N: 'F0=';                E: 'f_zero_equals';       T: 0; F: FLAG_FORTH2012_FLOAT),
  (N: 'F<';                 E: 'f_less_than';         T: 0; F: FLAG_FORTH2012_FLOAT),
  (N: 'F>D';                E: 'f_to_d';              T: 0; F: FLAG_FORTH2012_FLOAT),
  (N: 'F@';                 E: 'f_fetch';             T: 0; F: FLAG_FORTH2012_FLOAT),
  (N: 'FALIGN';             E: nil;                   T: 0; F: FLAG_FORTH2012_FLOAT),
  (N: 'FALIGNED';           E: nil;                   T: 0; F: FLAG_FORTH2012_FLOAT),
  (N: 'FCONSTANT';          E: nil;                   T: 0; F: FLAG_FORTH2012_FLOAT),
  (N: 'FDEPTH';             E: nil;                   T: 0; F: FLAG_FORTH2012_FLOAT),
  (N: 'FDROP';              E: nil;                   T: 0; F: FLAG_FORTH2012_FLOAT),
  (N: 'FDUP';               E: nil;                   T: 0; F: FLAG_FORTH2012_FLOAT),
  (N: 'FLITERAL';           E: nil;                   T: 0; F: FLAG_FORTH2012_FLOAT),
  (N: 'FLOAT+';             E: 'float_plus';          T: 0; F: FLAG_FORTH2012_FLOAT),
  (N: 'FLOATS';             E: nil;                   T: 0; F: FLAG_FORTH2012_FLOAT),
  (N: 'FLOOR';              E: nil;                   T: 0; F: FLAG_FORTH2012_FLOAT),
  (N: 'FMAX';               E: nil;                   T: 0; F: FLAG_FORTH2012_FLOAT),
  (N: 'FMIN';               E: nil;                   T: 0; F: FLAG_FORTH2012_FLOAT),
  (N: 'FNEGATE';            E: nil;                   T: 0; F: FLAG_FORTH2012_FLOAT),
  (N: 'FOVER';              E: nil;                   T: 0; F: FLAG_FORTH2012_FLOAT),
  (N: 'FROT';               E: nil;                   T: 0; F: FLAG_FORTH2012_FLOAT),
  (N: 'FROUND';             E: nil;                   T: 0; F: FLAG_FORTH2012_FLOAT),
  (N: 'FSWAP';              E: nil;                   T: 0; F: FLAG_FORTH2012_FLOAT),
  (N: 'FVARIABLE';          E: nil;                   T: 0; F: FLAG_FORTH2012_FLOAT),
  (N: 'REPRESENT';          E: nil;                   T: 0; F: FLAG_FORTH2012_FLOAT),
  (N: 'DF!';                E: 'd_f_store';           T: 0; F: FLAG_FORTH2012_FLOAT_EXT),
  (N: 'DF@';                E: 'd_f_fetch';           T: 0; F: FLAG_FORTH2012_FLOAT_EXT),
  (N: 'DFALIGN';            E: nil;                   T: 0; F: FLAG_FORTH2012_FLOAT_EXT),
  (N: 'DFALIGNED';          E: nil;                   T: 0; F: FLAG_FORTH2012_FLOAT_EXT),
  (N: 'DFFIELD:';           E: 'd_f_field_colon';     T: 0; F: FLAG_FORTH2012_FLOAT_EXT),
  (N: 'DFLOAT+';            E: 'd_float_plus';        T: 0; F: FLAG_FORTH2012_FLOAT_EXT),
  (N: 'DFLOATS';            E: 'd_floats';            T: 0; F: FLAG_FORTH2012_FLOAT_EXT),
  (N: 'F**';                E: 'f_star_star';         T: 0; F: FLAG_FORTH2012_FLOAT_EXT),
  (N: 'F.';                 E: 'f_dot';               T: 0; F: FLAG_FORTH2012_FLOAT_EXT),
  (N: 'F>S';                E: 'f_to_s';              T: 0; F: FLAG_FORTH2012_FLOAT_EXT),
  (N: 'FABS';               E: 'f_abs';               T: 0; F: FLAG_FORTH2012_FLOAT_EXT),
  (N: 'FACOS';              E: 'f_a_cos';             T: 0; F: FLAG_FORTH2012_FLOAT_EXT),
  (N: 'FACOSH';             E: 'f_a_cosh';            T: 0; F: FLAG_FORTH2012_FLOAT_EXT),
  (N: 'FALOG';              E: 'f_a_log';             T: 0; F: FLAG_FORTH2012_FLOAT_EXT),
  (N: 'FASIN';              E: 'f_a_sin';             T: 0; F: FLAG_FORTH2012_FLOAT_EXT),
  (N: 'FASINH';             E: 'f_a_cinch';           T: 0; F: FLAG_FORTH2012_FLOAT_EXT),
  (N: 'FATAN';              E: 'f_a_tan';             T: 0; F: FLAG_FORTH2012_FLOAT_EXT),
  (N: 'FATAN2';             E: 'f_a_tan_two';         T: 0; F: FLAG_FORTH2012_FLOAT_EXT),
  (N: 'FATANH';             E: 'f_a_tan_h';           T: 0; F: FLAG_FORTH2012_FLOAT_EXT),
  (N: 'FCOS';               E: 'f_cos';               T: 0; F: FLAG_FORTH2012_FLOAT_EXT),
  (N: 'FCOSH';              E: 'f_cosh';              T: 0; F: FLAG_FORTH2012_FLOAT_EXT),
  (N: 'FE.';                E: 'f_e_dot';             T: 0; F: FLAG_FORTH2012_FLOAT_EXT),
  (N: 'FEXP';               E: nil;                   T: 0; F: FLAG_FORTH2012_FLOAT_EXT),
  (N: 'FEXPM1';             E: nil;                   T: 0; F: FLAG_FORTH2012_FLOAT_EXT),
  (N: 'FFIELD:';            E: nil;                   T: 0; F: FLAG_FORTH2012_FLOAT_EXT),
  (N: 'FLN';                E: nil;                   T: 0; F: FLAG_FORTH2012_FLOAT_EXT),
  (N: 'FLNP1';              E: nil;                   T: 0; F: FLAG_FORTH2012_FLOAT_EXT),
  (N: 'FLOG';               E: nil;                   T: 0; F: FLAG_FORTH2012_FLOAT_EXT),
  (N: 'FS.';                E: 'f_s_dot';             T: 0; F: FLAG_FORTH2012_FLOAT_EXT),
  (N: 'FSIN';               E: nil;                   T: 0; F: FLAG_FORTH2012_FLOAT_EXT),
  (N: 'FSINCOS';            E: nil;                   T: 0; F: FLAG_FORTH2012_FLOAT_EXT),
  (N: 'FSINH';              E: nil;                   T: 0; F: FLAG_FORTH2012_FLOAT_EXT),
  (N: 'FSQRT';              E: nil;                   T: 0; F: FLAG_FORTH2012_FLOAT_EXT),
  (N: 'FTAN';               E: nil;                   T: 0; F: FLAG_FORTH2012_FLOAT_EXT),
  (N: 'FTANH';              E: nil;                   T: 0; F: FLAG_FORTH2012_FLOAT_EXT),
  (N: 'FTRUNC';             E: nil;                   T: 0; F: FLAG_FORTH2012_FLOAT_EXT),
  (N: 'FVALUE';             E: nil;                   T: 0; F: FLAG_FORTH2012_FLOAT_EXT),
  (N: 'F~';                 E: 'f_proximate';         T: 0; F: FLAG_FORTH2012_FLOAT_EXT),
  (N: 'PRECISION';          E: nil;                   T: 0; F: FLAG_FORTH2012_FLOAT_EXT),
  (N: 'S>F';                E: 's_to_f';              T: 0; F: FLAG_FORTH2012_FLOAT_EXT),
  (N: 'SET-PRECISION';      E: 'set_precision';       T: 0; F: FLAG_FORTH2012_FLOAT_EXT),
  (N: 'SF!';                E: 's_f_store';           T: 0; F: FLAG_FORTH2012_FLOAT_EXT),
  (N: 'SF@';                E: 's_f_fetch';           T: 0; F: FLAG_FORTH2012_FLOAT_EXT),
  (N: 'SFALIGN';            E: 's_f_align';           T: 0; F: FLAG_FORTH2012_FLOAT_EXT),
  (N: 'SFALIGNED';          E: 's_f_aligned';         T: 0; F: FLAG_FORTH2012_FLOAT_EXT),
  (N: 'SFFIELD:';           E: 's_f_field_colon';     T: 0; F: FLAG_FORTH2012_FLOAT_EXT),
  (N: 'SFLOAT+';            E: 's_float_plus';        T: 0; F: FLAG_FORTH2012_FLOAT_EXT),
  (N: 'SFLOATS';            E: 's_floats';            T: 0; F: FLAG_FORTH2012_FLOAT_EXT),
  (N: 'X-SIZE';             E: 'x_size';              T: 0; F: FLAG_FORTH2012_XCHAR),
  (N: 'XC!+';               E: 'x_c_store_plus';      T: 0; F: FLAG_FORTH2012_XCHAR),
  (N: 'XC!+?';              E: 'x_c_store_plus_query';T: 0; F: FLAG_FORTH2012_XCHAR),
  (N: 'XC,';                E: 'x_c_comma';           T: 0; F: FLAG_FORTH2012_XCHAR),
  (N: 'XC-SIZE';            E: 'x_c_size';            T: 0; F: FLAG_FORTH2012_XCHAR),
  (N: 'XC@+';               E: 'x_c_fetch_plus';      T: 0; F: FLAG_FORTH2012_XCHAR),
  (N: 'XCHAR+';             E: 'x_char_plus';         T: 0; F: FLAG_FORTH2012_XCHAR),
  (N: 'XEMIT';              E: 'x_emit';              T: 0; F: FLAG_FORTH2012_XCHAR),
  (N: 'XKEY';               E: 'x_key';               T: 0; F: FLAG_FORTH2012_XCHAR),
  (N: 'XKEY?';              E: 'x_key_query';         T: 0; F: FLAG_FORTH2012_XCHAR),
  (N: '+X/STRING';          E: 'plus_x_string';       T: 0; F: FLAG_FORTH2012_XCHAR_EXT),
  (N: '-TRAILING-GARBAGE';  E: 'minus_trailing_garbage'; T: 0; F: FLAG_FORTH2012_XCHAR_EXT),
  (N: 'CHAR';               E: nil;                   T: 0; F: FLAG_FORTH2012_XCHAR_EXT),
  (N: 'EKEY>XCHAR';         E: 'e_key_to_x_char';     T: 0; F: FLAG_FORTH2012_XCHAR_EXT),
  (N: 'PARSE';              E: nil;                   T: 0; F: FLAG_FORTH2012_XCHAR_EXT),
  (N: 'X-WIDTH';            E: 'x_width';             T: 0; F: FLAG_FORTH2012_XCHAR_EXT),
  (N: 'XC-WIDTH';           E: 'x_c_width';           T: 0; F: FLAG_FORTH2012_XCHAR_EXT),
  (N: 'XCHAR-';             E: 'x_char_minus';        T: 0; F: FLAG_FORTH2012_XCHAR_EXT),
  (N: 'XHOLD';              E: 'x_hold';              T: 0; F: FLAG_FORTH2012_XCHAR_EXT),
  (N: 'X\STRING-';          E: 'x_string_minus';      T: 0; F: FLAG_FORTH2012_XCHAR_EXT),
  (N: '[CHAR]';             E: 'bracket_char';        T: 0; F: FLAG_FORTH2012_XCHAR_EXT),
  (N: ';CODE';              E: 'semicolon_code';      T: 0; F: FLAG_FORTH2012_TOOLS_EXT),
  (N: 'AHEAD';              E: nil;                   T: 0; F: FLAG_FORTH2012_TOOLS_EXT),
  (N: 'ASSEMBLER';          E: nil;                   T: 0; F: FLAG_FORTH2012_TOOLS_EXT),
  (N: 'BYE';                E: nil;                   T: 0; F: FLAG_FORTH2012_TOOLS_EXT),
  (N: 'CODE';               E: nil;                   T: 0; F: FLAG_FORTH2012_TOOLS_EXT),
  (N: 'CS-PICK';            E: 'c_s_pick';            T: 0; F: FLAG_FORTH2012_TOOLS_EXT),
  (N: 'CS-ROLL';            E: 'c_s_roll';            T: 0; F: FLAG_FORTH2012_TOOLS_EXT),
  (N: 'EDITOR';             E: nil;                   T: 0; F: FLAG_FORTH2012_TOOLS_EXT),
  (N: 'FORGET';             E: nil;                   T: 0; F: FLAG_FORTH2012_TOOLS_EXT or FLAG_OBSOLESCENT),
  (N: 'N>R';                E: 'n_to_r';              T: 0; F: FLAG_FORTH2012_TOOLS_EXT),
  (N: 'NAME>COMPILE';       E: 'name_to_compile';     T: 0; F: FLAG_FORTH2012_TOOLS_EXT),
  (N: 'NAME>INTERPRET';     E: 'name_to_interpret';   T: 0; F: FLAG_FORTH2012_TOOLS_EXT),
  (N: 'NAME>STRING';        E: 'name_to_string';      T: 0; F: FLAG_FORTH2012_TOOLS_EXT),
  (N: 'NR>';                E: 'n_r_from';            T: 0; F: FLAG_FORTH2012_TOOLS_EXT),
  (N: 'STATE';              E: nil;                   T: 0; F: FLAG_FORTH2012_TOOLS_EXT),
  (N: 'SYNONYM';            E: nil;                   T: 0; F: FLAG_FORTH2012_TOOLS_EXT),
  (N: 'TRAVERSE-WORDLIST';  E: 'traverse_wordlist';   T: 0; F: FLAG_FORTH2012_TOOLS_EXT),
  (N: '[DEFINED]';          E: 'bracket_defined';     T: 0; F: FLAG_FORTH2012_TOOLS_EXT),
  (N: '[ELSE]';             E: 'bracket_else';        T: 0; F: FLAG_FORTH2012_TOOLS_EXT),
  (N: '[IF]';               E: 'bracket_if';          T: 0; F: FLAG_FORTH2012_TOOLS_EXT),
  (N: '[THEN]';             E: 'bracket_then';        T: 0; F: FLAG_FORTH2012_TOOLS_EXT),
  (N: '[UNDEFINED]';        E: 'bracket_undefined';   T: 0; F: FLAG_FORTH2012_TOOLS_EXT),
  (N: 'BLK';                E: nil;                   T: 0; F: FLAG_FORTH2012_BLOCK),
  (N: 'BLOCK';              E: nil;                   T: 0; F: FLAG_FORTH2012_BLOCK),
  (N: 'BUFFER';             E: nil;                   T: 0; F: FLAG_FORTH2012_BLOCK),
  (N: 'EVALUATE';           E: nil;                   T: 0; F: FLAG_FORTH2012_BLOCK),
  (N: 'FLUSH';              E: nil;                   T: 0; F: FLAG_FORTH2012_BLOCK),
  (N: 'LOAD';               E: nil;                   T: 0; F: FLAG_FORTH2012_BLOCK),
  (N: 'SAVE-BUFFERS';       E: 'save_buffers';        T: 0; F: FLAG_FORTH2012_BLOCK),
  (N: 'UPDATE';             E: nil;                   T: 0; F: FLAG_FORTH2012_BLOCK),
  (N: 'EMPTY-BUFFERS';      E: 'empty_buffers';       T: 0; F: FLAG_FORTH2012_BLOCK_EXT),
  (N: 'LIST';               E: nil;                   T: 0; F: FLAG_FORTH2012_BLOCK_EXT),
  (N: 'REFILL';             E: nil;                   T: 0; F: FLAG_FORTH2012_BLOCK_EXT),
  (N: 'SCR';                E: nil;                   T: 0; F: FLAG_FORTH2012_BLOCK_EXT),
  (N: 'THRU';               E: nil;                   T: 0; F: FLAG_FORTH2012_BLOCK_EXT),
  (N: '\';                  E: 'backslash';           T: 0; F: FLAG_FORTH2012_BLOCK_EXT),
  (N: '2CONSTANT';          E: 'two_constant';        T: 0; F: FLAG_FORTH2012_DOUBLE),
  (N: '2LITERAL';           E: 'two_literal';         T: 0; F: FLAG_FORTH2012_DOUBLE),
  (N: '2VARIABLE';          E: 'two_variable';        T: 0; F: FLAG_FORTH2012_DOUBLE),
  (N: 'D+';                 E: 'd_plus';              T: 0; F: FLAG_FORTH2012_DOUBLE),
  (N: 'D-';                 E: 'd_minus';             T: 0; F: FLAG_FORTH2012_DOUBLE),
  (N: 'D.';                 E: 'd_dot';               T: 0; F: FLAG_FORTH2012_DOUBLE),
  (N: 'D.R';                E: 'd_dot_r';             T: 0; F: FLAG_FORTH2012_DOUBLE),
  (N: 'D0<';                E: 'd_zero_less';         T: 0; F: FLAG_FORTH2012_DOUBLE),
  (N: 'D0=';                E: 'd_zero_equals';       T: 0; F: FLAG_FORTH2012_DOUBLE),
  (N: 'D2*';                E: 'd_two_star';          T: 0; F: FLAG_FORTH2012_DOUBLE),
  (N: 'D2/';                E: 'd_two_slash';         T: 0; F: FLAG_FORTH2012_DOUBLE),
  (N: 'D<';                 E: 'd_less_than';         T: 0; F: FLAG_FORTH2012_DOUBLE),
  (N: 'D=';                 E: 'd_equals';            T: 0; F: FLAG_FORTH2012_DOUBLE),
  (N: 'D>S';                E: 'd_to_s';              T: 0; F: FLAG_FORTH2012_DOUBLE),
  (N: 'DABS';               E: nil;                   T: 0; F: FLAG_FORTH2012_DOUBLE),
  (N: 'DMAX';               E: nil;                   T: 0; F: FLAG_FORTH2012_DOUBLE),
  (N: 'DMIN';               E: nil;                   T: 0; F: FLAG_FORTH2012_DOUBLE),
  (N: 'DNEGATE';            E: nil;                   T: 0; F: FLAG_FORTH2012_DOUBLE),
  (N: 'M*/';                E: 'm_star_slash';        T: 0; F: FLAG_FORTH2012_DOUBLE),
  (N: 'M+';                 E: 'm_plus';              T: 0; F: FLAG_FORTH2012_DOUBLE),
  (N: '2ROT';               E: 'two_rote';            T: 0; F: FLAG_FORTH2012_DOUBLE_EXT),
  (N: '2VALUE';             E: 'two_value';           T: 0; F: FLAG_FORTH2012_DOUBLE_EXT),
  (N: 'DU<';                E: 'd_u_less';            T: 0; F: FLAG_FORTH2012_DOUBLE_EXT),
  (N: 'AT-XY';              E: 'at_x_y';              T: 0; F: FLAG_FORTH2012_FACILITY),
  (N: 'KEY?';               E: 'key_question';        T: 0; F: FLAG_FORTH2012_FACILITY),
  (N: 'PAGE';               E: nil;                   T: 0; F: FLAG_FORTH2012_FACILITY),
  (N: '+FIELD';             E: 'plus_field';          T: 0; F: FLAG_FORTH2012_FACILITY_EXT),
  (N: 'BEGIN-STRUCTURE';    E: 'begin_structure';     T: 0; F: FLAG_FORTH2012_FACILITY_EXT),
  (N: 'CFIELD:';            E: 'c_field_colon';       T: 0; F: FLAG_FORTH2012_FACILITY_EXT),
  (N: 'EKEY';               E: nil;                   T: 0; F: FLAG_FORTH2012_FACILITY_EXT),
  (N: 'EKEY>CHAR';          E: 'e_key_to_char';       T: 0; F: FLAG_FORTH2012_FACILITY_EXT),
  (N: 'EKEY>FKEY';          E: 'e_key_to_f_key';      T: 0; F: FLAG_FORTH2012_FACILITY_EXT),
  (N: 'EKEY?';              E: 'e_key_question';      T: 0; F: FLAG_FORTH2012_FACILITY_EXT),
  (N: 'EMIT?';              E: 'emit_question';       T: 0; F: FLAG_FORTH2012_FACILITY_EXT),
  (N: 'END-STRUCTURE';      E: 'end_structure';       T: 0; F: FLAG_FORTH2012_FACILITY_EXT),
  (N: 'FIELD:';             E: 'field_colon';         T: 0; F: FLAG_FORTH2012_FACILITY_EXT),
  (N: 'K-ALT-MASK';         E: 'k_alt_mask';          T: 0; F: FLAG_FORTH2012_FACILITY_EXT),
  (N: 'K-CTRL-MASK';        E: 'k_ctrl_mask';         T: 0; F: FLAG_FORTH2012_FACILITY_EXT),
  (N: 'K-DELETE';           E: 'k_delete';            T: 0; F: FLAG_FORTH2012_FACILITY_EXT),
  (N: 'K-DOWN';             E: 'k_down';              T: 0; F: FLAG_FORTH2012_FACILITY_EXT),
  (N: 'K-END';              E: 'k_end';               T: 0; F: FLAG_FORTH2012_FACILITY_EXT),
  (N: 'K-F1';               E: 'k_f1';                T: 0; F: FLAG_FORTH2012_FACILITY_EXT),
  (N: 'K-F10';              E: 'k_f10';               T: 0; F: FLAG_FORTH2012_FACILITY_EXT),
  (N: 'K-F11';              E: 'k_f11';               T: 0; F: FLAG_FORTH2012_FACILITY_EXT),
  (N: 'K-F12';              E: 'k_f12';               T: 0; F: FLAG_FORTH2012_FACILITY_EXT),
  (N: 'K-F2';               E: 'k_f2';                T: 0; F: FLAG_FORTH2012_FACILITY_EXT),
  (N: 'K-F3';               E: 'k_f3';                T: 0; F: FLAG_FORTH2012_FACILITY_EXT),
  (N: 'K-F4';               E: 'k_f4';                T: 0; F: FLAG_FORTH2012_FACILITY_EXT),
  (N: 'K-F5';               E: 'k_f5';                T: 0; F: FLAG_FORTH2012_FACILITY_EXT),
  (N: 'K-F6';               E: 'k_f6';                T: 0; F: FLAG_FORTH2012_FACILITY_EXT),
  (N: 'K-F7';               E: 'k_f7';                T: 0; F: FLAG_FORTH2012_FACILITY_EXT),
  (N: 'K-F8';               E: 'k_f8';                T: 0; F: FLAG_FORTH2012_FACILITY_EXT),
  (N: 'K-F9';               E: 'k_f9';                T: 0; F: FLAG_FORTH2012_FACILITY_EXT),
  (N: 'K-HOME';             E: 'k_home';              T: 0; F: FLAG_FORTH2012_FACILITY_EXT),
  (N: 'K-INSERT';           E: 'k_insert';            T: 0; F: FLAG_FORTH2012_FACILITY_EXT),
  (N: 'K-LEFT';             E: 'k_left';              T: 0; F: FLAG_FORTH2012_FACILITY_EXT),
  (N: 'K-NEXT';             E: 'k_next';              T: 0; F: FLAG_FORTH2012_FACILITY_EXT),
  (N: 'K-PRIOR';            E: 'k_prior';             T: 0; F: FLAG_FORTH2012_FACILITY_EXT),
  (N: 'K-RIGHT';            E: 'k_right';             T: 0; F: FLAG_FORTH2012_FACILITY_EXT),
  (N: 'K-SHIFT-MASK';       E: 'k_shift_mask';        T: 0; F: FLAG_FORTH2012_FACILITY_EXT),
  (N: 'K-UP';               E: 'k_up';                T: 0; F: FLAG_FORTH2012_FACILITY_EXT),
  (N: 'MS';                 E: nil;                   T: 0; F: FLAG_FORTH2012_FACILITY_EXT),
  (N: 'TIME&DATE';          E: 'time_and_date';       T: 0; F: FLAG_FORTH2012_FACILITY_EXT),
  (N: '`PubForth 0.TBA.0`: Core Extensions word set';                E: nil; T: 0; F: FLAG_PUBFORTH_MILESTONE),
  (N: '`PubForth 0.TBA.0`: Programming-Tools word set';              E: nil; T: 0; F: FLAG_PUBFORTH_MILESTONE),
  (N: '`PubForth 0.TBA.0`: Programming-Tools Extensions word set';   E: nil; T: 0; F: FLAG_PUBFORTH_MILESTONE),
  (N: '`PubForth 0.TBA.0`: String word set';                         E: nil; T: 0; F: FLAG_PUBFORTH_MILESTONE),
  (N: '`PubForth 0.TBA.0`: String Extensions word set';              E: nil; T: 0; F: FLAG_PUBFORTH_MILESTONE),
  (N: '`PubForth 0.TBA.0`: File Access word set';                    E: nil; T: 0; F: FLAG_PUBFORTH_MILESTONE),
  (N: '`PubForth 0.TBA.0`: File Access Extensions word set';         E: nil; T: 0; F: FLAG_PUBFORTH_MILESTONE),
  (N: '`PubForth 0.TBA.0`: Extended-Character word set';             E: nil; T: 0; F: FLAG_PUBFORTH_MILESTONE),
  (N: '`PubForth 0.TBA.0`: Extended-Character Extensions word set';  E: nil; T: 0; F: FLAG_PUBFORTH_MILESTONE),
  (N: '`PubForth 0.TBA.0`: Locals word set';                         E: nil; T: 0; F: FLAG_PUBFORTH_MILESTONE),
  (N: '`PubForth 0.TBA.0`: Locals Extensions word set';              E: nil; T: 0; F: FLAG_PUBFORTH_MILESTONE),
  (N: '`PubForth 0.TBA.0`: Block word set';                          E: nil; T: 0; F: FLAG_PUBFORTH_MILESTONE),
  (N: '`PubForth 0.TBA.0`: Block Extensions word set';               E: nil; T: 0; F: FLAG_PUBFORTH_MILESTONE),
  (N: '`PubForth 0.TBA.0`: Double-Number word set';                  E: nil; T: 0; F: FLAG_PUBFORTH_MILESTONE),
  (N: '`PubForth 0.TBA.0`: Double-Number Extensions word set';       E: nil; T: 0; F: FLAG_PUBFORTH_MILESTONE),
  (N: '`PubForth 0.TBA.0`: Exception word set';                      E: nil; T: 0; F: FLAG_PUBFORTH_MILESTONE),
  (N: '`PubForth 0.TBA.0`: Exception Extensions word set';           E: nil; T: 0; F: FLAG_PUBFORTH_MILESTONE),
  (N: '`PubForth 0.TBA.0`: Facility word set';                       E: nil; T: 0; F: FLAG_PUBFORTH_MILESTONE),
  (N: '`PubForth 0.TBA.0`: Facility Extensions word set';            E: nil; T: 0; F: FLAG_PUBFORTH_MILESTONE),
  (N: '`PubForth 0.TBA.0`: Floating-Point word set';                 E: nil; T: 0; F: FLAG_PUBFORTH_MILESTONE),
  (N: '`PubForth 0.TBA.0`: Floating-Point Extensions word set';      E: nil; T: 0; F: FLAG_PUBFORTH_MILESTONE),
  (N: '`PubForth 0.TBA.0`: Memory-Allocation word set';              E: nil; T: 0; F: FLAG_PUBFORTH_MILESTONE),
  (N: '`PubForth 0.TBA.0`: Search-Order word set';                   E: nil; T: 0; F: FLAG_PUBFORTH_MILESTONE),
  (N: '`PubForth 0.TBA.0`: Search-Order Extensions word set';        E: nil; T: 0; F: FLAG_PUBFORTH_MILESTONE),
  (N: '`PubForth 1.0.0`';  E: nil; T: 0; F: FLAG_PUBFORTH_MILESTONE)

);

var
  WordsInfoReady: Boolean = False;
procedure RequireWordsInfo;
var
  PrevT: Int32;
  I: Int32;
begin
  if WordsInfoReady then
    Exit;

  PrevT := 0;
  for I := 0 to High(STATIC_WORDS_ARRAY) do begin
    //if STATIC_WORDS_ARRAY[I].E = nil then
    //  STATIC_WORDS_ARRAY[I].E := STATIC_WORDS_ARRAY[I].N;

    if (I > 0) and (STATIC_WORDS_ARRAY[I].T = 0) then begin
      //if (STATIC_WORDS_ARRAY[I].F and FLAG_PUBFORTH_MILESTONE) = 0 then begin
      if Pos('PubForth', STATIC_WORDS_ARRAY[I].N) = 0 then begin
        Inc(PrevT, 60*60*24);
        STATIC_WORDS_ARRAY[I].T := PrevT;
      end;
    end else begin
      PrevT := STATIC_WORDS_ARRAY[I].T;
      STATIC_WORDS_ARRAY[I].F := STATIC_WORDS_ARRAY[I].F or FLAG_IMPLEMENTED;
    end;
  end;

  WordsInfoReady := True;
end;

function GetProgress: Int32;
var
  I: Int32;
  Implemented, All: Int32;
begin
  RequireWordsInfo;
  Implemented := 0;
  All := 0;
  for I := 0 to High(STATIC_WORDS_ARRAY) do begin
    if (STATIC_WORDS_ARRAY[I].F and FLAG_FORTH2012) <> 0 then begin
      Inc(All);
      if (STATIC_WORDS_ARRAY[I].F and FLAG_IMPLEMENTED) <> 0 then begin
        Inc(Implemented);
      end;
    end;
  end;
  if All <= 0 then
    All := 1;
  Exit(Round(Implemented / All));
end;

function IntToStr(N: Int32): AnsiString;
begin
  Str(N, Result);
end;

function IntToStr0(N: Int32; Digits: Int32): AnsiString;
begin
  Str(N, Result);
  while Length(Result) < Digits do
    Result := '0' + Result;
end;

function TimestampToDate(T: UInt32): AnsiString;
var
  Y, M, D: TDateInteger;
begin
  if T = 0 then
    Exit('202?.??.??');
  civil_from_days(T div (60 * 60 * 24), Y, M, D);
  Exit(IntToStr0(Y, 4) + '.' + IntToStr0(M, 2) + '.' + IntToStr0(D, 2));
end;

procedure PrintDevelopmentPlan;
var
  I: Int32;
begin
  RequireWordsInfo;
  for I := 0 to High(STATIC_WORDS_ARRAY) do begin
    Writeln(TimestampToDate(STATIC_WORDS_ARRAY[I].T), ' ', STATIC_WORDS_ARRAY[I].N, '');
  end;
end;

function EscapeTicks(const S: AnsiString): AnsiString;
var
  I: Int32;
begin
  Result := '';
  for I := 1 to Length(S) do begin
    if S[I] = '`' then begin
      Result := Result + '\`';
    end else
      Result := Result + S[I];
  end;
end;

function CanonizeWord(const W: AnsiString): AnsiString;
var
  I: Int32;
begin
  Result := '';
  for I := 1 to Length(W) do begin
    if W[I] = '_' then begin
      Result := Result + '-';
    end else
      Result := Result + W[I];
  end;
end;

function PatchReadmeFile(const FileName: AnsiString): Boolean;
label
  LFailed;
var
  T, O: TextFile;
  Line: AnsiString;
  TmpFileName: AnsiString;
  I: Int32;
  Name, EscapedName: AnsiString;
  CheckBox: AnsiString;
  Cross: AnsiString;

  function NextLine: Boolean;
  begin
    {$PUSH} {$I-} Readln(T, Line); {$POP}
    Exit(IOResult = 0);
  end;

  function WriteLine(const S: AnsiString): Boolean;
  begin
    {$PUSH} {$I-} Writeln(O, S); {$POP}
    Exit(IOResult = 0);
  end;

  function BypassLine: Boolean;
  begin
    Exit(WriteLine(Line));
  end;

begin
  Assign(T, FileName);
  {$PUSH} {$I-} Reset(T); {$POP}
  if IOResult <> 0 then
    Exit(False); // TODO better error message reporting

  TmpFileName := FileName + '.new';
  Assign(O, TmpFileName);
  {$PUSH} {$I-} Rewrite(O); {$POP}
  if IOResult <> 0 then begin
    {$PUSH} {$I-} Close(T); {$POP}
    Exit(False);
  end;

  while not Eof(T) do begin
    Line := '';
    if not NextLine then
      goto LFailed;
    if (Length(Line) > 3) and (Copy(Line, 1, 3) = '- [') then
      break;
    if Pos('Progress: ', Line) = 1 then begin
      if not WriteLine('Progress: ' + IntToStr(GetProgress) + '%') then
        goto LFailed;
    end else begin
      if not BypassLine then
        goto LFailed;
    end;
  end;

  RequireWordsInfo;
  for I := 0 to High(STATIC_WORDS_ARRAY) do begin
    // TODO better date formatting
    // TODO name escaping
    Name := STATIC_WORDS_ARRAY[I].N;
    EscapedName := '';
    if Pos(' ', Name) = 0 then begin
      Name := '`' + EscapeTicks(Name) + '`';
      if STATIC_WORDS_ARRAY[I].E <> nil then begin
        EscapedName := CanonizeWord(STATIC_WORDS_ARRAY[I].E);
        if STATIC_WORDS_ARRAY[I].N = UpCase(EscapedName) then begin
          EscapedName := '';
        end else
          EscapedName := ' "' + EscapedName + '"';
      end;
    end;
    CheckBox := ' ';
    Cross := '';
    if (STATIC_WORDS_ARRAY[I].F and FLAG_IMPLEMENTED) <> 0 then begin
      CheckBox := 'x';
      if (Pos('PubForth', Name) = 0) and (Pos('[', Name) = 0) then
        Cross := '~~';
    end;
    WriteLine('- [' + CheckBox + '] ' + Cross + TimestampToDate(STATIC_WORDS_ARRAY[I].T) + ' ' + Name + EscapedName + Cross);
  end;

  while not Eof(T) do begin
    if not NextLine then
      goto LFailed;
    if (Length(Line) > 3) and (Copy(Line, 1, 3) = '- [') then
      continue;
    if not BypassLine then
      goto LFailed;
  end;

  {$PUSH} {$I-} Close(T); {$POP}
  {$PUSH} {$I-} Close(O); {$POP}

  Assign(T, FileName);
  {$PUSH} {$I-} Erase(T); {$POP}

  Assign(O, TmpFileName);
  {$PUSH} {$I-} Rename(O, FileName); {$POP}
  Result := IOResult = 0;

  Exit;

LFailed:
  {$PUSH} {$I-} Close(T); {$POP}
  {$PUSH} {$I-} Close(O); {$POP}

  Exit(False);
end;

end.
