# Open the existing Vivado project
open_project ./vivado_proj/risc_processor_vivado.xpr

# Add the testbench to the simulation fileset
add_files -fileset sim_1 -norecurse ./sim/tb_risc_processor.v

# Set the testbench as the top module for simulation
set_property top tb_risc_processor [get_filesets sim_1]
update_compile_order -fileset sim_1

# Launch the behavioral simulation
puts "Launching Vivado Simulator (xsim)..."
launch_simulation

puts "======================================================="
puts "Simulation finished."
puts "======================================================="
exit