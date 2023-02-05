############
# Makefile
# Author: Christopher Tinker
# Date: 2022/01/19
# 
# 5 stage pipelined CPU makefile
######## ####

SRC_DIR = ./src/rtl
CONSTRAINTS_DIR = ./src/constraints
INCLUDE_DIR = ./src/rtl

LINTER := verilator
LINT_OPTIONS += --lint-only -sv -Wall -I$(INCLUDE_DIR)

SRC_FILES := $(wildcard $(SRC_DIR)/*.sv)
INCLUDE_FILES := $(wildcard $(INCLUDE_DIR)/*.svh)
TOP_MODULE := riscv_core.sv

# Filter out a file we don't want linted / compiled
SRC_FILES := $(filter-out $(SRC_DIR)/bram_dualport.sv $(SRC_DIR)/old_dcdr.sv, $(SRC_FILES))

.PHONY: formal
formal:
	sby test.sby -f -d ./sim/formal/output

.PHONY: lint
lint: 
	$(LINTER) $(LINT_OPTIONS) $(SRC_FILES)

