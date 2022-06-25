default : usage ;

usage :
	@echo make build
	@echo make test
	@echo make clean
	@echo make test_fpc

.SUFFIXES:

.SECONDARY:

.PHONY : usage build

FPC_FLAGS := -vq -O2 -Oodfa -gl

ifeq ($(OS),Windows_NT)
EXEEXT := .exe
PASS:=(exit 0)
clean :
	rmdir /s /q .build || $(PASS)
	rmdir /s /q bin    || $(PASS)
MKDIRP:=mkdir
else
EXEEXT:=
PASS:=true
MKDIRP:=mkdir -p
clean :
	rm -rf .build || $(PASS)
	rm -rf bin    || $(PASS)
endif

.PHONY : .build
.build :
	$(MKDIRP) .build || $(PASS)

.PHONY : bin
bin :
	$(MKDIRP) bin || $(PASS)

.PHONY : .build/tool
.build/tool : .build
	cd .build && $(MKDIRP) tool || $(PASS)

TOOL_TESTPROGRAMS:=bin/testprograms$(EXEEXT)
$(TOOL_TESTPROGRAMS) : prepare_build .build/tool bin
	cd tool/testprograms && fpc $(FPC_FLAGS) -Sew -FE../../bin -FU../../.build/tool testprograms.pas

build_tools : $(TOOL_TESTPROGRAMS) ;

PUBFORTH:=bin/pubforth$(EXEEXT)
build : prepare_build build_tools .build bin
	cd src && fpc $(FPC_FLAGS) -Sew -FE../bin -FU../.build pubforth.pas

test : $(TOOL_TESTPROGRAMS)
	$(MKDIRP) .test || $(PASS)
	$(TOOL_TESTPROGRAMS) -l tests.list -d .test

test_fpc : $(TOOL_TESTPROGRAMS)
	$(MKDIRP) .test || $(PASS)
	$(TOOL_TESTPROGRAMS) -l tests_fpc.list -d .test


ifneq ($(wildcard ../pubforth_external/Makefile.inc),)
  include ../pubforth_external/Makefile.inc
else
prepare_build : ;
endif
