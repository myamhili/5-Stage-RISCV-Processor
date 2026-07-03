# Clean Vivado GUI simulation setup for the self-checking testbench.
# Run from the repo root:
#   vivado -mode gui -source sim_gui.tcl

create_project risc_processor_sim ./vivado_sim -part xc7a35tcpg236-1 -force

add_files ./rtl/pc.v
add_files ./rtl/instruction_memory.v
add_files ./rtl/control_unit.v
add_files ./rtl/register_file.v
add_files ./rtl/alu.v
add_files ./rtl/data_memory.v
add_files ./rtl/risc_processor.v

add_files -fileset sim_1 ./sim/tb_wave_branch_flush.v

set_property top tb_wave_branch_flush [get_filesets sim_1]
set_property source_mgmt_mode None [current_project]
set_property verilog_define {BRANCH_FLUSH_TEST} [get_filesets sim_1]
update_compile_order -fileset sim_1

set_property -name {xsim.simulate.runtime} -value {0 ns} -objects [get_filesets sim_1]

launch_simulation

proc safe_add_wave {signal_name} {
    if {[catch {add_wave $signal_name} err]} {
        puts "WARN: could not add wave $signal_name: $err"
    }
}

safe_add_wave /tb_wave_branch_flush/clk
safe_add_wave /tb_wave_branch_flush/rst
safe_add_wave /tb_wave_branch_flush/pc_out
safe_add_wave /tb_wave_branch_flush/instruction_out
safe_add_wave /tb_wave_branch_flush/uut/pc_branch
safe_add_wave /tb_wave_branch_flush/uut/load_use_hazard
safe_add_wave /tb_wave_branch_flush/uut/if_id_instruction
safe_add_wave /tb_wave_branch_flush/uut/id_ex_rd
safe_add_wave /tb_wave_branch_flush/uut/id_ex_reg_write
safe_add_wave /tb_wave_branch_flush/uut/id_ex_mem_write
safe_add_wave /tb_wave_branch_flush/uut/id_ex_branch

run 500 ns
zoom_fit
