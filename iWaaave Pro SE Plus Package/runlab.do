# Set target module
if {$argc > 0} {
    set module $1
} else {
    set module DE1_SoC
}

# Create work library
vlib work

# Compile Verilog
#     We can include all SystemVerilog files in the current folder using the
#     following line:
vlog "./*.sv"
#     This uses the asterisk (*) to match all files ending in ".sv" at once.
#     NOTE: If you have incomplete files in the current folder, they will be
#     picked up, and will probably fail to compile. Delete any old/unused
#     files, or include only the specific files you need.

# Call vsim to invoke simulator
#     Make sure the last item on the line is the name of the testbench module
#     you want to execute.
vsim -voptargs="+acc" -t 1ps -lib work ${module}_testbench

# Source the wave do file
#     This should be the file that sets up the signal window for the module you
#     are testing.
do ${module}_wave.do

# Make sure relevant windows are visible
view wave
view structure
view signals

# Run the simulation!
run -all

# vim: ft=tcl
