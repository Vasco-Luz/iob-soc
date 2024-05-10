 

# Read the Verilog files


yosys read_verilog -I../simulation/src -I../src -defer ../src/*.v
# Synthesize the design
yosys synth -top iob_soc

# Optimize the design
yosys opt

# Generate the RTL netlist
yosys write_verilog -noattr -noexpr synthesized_netlist.v