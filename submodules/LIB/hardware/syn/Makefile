# This file becomes the syn makefile when copied to the build
# directory

SHELL:=bash

include ../../config_build.mk


#include the module's headers and sources
VHDR+=$(wildcard ../src/*.vh) $(wildcard ./src/*.vh)
VSRC+=$(wildcard ../src/*.v) $(wildcard ./src/*.v)


INCLUDE+=.
INCLUDE+=../src
INCLUDE+=../common_src

include $(SYNTHETISER)/build.mk
