### 5 Stage Pipeline RV32I Soft Processor

Additional docs to follow


### Building vivado project

The Vivado project will be built in the build directory. 

To build with scripts/build.tcl, run the following command from the top-level
repository directory:

`vivado -source scripts/build.tcl`

To write the Vivado project, run the following command (assuming that Vivado was
opened in the top-level repository directory):

`write_project_tcl -paths_relative_to . -force ./scripts/build.tcl`

Omit the `-force` tag if this is your first time writing the Vivado project to a
TCL script.


