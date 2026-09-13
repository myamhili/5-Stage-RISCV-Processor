// Self-checking Machine-mode interrupt and counter milestone testbench.
`timescale 1ns/1ps

module tb_machine_mode;
    reg clk;
    reg rst;
    reg irq_software;
    reg irq_timer;
    reg irq_external;

    wire retire_valid;
    wire [31:0] retire_pc;
    wire [31:0] retire_instruction;
    wire retire_rd_we;
    wire [4:0] retire_rd_addr;
    wire [31:0] retire_rd_data;
    wire retire_mem_valid;
    wire retire_mem_write;
    wire [31:0] retire_mem_addr;
    wire [31:0] retire_mem_wdata;
    wire [3:0] retire_mem_wstrb;
    wire trap_valid;
    wire [31:0] trap_pc;
    wire [31:0] trap_instruction;
    wire [31:0] trap_cause;
    wire [31:0] trap_tval;

    reg [255:0] test_name;
    integer errors;
    integer cycles;
    integer max_cycles;
    integer trap_count;
    integer physical_store_count;
    integer interrupt_triggered;
    integer completed;
    reg [31:0] observed_causes [0:2];

    initial begin
        clk = 1'b0;
        forever #5 clk = ~clk;
    end

    simple_soc uut (
        .clk(clk),
        .rst(rst),
        .irq_software(irq_software),
        .irq_timer(irq_timer),
        .irq_external(irq_external),
        .retire_valid(retire_valid),
        .retire_pc(retire_pc),
        .retire_instruction(retire_instruction),
        .retire_rd_we(retire_rd_we),
        .retire_rd_addr(retire_rd_addr),
        .retire_rd_data(retire_rd_data),
        .retire_mem_valid(retire_mem_valid),
        .retire_mem_write(retire_mem_write),
        .retire_mem_addr(retire_mem_addr),
        .retire_mem_wdata(retire_mem_wdata),
        .retire_mem_wstrb(retire_mem_wstrb),
        .trap_valid(trap_valid),
        .trap_pc(trap_pc),
        .trap_instruction(trap_instruction),
        .trap_cause(trap_cause),
        .trap_tval(trap_tval)
    );

    task expect_register;
        input [4:0] index;
        input [31:0] expected;
        begin
            if (uut.core.regfile.registers[index] !== expected) begin
                $display("FAIL x%0d expected=%08h got=%08h",
                         index, expected, uut.core.regfile.registers[index]);
                errors = errors + 1;
            end
        end
    endtask

    always @(posedge clk) begin
        if (!rst) begin
            if (retire_valid) begin
                $display("ARCH R %08h %08h %0d %02h %08h",
                         retire_pc, retire_instruction, retire_rd_we,
                         retire_rd_addr, retire_rd_data);
            end

            if (uut.b_dmem_req_valid && uut.b_dmem_req_ready &&
                uut.b_dmem_req_write)
                physical_store_count = physical_store_count + 1;

            // Assert the timer interrupt only after the selected memory
            // request has been accepted by the core-side delay adapter.
            if (!interrupt_triggered &&
                uut.dmem_req_valid && uut.dmem_req_ready) begin
                if ((test_name == "machine_interrupt_store") &&
                    uut.dmem_req_write) begin
                    irq_timer <= 1'b1;
                    interrupt_triggered = 1;
                end else if ((test_name == "machine_interrupt_load") &&
                             !uut.dmem_req_write) begin
                    irq_timer <= 1'b1;
                    interrupt_triggered = 1;
                end
            end

            if (!interrupt_triggered &&
                (test_name == "machine_interrupt_branch") &&
                uut.core.ex_mem_redirect_valid) begin
                irq_external <= 1'b1;
                interrupt_triggered = 1;
            end

            if (trap_valid) begin
                $display("ARCH T %08h %08h %08h",
                         trap_pc, trap_cause, trap_tval);

                if (!trap_cause[31]) begin
                    $display("FAIL Machine-mode test observed synchronous trap");
                    errors = errors + 1;
                end
                if (trap_instruction !== 32'h0000_0000) begin
                    $display("FAIL interrupt trap instruction must be zero");
                    errors = errors + 1;
                end
                if (trap_tval !== 32'h0000_0000) begin
                    $display("FAIL interrupt mtval must be zero");
                    errors = errors + 1;
                end
                if (!retire_valid) begin
                    $display("FAIL interrupt was not taken after a retirement");
                    errors = errors + 1;
                end

                if (trap_count < 3)
                    observed_causes[trap_count] = trap_cause;
                trap_count = trap_count + 1;

                // Level-sensitive sources are cleared by their peripheral
                // model, represented here by the testbench.
                if (trap_cause == 32'h8000_000B)
                    irq_external <= 1'b0;
                else if (trap_cause == 32'h8000_0003)
                    irq_software <= 1'b0;
                else if (trap_cause == 32'h8000_0007)
                    irq_timer <= 1'b0;
            end

            if (retire_rd_we) begin
                if ((test_name == "machine_counters") &&
                    (retire_rd_addr == 5'd11) &&
                    (retire_rd_data == 32'h0000_005A))
                    completed = 1;
                else if ((test_name == "machine_interrupt_store" ||
                          test_name == "machine_interrupt_load") &&
                         (retire_rd_addr == 5'd9) &&
                         (retire_rd_data == 32'h0000_005A))
                    completed = 1;
                else if ((retire_rd_addr == 5'd11) &&
                         (retire_rd_data == 32'h0000_005A))
                    completed = 1;
                else if ((test_name == "machine_interrupt_branch") &&
                         (retire_rd_addr == 5'd12) &&
                         (retire_rd_data == 32'h0000_005A))
                    completed = 1;
            end
        end
    end

    initial begin
        errors = 0;
        cycles = 0;
        max_cycles = 2000;
        trap_count = 0;
        physical_store_count = 0;
        interrupt_triggered = 0;
        completed = 0;
        observed_causes[0] = 32'h0;
        observed_causes[1] = 32'h0;
        observed_causes[2] = 32'h0;
        irq_software = 1'b0;
        irq_timer = 1'b0;
        irq_external = 1'b0;
        rst = 1'b1;

        if (!$value$plusargs("TEST=%s", test_name))
            test_name = "machine_interrupt_software";
        if (!$value$plusargs("MAX_CYCLES=%d", max_cycles))
            max_cycles = 2000;

        if (test_name == "machine_interrupt_software")
            irq_software = 1'b1;
        else if (test_name == "machine_interrupt_timer")
            irq_timer = 1'b1;
        else if (test_name == "machine_interrupt_external")
            irq_external = 1'b1;
        else if (test_name == "machine_interrupt_masking")
            irq_external = 1'b1;
        else if (test_name == "machine_interrupt_priority") begin
            irq_software = 1'b1;
            irq_timer = 1'b1;
            irq_external = 1'b1;
        end

        repeat (2) @(posedge clk);
        @(negedge clk);
        rst = 1'b0;

        while (!completed && cycles < max_cycles) begin
            @(negedge clk);
            cycles = cycles + 1;
        end
        #1;

        if (!completed) begin
            $display("FAIL test did not complete after %0d cycles", cycles);
            errors = errors + 1;
        end

        if (test_name == "machine_counters") begin
            if (trap_count != 0) begin
                $display("FAIL counter test observed %0d traps", trap_count);
                errors = errors + 1;
            end
            expect_register(5'd4, 32'h0000_0001);
            expect_register(5'd8, 32'h0000_0001);
            expect_register(5'd9, 32'h0000_0000);
            expect_register(5'd10, 32'h0000_0000);
        end else if (test_name == "machine_interrupt_priority") begin
            if (trap_count != 3) begin
                $display("FAIL priority test expected 3 traps got %0d", trap_count);
                errors = errors + 1;
            end
            if (observed_causes[0] !== 32'h8000_000B ||
                observed_causes[1] !== 32'h8000_0003 ||
                observed_causes[2] !== 32'h8000_0007) begin
                $display("FAIL interrupt priority/order %08h %08h %08h",
                         observed_causes[0], observed_causes[1],
                         observed_causes[2]);
                errors = errors + 1;
            end
            expect_register(5'd4, 32'h0000_0888);
            expect_register(5'd5, 32'h0000_0888);
            expect_register(5'd10, 32'h0000_0001);
            expect_register(5'd23, 32'h0000_0003);
        end else if (test_name == "machine_interrupt_store" ||
                     test_name == "machine_interrupt_load") begin
            if (trap_count != 1 || observed_causes[0] !== 32'h8000_0007) begin
                $display("FAIL memory interrupt cause/count");
                errors = errors + 1;
            end
            if (test_name == "machine_interrupt_store" &&
                uut.core.csr_inst.mepc !== 32'h0000_0028) begin
                $display("FAIL store interrupt mepc=%08h",
                         uut.core.csr_inst.mepc);
                errors = errors + 1;
            end
            if (test_name == "machine_interrupt_load" &&
                uut.core.csr_inst.mepc !== 32'h0000_002C) begin
                $display("FAIL load interrupt mepc=%08h",
                         uut.core.csr_inst.mepc);
                errors = errors + 1;
            end
            if (physical_store_count != 1) begin
                $display("FAIL expected one physical store got %0d",
                         physical_store_count);
                errors = errors + 1;
            end
            if (uut.memory.memory[0] !== 32'h0000_0055) begin
                $display("FAIL RAM write value=%08h", uut.memory.memory[0]);
                errors = errors + 1;
            end
            expect_register(5'd7, 32'h0000_0055);
            expect_register(5'd8, 32'h0000_0056);
            expect_register(5'd9, 32'h0000_005A);
            expect_register(5'd23, 32'h0000_0001);
        end else if (test_name == "machine_interrupt_masking") begin
            if (trap_count != 1 || observed_causes[0] !== 32'h8000_000B) begin
                $display("FAIL local interrupt masking cause/count");
                errors = errors + 1;
            end
            if (uut.core.csr_inst.mepc !== 32'h0000_002C) begin
                $display("FAIL masked interrupt mepc=%08h",
                         uut.core.csr_inst.mepc);
                errors = errors + 1;
            end
            expect_register(5'd11, 32'h0000_005A);
            expect_register(5'd12, 32'h0000_0001);
            expect_register(5'd23, 32'h0000_0001);
        end else if (test_name == "machine_interrupt_branch") begin
            if (trap_count != 1 || observed_causes[0] !== 32'h8000_000B) begin
                $display("FAIL branch interrupt cause/count");
                errors = errors + 1;
            end
            if (uut.core.csr_inst.mepc !== 32'h0000_002C) begin
                $display("FAIL branch interrupt mepc=%08h",
                         uut.core.csr_inst.mepc);
                errors = errors + 1;
            end
            expect_register(5'd11, 32'h0000_0000);
            expect_register(5'd12, 32'h0000_005A);
            expect_register(5'd23, 32'h0000_0001);
        end else begin
            if (trap_count != 1) begin
                $display("FAIL individual interrupt expected one trap got %0d",
                         trap_count);
                errors = errors + 1;
            end
            if (test_name == "machine_interrupt_software") begin
                if (observed_causes[0] !== 32'h8000_0003)
                    errors = errors + 1;
                expect_register(5'd5, 32'h0000_0008);
            end else if (test_name == "machine_interrupt_timer") begin
                if (observed_causes[0] !== 32'h8000_0007)
                    errors = errors + 1;
                expect_register(5'd5, 32'h0000_0080);
            end else if (test_name == "machine_interrupt_external") begin
                if (observed_causes[0] !== 32'h8000_000B)
                    errors = errors + 1;
                expect_register(5'd5, 32'h0000_0800);
            end
            if (uut.core.csr_inst.mepc !== 32'h0000_0024) begin
                $display("FAIL interrupt mepc=%08h", uut.core.csr_inst.mepc);
                errors = errors + 1;
            end
            expect_register(5'd4, 32'h0000_0888);
            expect_register(5'd10, 32'h0000_0001);
            expect_register(5'd11, 32'h0000_005A);
            expect_register(5'd22, 32'h0000_0000);
            expect_register(5'd23, 32'h0000_0001);
        end

        if (errors == 0)
            $display("TEST %0s PASS", test_name);
        else begin
            $display("TEST %0s FAIL with %0d error(s)", test_name, errors);
            $fatal(1);
        end
        $finish;
    end
endmodule
