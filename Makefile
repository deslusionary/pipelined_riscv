############
# Makefile
# Author: Christopher Tinker
# Date: 2022/01/19
# 
# 5 stage pipelined CPU makefile
######## ####

SHELL=/bin/bash




formal:
	sby test.sby -f -d ./sim/formal/output

.PHONY: formal
