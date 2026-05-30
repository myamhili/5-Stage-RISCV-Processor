# Create project targeting Artix-7 (e.g. Basys 3 board)
create_project risc_processor_vivado ./vivado_proj -part xc7a35tcpg236-1 -force

# Add all Verilog RTL source files
add_files [glob ./rtl/*.v]

# Add constraint file for timing
add_files ./constraints.xdc

# Set the top-level module
set_property top risc_processor [current_fileset]

# Instruct Vivado not to insert I/O buffers (Out-Of-Context mode)
set_property -name {STEPS.SYNTH_DESIGN.ARGS.MORE OPTIONS} -value {-mode out_of_context} -objects [get_runs synth_1]

# Synthesize the design
puts "Starting Synthesis..."
launch_runs synth_1 -jobs 4
wait_on_run synth_1

# Run implementation (Placement & Routing)
puts "Starting Implementation..."
launch_runs impl_1 -jobs 4
wait_on_run impl_1

# Open the implemented design to run reports
open_run impl_1

# Generate Post-Implementation Timing & Utilization Reports
report_timing_summary -file ./vivado_proj/timing_summary.txt
report_utilization -file ./vivado_proj/utilization_summary.txt

puts "======================================================="
puts "Build complete!"
puts "Check vivado_proj/timing_summary.txt for timing slack."
puts "Check vivado_proj/utilization_summary.txt for resources."
puts "======================================================="
exit