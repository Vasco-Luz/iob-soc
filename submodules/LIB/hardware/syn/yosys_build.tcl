set VSRC $env(VSRC)

# Split the VSRC variable into a list of file paths
set VSRC_files [split $VSRC " "]

# Loop through the list of Verilog files and read them
foreach file $VSRC_files {
    read_verilog $file
}