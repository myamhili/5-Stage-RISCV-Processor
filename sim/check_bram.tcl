# Non-project check: preserves existing GUI projects and their run results.
# Run from any directory: vivado -mode batch -source sim/check_bram.tcl
set root [file join [file dirname [info script]] ..]
set reports [file join $root sim build bram_check]
file mkdir $reports
create_project -in_memory -part xc7a35tcpg236-1
read_verilog [glob [file join $root rtl *.v]]
read_xdc [file join $root constraints.xdc]
synth_design -top risc_processor -part xc7a35tcpg236-1 -mode out_of_context
report_utilization -file [file join $reports utilization_synth.rpt]
set brams [get_cells -hier -filter {REF_NAME =~ RAMB* && NAME =~ *memory_reg*}]
puts "BRAM_CHECK: inferred [llength $brams] block RAM primitives"
if {[llength $brams] == 0} { error "Main RAM did not infer block RAM" }
opt_design
place_design
route_design
report_utilization -file [file join $reports utilization_routed.rpt]
report_timing_summary -file [file join $reports timing_routed.rpt]
report_drc -file [file join $reports drc_routed.rpt]
write_checkpoint -force [file join $reports routed.dcp]
set worst [get_timing_paths -delay_type max -max_paths 1]
if {[llength $worst] == 0} { error "No setup timing paths were found" }
set slack [get_property SLACK $worst]
puts "BRAM_CHECK: routed worst setup slack = $slack ns"
if {$slack < 0} { error "Setup timing failed; inspect timing_routed.rpt" }
set hold_paths [get_timing_paths -delay_type min -max_paths 1]
if {[llength $hold_paths] == 0} { error "No hold timing paths were found" }
set hold_slack [get_property SLACK $hold_paths]
puts "BRAM_CHECK: routed worst hold slack = $hold_slack ns"
if {$hold_slack < 0} { error "Hold timing failed; inspect timing_routed.rpt" }
puts "BRAM_CHECK: PASS (out-of-context; not board/IO validation)"
