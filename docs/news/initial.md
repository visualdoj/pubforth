*It is not a documentation, just a news post with some plans and brief explanations.*

# 15 june 2022: PubFoth - announcment

`PubForth` is cross-platform implementation of standard `Forth` language. It should work at least on Windows, Linux, macOS, but all other supported by Free Pascal Compiler platforms with standard OS facilities (terminal, file system etc) and at least 32 bits are already supported or "not-hard-to-be-ported".

As a "standard Forth" I've chosen `Forth 2012 Standard`: https://forth-standard.org/

By default it runs a virtual machine which produces intermediate code. That intermediate code may be `translated` to other language by some implemented backend: Pascal, C, Assembly language etc.

All sources are dedicated to public domain, i.e. they may be used in any way by anybody.

## Build

Requirements: [Free Pascal Compiler](https://www.freepascal.org/), GNU Make.

To build `PubForth` run `make build` in root directory:

```
make build
```

It should produce `bin/pubforth` or `bin/pubforth.exe` executable. It may also build some tools used by build proccess.

Also I am going to release binaries on github.

## Test

To test `PubForth` run `make test` in root directory:

```
make test
```

I use my program `testprograms` for running tests. It should fail if any test failed and pass if all tests passed. If called from terminal, it produces nice-looking colorful output.

Tests and their results are placed inside `test` directory.

## PubForth

Some basic command lines:

```
pubforth --version

        Prints version of the program

pubforth --long-help

        Prints full command line help

pubforth --repl

        Runs program in REPL mode

pubforth prog.fs

        Interprets Forth program from prog.fs
```

## Backends

To produce a source code for backend, backend name and output file should be provided:

```
pubforth prog.fs --backend pascal -o prog.pas
```

`0.0.0` version produces only dummy (or hello world) program.

`pubforth --print-backends-list` prints list of supported backends.
