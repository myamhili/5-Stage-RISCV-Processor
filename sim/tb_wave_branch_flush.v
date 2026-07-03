// Waveform-only testbench for Vivado GUI screenshots.
// This testbench intentionally does not call $finish so the wave window stays open.

`timescale 1ns/1ps

module tb_wave_branch_flush;

    reg clk;
    reg rst;

    wire [31:0] pc_out;
    wire [31:0] instruction_out;
    wire [31:0] alu_result_out;
    wire [31:0] mem_read_data_out;
    wire [31:0] led_out;

    initial begin
        clk = 1'b0;
        forever #5 clk = ~clk;
    end

    initial begin
        rst = 1'b1;
        repeat (2) @(posedge clk);
        rst = 1'b0;
    end

    risc_processor uut (
        .clk                  (clk),
        .rst                  (rst),
        .pc_out               (pc_out),
        .instruction_out      (instruction_out),
        .alu_result_out       (alu_result_out),
        .mem_read_data_out    (mem_read_data_out),
        .led_out              (led_out)
    );

endmodule
