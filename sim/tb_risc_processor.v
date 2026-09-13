// Self-checking testbench for the pipelined RISC-V processor.

`timescale 1ns/1ps

module tb_risc_processor;
    reg clk;
    reg rst;
    reg irq_software;
    reg irq_timer;
    reg irq_external;
    bus_monitor #(.PAYLOAD_WIDTH(32)) imem_monitor (
        .clk(clk), .rst(rst),
        .req_valid(uut.soc.imem_req_valid), .req_ready(uut.soc.imem_req_ready),
        .req_payload(uut.soc.imem_req_addr),
        .rsp_valid(uut.soc.imem_rsp_valid), .rsp_ready(uut.soc.imem_rsp_ready),
        .rsp_payload({uut.soc.imem_rsp_error,uut.soc.imem_rsp_data})
    );
    bus_monitor #(.PAYLOAD_WIDTH(69)) dmem_monitor (
        .clk(clk), .rst(rst),
        .req_valid(uut.soc.dmem_req_valid), .req_ready(uut.soc.dmem_req_ready),
        .req_payload({uut.soc.dmem_req_write,uut.soc.dmem_req_addr,uut.soc.dmem_req_wdata,uut.soc.dmem_req_wstrb}),
        .rsp_valid(uut.soc.dmem_rsp_valid), .rsp_ready(uut.soc.dmem_rsp_ready),
        .rsp_payload({uut.soc.dmem_rsp_error,uut.soc.dmem_rsp_rdata})
    );

    wire [31:0] pc_out;
    wire [31:0] instruction_out;
    wire [31:0] alu_result_out;
    wire [31:0] mem_read_data_out;
    wire [31:0] led_out;

    wire        retire_valid;
    wire [31:0] retire_pc;
    wire [31:0] retire_instruction;
    wire        retire_rd_we;
    wire [4:0]  retire_rd_addr;
    wire [31:0] retire_rd_data;

    wire        retire_mem_valid;
    wire        retire_mem_write;
    wire [31:0] retire_mem_addr;
    wire [31:0] retire_mem_wdata;
    wire [3:0]  retire_mem_wstrb;

    wire        trap_valid;
    wire [31:0] trap_pc;
    wire [31:0] trap_instruction;
    wire [31:0] trap_cause;
    wire [31:0] trap_tval;

    integer errors;
    integer cycles;
    integer max_cycles;
    reg [1023:0] test_name;

    integer physical_store_count;
    integer retired_store_count;
    integer expected_store_count;

    integer retirement_count;
    integer expected_retirements;
    integer expected_pc_count;
    integer trace_enabled;
    integer expected_pc_index;
    integer load_use_stall_count;
    integer use_retirement_limit;
    integer expect_trap;
    integer trap_count;
    reg [31:0] expected_trap_pc;
    reg [31:0] expected_trap_cause;
    reg [31:0] expected_trap_tval;

    reg [31:0] expected_retire_pc [0:63];

    initial begin
        clk = 0;
        forever #5 clk = ~clk;
    end

    risc_processor #(.LEGACY_DATA_MAP(1)) uut (
        .clk                  (clk),
        .rst                  (rst),
        .irq_software         (irq_software),
        .irq_timer            (irq_timer),
        .irq_external         (irq_external),

        .pc_out               (pc_out),
        .instruction_out      (instruction_out),
        .alu_result_out       (alu_result_out),
        .mem_read_data_out    (mem_read_data_out),
        .led_out              (led_out),

        .retire_valid         (retire_valid),
        .retire_pc            (retire_pc),
        .retire_instruction   (retire_instruction),
        .retire_rd_we         (retire_rd_we),
        .retire_rd_addr       (retire_rd_addr),
        .retire_rd_data       (retire_rd_data),

        .retire_mem_valid     (retire_mem_valid),
        .retire_mem_write     (retire_mem_write),
        .retire_mem_addr      (retire_mem_addr),
        .retire_mem_wdata     (retire_mem_wdata),
        .retire_mem_wstrb     (retire_mem_wstrb),

        .trap_valid           (trap_valid),
        .trap_pc              (trap_pc),
        .trap_instruction     (trap_instruction),
        .trap_cause           (trap_cause),
        .trap_tval            (trap_tval)
    );

    task add_expected_pc;
        input [31:0] pc;
        begin
            if (expected_pc_count >= 64) begin
                $display("FAIL: expected retirement PC table overflow");
                errors = errors + 1;
            end else begin
                expected_retire_pc[expected_pc_count] = pc;
                expected_pc_count = expected_pc_count + 1;
            end
        end
    endtask

    function [3:0] expected_store_strobe;
        input [2:0] store_funct3;
        input [1:0] address_low;
        begin
            case (store_funct3)
                3'b000: expected_store_strobe = 4'b0001 << address_low;
                3'b001: expected_store_strobe = address_low[1] ?
                                                       4'b1100 : 4'b0011;
                3'b010: expected_store_strobe = 4'b1111;
                default: expected_store_strobe = 4'b0000;
            endcase
        end
    endfunction

    task configure_expected_pcs;
        begin
            expected_pc_count = 0;

            if (test_name == "branch_flush") begin
                // PCs 8 and 12 are fetched but must be flushed.
                add_expected_pc(32'h00000000);
                add_expected_pc(32'h00000004);
                add_expected_pc(32'h00000010);
                add_expected_pc(32'h00000014);
                add_expected_pc(32'h00000018);
                add_expected_pc(32'h0000001C);
            end else if (test_name == "jumps") begin
                // JAL flushes PCs 4 and 8; JALR flushes PCs 24 and 28.
                add_expected_pc(32'h00000000);
                add_expected_pc(32'h0000000C);
                add_expected_pc(32'h00000010);
                add_expected_pc(32'h00000014);
                add_expected_pc(32'h00000020);
                add_expected_pc(32'h00000024);
                add_expected_pc(32'h00000028);
            end else if (test_name == "jump_backward") begin
                // The JAL at PC 20 redirects backward to PC 8.
                add_expected_pc(32'h00000000);
                add_expected_pc(32'h00000004);
                add_expected_pc(32'h0000000C);
                add_expected_pc(32'h00000014);
                add_expected_pc(32'h00000008);
                add_expected_pc(32'h0000000C);
                add_expected_pc(32'h00000010);
                add_expected_pc(32'h0000001C);
                add_expected_pc(32'h00000020);
                add_expected_pc(32'h00000024);
            end else if (test_name == "branches_all") begin
                // All wrong-path sentinel writes and the fail block are skipped.
                add_expected_pc(32'h00000000);
                add_expected_pc(32'h00000004);
                add_expected_pc(32'h00000008);
                add_expected_pc(32'h0000000C);
                add_expected_pc(32'h00000014);
                add_expected_pc(32'h00000018);
                add_expected_pc(32'h0000001C);
                add_expected_pc(32'h00000024);
                add_expected_pc(32'h00000028);
                add_expected_pc(32'h0000002C);
                add_expected_pc(32'h00000034);
                add_expected_pc(32'h00000038);
                add_expected_pc(32'h0000003C);
                add_expected_pc(32'h00000044);
                add_expected_pc(32'h00000048);
                add_expected_pc(32'h0000004C);
                add_expected_pc(32'h00000054);
                add_expected_pc(32'h00000058);
                add_expected_pc(32'h0000005C);
                add_expected_pc(32'h00000064);
                add_expected_pc(32'h00000068);
                add_expected_pc(32'h0000006C);
                add_expected_pc(32'h00000070);
                add_expected_pc(32'h00000074);
                add_expected_pc(32'h0000007C);
                add_expected_pc(32'h00000080);
                add_expected_pc(32'h00000084);
                add_expected_pc(32'h00000088);
                add_expected_pc(32'h00000090);
                add_expected_pc(32'h00000094);
                add_expected_pc(32'h0000009C);
                add_expected_pc(32'h000000A0);
            end else if (test_name == "csr_mret") begin
                add_expected_pc(32'h00000000);
                add_expected_pc(32'h00000004);
                add_expected_pc(32'h00000008);
                add_expected_pc(32'h0000000C);
                add_expected_pc(32'h00000010);
                add_expected_pc(32'h00000014);
                add_expected_pc(32'h00000018);
                add_expected_pc(32'h0000001C);
                add_expected_pc(32'h00000020);
                add_expected_pc(32'h00000024);
                add_expected_pc(32'h00000028);
                add_expected_pc(32'h0000002C);
                add_expected_pc(32'h00000030);
                add_expected_pc(32'h00000034);
                add_expected_pc(32'h00000038);
                add_expected_pc(32'h00000044);
                add_expected_pc(32'h00000048);
                add_expected_pc(32'h0000004C);
                add_expected_pc(32'h00000050);
            end else if (test_name == "trap_resume") begin
                add_expected_pc(32'h00000000);
                add_expected_pc(32'h00000004);
                add_expected_pc(32'h00000008);
                add_expected_pc(32'h0000000C);
                add_expected_pc(32'h0000001C);
                add_expected_pc(32'h00000020);
                add_expected_pc(32'h00000024);
                add_expected_pc(32'h00000028);
                add_expected_pc(32'h0000002C);
                add_expected_pc(32'h00000030);
                add_expected_pc(32'h00000014);
                add_expected_pc(32'h00000018);
                add_expected_pc(32'h00000034);
                add_expected_pc(32'h00000038);
                add_expected_pc(32'h0000003C);
            end else begin
                for (expected_pc_index = 0;
                     expected_pc_index < expected_retirements;
                     expected_pc_index = expected_pc_index + 1) begin
                    add_expected_pc(expected_pc_index * 4);
                end
            end
        end
    endtask

    always @(posedge clk) begin
        if (rst) begin
            physical_store_count = 0;
            retired_store_count  = 0;
            retirement_count     = 0;
            load_use_stall_count = 0;
            trap_count           = 0;
        end else begin
            if (uut.soc.core.load_use_hazard)
                load_use_stall_count = load_use_stall_count + 1;

            if (uut.soc.core.ex_memory_misaligned && !expect_trap) begin
                $display(
                    "FAIL: unexpected misaligned memory access pc=%08h instruction=%08h",
                    uut.soc.core.id_ex_pc,
                    uut.soc.core.id_ex_instruction
                );
                errors = errors + 1;
            end

            if (uut.soc.core.id_ex_valid && uut.soc.core.id_ex_illegal && !expect_trap) begin
                $display(
                    "FAIL: illegal instruction entered EX pc=%08h instruction=%08h",
                    uut.soc.core.id_ex_pc,
                    uut.soc.core.id_ex_instruction
                );
                errors = errors + 1;
            end

            if (uut.soc.dmem_req_valid && uut.soc.dmem_req_ready && uut.soc.dmem_req_write)
                physical_store_count = physical_store_count + 1;

            if (retire_valid) begin
                $display("ARCH R %08h %08h %b %02h %08h %b %b %08h %08h %h",
                    retire_pc, retire_instruction, retire_rd_we,
                    retire_rd_we ? retire_rd_addr : 5'b0,
                    retire_rd_we ? retire_rd_data : 32'b0,
                    retire_mem_valid, retire_mem_write,
                    retire_mem_valid ? retire_mem_addr : 32'b0,
                    retire_mem_write ? retire_mem_wdata : 32'b0,
                    retire_mem_wstrb);
                if (trace_enabled) begin
                    $display(
                        "RETIRE pc=%08h instruction=%08h",
                        retire_pc,
                        retire_instruction
                    );
                end

                if (trace_enabled && retire_rd_we) begin
                    $display(
                        "  write x%0d = %08h",
                        retire_rd_addr,
                        retire_rd_data
                    );
                end

                if (retire_mem_write) begin
                    retired_store_count = retired_store_count + 1;

                    if (trace_enabled) begin
                        $display(
                            "  store addr=%08h data=%08h strb=%b",
                            retire_mem_addr,
                            retire_mem_wdata,
                            retire_mem_wstrb
                        );
                    end
                end

                if (use_retirement_limit) begin
                    if (retirement_count >= expected_retirements) begin
                        $display(
                            "FAIL: unexpected retirement PC=%08h instruction=%08h",
                            retire_pc,
                            retire_instruction
                        );
                        errors = errors + 1;
                    end else begin
                        if (retire_pc !== expected_retire_pc[retirement_count]) begin
                            $display(
                                "FAIL: retirement %0d expected PC=%08h got=%08h",
                                retirement_count,
                                expected_retire_pc[retirement_count],
                                retire_pc
                            );
                            errors = errors + 1;
                        end

                        if (retire_pc[1:0] !== 2'b00) begin
                            $display(
                                "FAIL: misaligned retirement PC=%08h",
                                retire_pc
                            );
                            errors = errors + 1;
                        end else if (retire_pc >= 32'd256) begin
                            $display(
                                "FAIL: retirement PC outside instruction ROM=%08h",
                                retire_pc
                            );
                            errors = errors + 1;
                        end else begin
                            if (retire_instruction !==
                                uut.soc.memory.rom[retire_pc[31:2]]) begin
                                $display(
                                    "FAIL: PC=%08h expected instruction=%08h got=%08h",
                                    retire_pc,
                                    uut.soc.memory.rom[retire_pc[31:2]],
                                    retire_instruction
                                );
                                errors = errors + 1;
                            end
                        end
                    end
                end

                if (retire_rd_we && retire_rd_addr == 5'd0) begin
                    $display(
                        "FAIL: retirement reported a write to x0"
                    );
                    errors = errors + 1;
                end

                if (retire_mem_write && !retire_mem_valid) begin
                    $display("FAIL: store reported without memory-valid");
                    errors = errors + 1;
                end

                if (retire_mem_write &&
                    retire_mem_wstrb !== expected_store_strobe(
                        retire_instruction[14:12],
                        retire_mem_addr[1:0]
                    )) begin
                    $display(
                        "FAIL: store retired with incorrect strobes %b",
                        retire_mem_wstrb
                    );
                    errors = errors + 1;
                end

                retirement_count = retirement_count + 1;
            end else if (retire_rd_we || retire_mem_valid || retire_mem_write) begin
                $display("FAIL: invalid retirement reported side effects");
                errors = errors + 1;
            end

            if (retire_valid && trap_valid && !trap_cause[31]) begin
                $display(
                    "FAIL: retirement and synchronous trap occurred simultaneously"
                );
                errors = errors + 1;
            end

            if (trap_valid) begin
                $display("ARCH T %08h %08h %08h",trap_pc,trap_cause,trap_tval);
                if (!expect_trap) begin
                    $display(
                        "FAIL: unexpected trap pc=%08h instruction=%08h cause=%08h tval=%08h",
                        trap_pc, trap_instruction, trap_cause, trap_tval
                    );
                    errors = errors + 1;
                end else if (trap_count != 0) begin
                    $display("FAIL: more than one trap observed");
                    errors = errors + 1;
                end else begin
                    if (trap_pc !== expected_trap_pc) begin
                        $display("FAIL trap PC: expected %08h got %08h",
                                 expected_trap_pc, trap_pc);
                        errors = errors + 1;
                    end
                    if (trap_cause !== expected_trap_cause) begin
                        $display("FAIL trap cause: expected %08h got %08h",
                                 expected_trap_cause, trap_cause);
                        errors = errors + 1;
                    end
                    if (trap_tval !== expected_trap_tval) begin
                        $display("FAIL trap tval: expected %08h got %08h",
                                 expected_trap_tval, trap_tval);
                        errors = errors + 1;
                    end
                    $display("PASS trap pc=%08h cause=%0d tval=%08h",
                             trap_pc, trap_cause, trap_tval);
                end
                trap_count = trap_count + 1;
            end
        end
    end

    task check_reg;
        input [4:0] reg_index;
        input [31:0] expected;
        begin
            if (uut.soc.core.regfile.registers[reg_index] !== expected) begin
                $display("FAIL reg x%0d: expected %h, got %h",
                         reg_index, expected, uut.soc.core.regfile.registers[reg_index]);
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
            if (uut.soc.memory.memory[word_index] !== expected) begin
                $display("FAIL mem[%0d]: expected %h, got %h",
                         word_index, expected, uut.soc.memory.memory[word_index]);
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
        max_cycles = 120;
        irq_software = 1'b0;
        irq_timer = 1'b0;
        irq_external = 1'b0;

        physical_store_count = 0;
        retired_store_count  = 0;
        expected_store_count = 0;

        retirement_count   = 0;
        expected_retirements = 0;
        expected_pc_count  = 0;
        trace_enabled      = $test$plusargs("TRACE");
        load_use_stall_count = 0;
        use_retirement_limit = 0;
        expect_trap         = 0;
        trap_count           = 0;
        expected_trap_pc     = 32'h0000_0000;
        expected_trap_cause  = 32'h0000_0000;
        expected_trap_tval   = 32'h0000_0000;

        if (!$value$plusargs("TEST=%s", test_name)) begin
            test_name = "fibonacci";
        end
        if (test_name == "memory") begin
            expected_store_count = 2;
        end else if (test_name == "store_forward") begin
            expected_store_count = 1;
        end else if (test_name == "subword_memory") begin
            expected_store_count = 13;
        end else begin
            expected_store_count = 0;
        end
        if (!$value$plusargs("MAX_CYCLES=%d", max_cycles)) begin
            max_cycles = 120;
        end
        use_retirement_limit = $value$plusargs(
            "EXPECTED_RETIREMENTS=%d",
            expected_retirements
        );
        expect_trap = $value$plusargs(
            "EXPECTED_TRAP_CAUSE=%d",
            expected_trap_cause
        );
        if (expect_trap) begin
            if (!$value$plusargs("EXPECTED_TRAP_PC=%h", expected_trap_pc)) begin
                $display("FAIL: missing EXPECTED_TRAP_PC");
                errors = errors + 1;
            end
            if (!$value$plusargs("EXPECTED_TRAP_TVAL=%h", expected_trap_tval)) begin
                $display("FAIL: missing EXPECTED_TRAP_TVAL");
                errors = errors + 1;
            end
        end

        if (use_retirement_limit) begin
            configure_expected_pcs();

            if (expected_pc_count != expected_retirements) begin
                $display(
                    "FAIL: configured %0d expected PCs for %0d retirements",
                    expected_pc_count,
                    expected_retirements
                );
                errors = errors + 1;
            end
        end

        $display("===== Running test: %0s =====", test_name);

        rst = 1;
        repeat (2) @(posedge clk);
        @(negedge clk);
        rst = 0;

        if (expect_trap && !use_retirement_limit) begin
            while ((trap_count < 1) && (cycles < max_cycles)) begin
                @(negedge clk);
                cycles = cycles + 1;
            end
        end else if (use_retirement_limit) begin
            while ((retirement_count < expected_retirements) &&
                   (cycles < max_cycles)) begin
                @(negedge clk);
                cycles = cycles + 1;
            end
        end else if (test_name == "fibonacci") begin
            while (retired_store_count < 10 && cycles < max_cycles) begin
                @(negedge clk);
                cycles = cycles + 1;
            end
        end else begin
            repeat (max_cycles) begin
                @(negedge clk);
                cycles = cycles + 1;
            end
        end

        #1;

        if (use_retirement_limit &&
            retirement_count != expected_retirements) begin
            $display(
                "FAIL: expected %0d retirements, observed %0d after %0d cycles",
                expected_retirements,
                retirement_count,
                cycles
            );
            errors = errors + 1;
        end

        if (expect_trap && trap_count != 1) begin
            $display("FAIL: expected one trap, observed %0d", trap_count);
            errors = errors + 1;
        end

        if (test_name == "fibonacci" && retired_store_count != 10) begin
            $display("FAIL Fibonacci completion");
            errors=errors+1;
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
        end else if (test_name == "upper_immediate") begin
            check_reg(1, 32'h12345000);
            check_reg(2, 32'h00000008);
            check_reg(3, 32'h0000100C);
            check_reg(4, 32'h00001014);
            check_reg(5, 32'h12345001);
        end else if (test_name == "jumps") begin
            check_reg(1, 32'h00000021);
            check_reg(2, 32'h00000000);
            check_reg(3, 32'h00000000);
            check_reg(4, 32'h00000005);
            check_reg(5, 32'h00000004);
            check_reg(6, 32'h00000018);
            check_reg(7, 32'h00000000);
            check_reg(8, 32'h00000000);
            check_reg(9, 32'h00000019);
        end else if (test_name == "jump_backward") begin
            check_reg(1, 32'h00000001);
            check_reg(2, 32'h00000000);
            check_reg(3, 32'h00000019);
            check_reg(5, 32'h00000018);
        end else if (test_name == "compare") begin
            check_reg(3,  32'h00000001);
            check_reg(4,  32'h00000000);
            check_reg(5,  32'h00000000);
            check_reg(6,  32'h00000001);
            check_reg(7,  32'h00000001);
            check_reg(8,  32'h00000000);
            check_reg(9,  32'h00000001);
            check_reg(10, 32'h00000000);
            check_reg(12, 32'h00000001);
            check_reg(13, 32'h00000000);
            check_reg(14, 32'h00000000);
            check_reg(15, 32'h00000001);
            check_reg(16, 32'h00000002);
        end else if (test_name == "shifts") begin
            check_reg(2,  32'h80000000);
            check_reg(3,  32'h00000001);
            check_reg(5,  32'hFFFFFFFC);
            check_reg(6,  32'h3FFFFFFC);
            check_reg(8,  32'h00000002);
            check_reg(9,  32'h40000000);
            check_reg(10, 32'hFFFFFFF8);
            check_reg(11, 32'h00000001);
            check_reg(12, 32'hFFFFFFFF);
            check_reg(13, 32'h00000001);
            check_reg(14, 32'h00000002);
        end else if (test_name == "branches_all") begin
            check_reg(3,  32'h000000FF);
            check_reg(4,  32'h000000AA);
            check_reg(5,  32'h000000AA);
            check_reg(6,  32'h00000007);
            check_reg(8,  32'h00000007);
            check_reg(10, 32'h00000000);
            check_reg(11, 32'h00000000);
            check_reg(12, 32'h00000000);
            check_reg(13, 32'h00000000);
            check_reg(14, 32'h00000000);
            check_reg(15, 32'h00000000);
            check_reg(16, 32'h00000000);
            check_reg(17, 32'h00000000);
            check_reg(31, 32'h00000000);
        end else if (test_name == "subword_memory") begin
            check_reg(1,  32'h80FF7F01);
            check_reg(2,  32'h00000001);
            check_reg(3,  32'h0000007F);
            check_reg(4,  32'hFFFFFFFF);
            check_reg(5,  32'h000000FF);
            check_reg(6,  32'hFFFFFF80);
            check_reg(7,  32'h00000080);
            check_reg(8,  32'h00007F01);
            check_reg(9,  32'hFFFF80FF);
            check_reg(10, 32'h000080FF);
            check_reg(12, 32'h44332211);
            check_reg(15, 32'hC3D4A1B2);
            check_reg(18, 32'h5566AA88);
            check_reg(20, 32'hFFFEAA88);
            check_reg(21, 32'hFFFFFF80);
            check_reg(22, 32'hFFFFFF81);
            check_reg(24, 32'h0000005A);
            check_mem(8,  32'h80FF7F01);
            check_mem(10, 32'h44332211);
            check_mem(11, 32'hC3D4A1B2);
            check_mem(12, 32'hFFFEAA88);
            check_mem(13, 32'h0000005A);
            check_led(32'h00341200);
        end else if (test_name == "csr_mret") begin
            check_reg(2,  32'h00000000);
            check_reg(3,  32'h00000055);
            check_reg(5,  32'h00000055);
            check_reg(7,  32'h0000005F);
            check_reg(8,  32'h0000005C);
            check_reg(9,  32'h00000007);
            check_reg(10, 32'h0000000F);
            check_reg(11, 32'h0000000E);
            check_reg(13, 32'h0000000D);
            check_reg(14, 32'h0000000E);
        end else if (test_name == "fence_system") begin
            check_reg(1, 32'h00000001);
            check_reg(2, 32'h00000003);
        end else if (test_name == "branch_misaligned_not_taken") begin
            check_reg(1, 32'h00000001);
            check_reg(2, 32'h00000002);
        end else if (test_name == "csr_readonly_read") begin
            check_reg(1, 32'h40000100);
            check_reg(2, 32'h40000100);
        end else if (test_name == "trap_load_misaligned") begin
            check_reg(2, 32'h00000055);
            check_reg(3, 32'h00000000);
        end else if (test_name == "trap_store_misaligned") begin
            check_mem(0, 32'h000000AA);
            check_reg(3, 32'h00000000);
        end else if (test_name == "trap_csr_illegal") begin
            check_reg(1, 32'h00000001);
            check_reg(2, 32'h00000000);
        end else if (test_name == "trap_resume") begin
            check_reg(2,  32'h0000000B);
            check_reg(3,  32'h00000014);
            check_reg(4,  32'h00000000);
            check_reg(10, 32'h00000001);
            check_reg(11, 32'h0000000B);
        end else if (expect_trap) begin
            // Trap metadata is checked by the trap monitor above.
        end else begin
            check_led(32'h00000037);
        end

        if (use_retirement_limit &&
            physical_store_count != expected_store_count) begin
            $display(
                "FAIL: expected %0d physical stores, got %0d",
                expected_store_count,
                physical_store_count
            );

            errors = errors + 1;
        end

        if(use_retirement_limit &&
           retired_store_count != expected_store_count) begin
            $display(
                "FAIL: expected %0d retired stores, got %0d",
                expected_store_count,
                retired_store_count
            );

            errors = errors + 1;
        end

        if (use_retirement_limit &&
            physical_store_count != retired_store_count) begin
            $display(
                "FAIL: physical stores=%0d retired stores=%0d",
                physical_store_count,
                retired_store_count
            );

            errors = errors + 1;
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
