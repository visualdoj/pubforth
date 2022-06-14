default : usage ;

usage :
	@echo make build
	@echo make test
	@echo make clean

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
MKDIRP:=md
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

TESTPROGRAMS:=bin/testprograms$(EXEEXT)
$(TESTPROGRAMS) : prepare_build .build/tool
	cd tool/testprograms && fpc $(FPC_FLAGS) -Sew -FE../../bin -FU../../.build/tool testprograms.pas

build_tools : $(TESTPROGRAMS) ;

PUBFORTH:=bin/pubforth$(EXEEXT)
build : prepare_build build_tools .build bin
	cd src && fpc $(FPC_FLAGS) -Sew -FE../bin -FU../.build pubforth.pas

test : $(TESTPROGRAMS)
	$(TESTPROGRAMS) -l tests.list -d .build


ifneq ($(wildcard ../pubforth_external/Makefile.inc),)
  include ../pubforth_external/Makefile.inc
else
prepare_build : ;
endif
