# Create project targeting Artix-7 (e.g. Basys 3 board)
create_project risc_processor_vivado ./vivado_proj_bitstream -part xc7a35tcpg236-1 -force

# Add all Verilog RTL source files
add_files [glob ./rtl/*.v]

# Add constraint file for Basys 3
add_files ./basys3.xdc

# Set the top-level module
set_property top top_basys3 [current_fileset]

# Synthesize the design
puts "Starting Synthesis..."
launch_runs synth_1 -jobs 4
wait_on_run synth_1

# Run implementation (Placement & Routing)
puts "Starting Implementation..."
launch_runs impl_1 -jobs 4
wait_on_run impl_1

# Generate Bitstream
puts "Generating Bitstream..."
launch_runs impl_1 -to_step write_bitstream -jobs 4
wait_on_run impl_1

puts "======================================================="
puts "Build & Bitstream complete!"
puts "======================================================="
exit
