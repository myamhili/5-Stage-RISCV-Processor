// Testbench for RISC-V Processor

`timescale 1ns/1ps

module tb_risc_processor;

    reg  clk;
    reg  rst;
    
    wire [31:0] pc_out;
    wire [31:0] instruction_out;
    wire [31:0] alu_result_out;
    wire [31:0] mem_read_data_out;

    // Clock generation - 10ns period
    initial begin
        clk = 0;
        forever #5 clk = ~clk;
    end

    // Instantiate the processor
    risc_processor uut (
        .clk                  (clk),
        .rst                  (rst),
        .pc_out               (pc_out),
        .instruction_out      (instruction_out),
        .alu_result_out       (alu_result_out),
        .mem_read_data_out    (mem_read_data_out)
    );

    // Test stimulus
    initial begin
        $display("===== RISC-V Processor Testbench =====");
        $display("Time=%0t: Resetting processor...", $time);
        rst = 1;
        #20;
        rst = 0;
        $display("Time=%0t: Reset complete, starting execution...", $time);
        
        // Run for 200ns (20 clock cycles)
        #200;
        
        $display("\n===== Test Complete =====");
        $display("Final PC: %h", pc_out);
        $display("Final Instruction: %h", instruction_out);
        $display("Final ALU Result: %h", alu_result_out);
        $display("Final Memory Read Data: %h", mem_read_data_out);
        
        $finish;
    end

    // Monitor changes
    initial begin
        $monitor("Time=%0t PC=%h Instr=%h ALU=%h MemRead=%h", 
                 $time, pc_out, instruction_out, alu_result_out, mem_read_data_out);
    end

endmodule