 

# Read the Verilog files


yosys read_verilog -sv -formal -I../simulation/src -I../src -defer ../src/*.vh ../src/*.v
# Synthesize the design
yosys synth -auto-top 

# Optimize the design
yosys opt

# Generate the RTL netlist
yosys write_verilog -noattr -noexpr synthesized_netlist.v