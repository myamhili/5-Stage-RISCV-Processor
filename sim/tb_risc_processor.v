// Self-checking testbench for the pipelined RISC-V processor.

`timescale 1ns/1ps

module tb_risc_processor;

    reg  clk;
    reg  rst;

    wire [31:0] pc_out;
    wire [31:0] instruction_out;
    wire [31:0] alu_result_out;
    wire [31:0] mem_read_data_out;
    wire [31:0] led_out;

    integer errors;
    integer cycles;
    integer max_cycles;
    reg [1023:0] test_name;

    initial begin
        clk = 0;
        forever #5 clk = ~clk;
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

    task check_reg;
        input [4:0] reg_index;
        input [31:0] expected;
        begin
            if (uut.regfile.registers[reg_index] !== expected) begin
                $display("FAIL reg x%0d: expected %h, got %h",
                         reg_index, expected, uut.regfile.registers[reg_index]);
                errors = errors + 1;
            end else begin
                $display("PASS reg x%0d = %h", reg_index, expected);
            end
        end
    endtask

    task check_mem;
        input [5:0] word_index;
        input [31:0] expected;
        begin
            if (uut.dmem.memory[word_index] !== expected) begin
                $display("FAIL mem[%0d]: expected %h, got %h",
                         word_index, expected, uut.dmem.memory[word_index]);
                errors = errors + 1;
            end else begin
                $display("PASS mem[%0d] = %h", word_index, expected);
            end
        end
    endtask

    task check_led;
        input [31:0] expected;
        begin
            if (led_out !== expected) begin
                $display("FAIL led_out: expected %h, got %h", expected, led_out);
                errors = errors + 1;
            end else begin
                $display("PASS led_out = %h", expected);
            end
        end
    endtask

    initial begin
        errors = 0;
        cycles = 0;
        max_cycles = 80;

        if (!$value$plusargs("TEST=%s", test_name)) begin
            test_name = "fibonacci";
        end
        if (!$value$plusargs("MAX_CYCLES=%d", max_cycles)) begin
            max_cycles = 80;
        end

        $display("===== Running test: %0s =====", test_name);

        rst = 1;
        repeat (2) @(posedge clk);
        rst = 0;

        repeat (max_cycles) begin
            @(posedge clk);
            cycles = cycles + 1;
        end

        if (test_name == "alu") begin
            check_reg(1, 32'h00000005);
            check_reg(2, 32'h00000003);
            check_reg(3, 32'h00000008);
            check_reg(4, 32'h00000002);
            check_reg(5, 32'h00000001);
            check_reg(6, 32'h00000007);
            check_reg(7, 32'h00000006);
            check_reg(0, 32'h00000000);
        end else if (test_name == "memory") begin
            check_reg(3, 32'h0000002A);
            check_reg(4, 32'h00000063);
            check_mem(4, 32'h0000002A);
            check_mem(5, 32'h00000063);
        end else if (test_name == "forwarding") begin
            check_reg(3, 32'h0000000F);
            check_reg(4, 32'h00000014);
            check_reg(5, 32'h00000023);
        end else if (test_name == "load_use") begin
            check_reg(2, 32'h000000AA);
            check_reg(3, 32'h000000AF);
            check_reg(4, 32'h000000AF);
        end else if (test_name == "branch_flush") begin
            check_reg(1, 32'h00000001);
            check_reg(2, 32'h00000000);
            check_reg(3, 32'h00000003);
            check_reg(4, 32'h00000004);
        end else if (test_name == "store_forward") begin
            check_mem(6, 32'h0000000C);
            check_reg(5, 32'h0000000C);
        end else begin
            check_led(32'h00000037);
        end

        if (errors == 0) begin
            $display("TEST %0s PASS", test_name);
        end else begin
            $display("TEST %0s FAIL with %0d error(s)", test_name, errors);
            $fatal(1);
        end

        $finish;
    end

endmodule
