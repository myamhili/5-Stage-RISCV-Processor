`timescale 1ns/1ps
module tb_memory_milestone;
    reg clk=0, rst=1;
    always #5 clk=~clk;
    wire [31:0] led_out;
    wire retire_valid, retire_rd_we, retire_mem_valid, retire_mem_write, trap_valid;
    wire [31:0] retire_pc, retire_instruction, retire_rd_data;
    wire [4:0] retire_rd_addr;
    wire [31:0] retire_mem_addr, retire_mem_wdata, trap_pc, trap_cause, trap_tval;
    wire [3:0] retire_mem_wstrb;
    simple_soc uut (
        .clk(clk), .rst(rst), .led_out(led_out),
        .irq_software(1'b0), .irq_timer(1'b0), .irq_external(1'b0),
        .retire_valid(retire_valid), .retire_pc(retire_pc),
        .retire_instruction(retire_instruction),
        .retire_rd_we(retire_rd_we), .retire_rd_addr(retire_rd_addr),
        .retire_rd_data(retire_rd_data), .retire_mem_valid(retire_mem_valid),
        .retire_mem_write(retire_mem_write), .retire_mem_addr(retire_mem_addr),
        .retire_mem_wdata(retire_mem_wdata), .retire_mem_wstrb(retire_mem_wstrb),
        .trap_valid(trap_valid), .trap_pc(trap_pc),
        .trap_cause(trap_cause), .trap_tval(trap_tval)
    );
    bus_monitor #(.PAYLOAD_WIDTH(32)) imem_monitor (
        .clk(clk), .rst(rst),
        .req_valid(uut.imem_req_valid), .req_ready(uut.imem_req_ready),
        .req_payload(uut.imem_req_addr),
        .rsp_valid(uut.imem_rsp_valid), .rsp_ready(uut.imem_rsp_ready),
        .rsp_payload({uut.imem_rsp_error,uut.imem_rsp_data})
    );
    bus_monitor #(.PAYLOAD_WIDTH(69)) dmem_monitor (
        .clk(clk), .rst(rst),
        .req_valid(uut.dmem_req_valid), .req_ready(uut.dmem_req_ready),
        .req_payload({uut.dmem_req_write,uut.dmem_req_addr,uut.dmem_req_wdata,uut.dmem_req_wstrb}),
        .rsp_valid(uut.dmem_rsp_valid), .rsp_ready(uut.dmem_rsp_ready),
        .rsp_payload({uut.dmem_rsp_error,uut.dmem_rsp_rdata})
    );

    reg [255:0] test_name;
    integer cycles=0, stores=0, retired_stores=0, responses=0, retired_memory=0;
    integer expected_cause, expected_stores, unused, reset_mode, resets=0;
    reg [31:0] expected_pc, expected_tval;
    reg done=0;
    reg expect_trap;
    reg [31:0] saved_rom;
    always @(posedge clk) if (!rst) begin
        if (uut.dmem_req_valid && uut.dmem_req_ready && uut.dmem_req_write)
            stores=stores+1;
        if (uut.dmem_rsp_valid && uut.dmem_rsp_ready && !uut.dmem_rsp_error)
            responses=responses+1;
        if (retire_valid) begin
            $display("ARCH R %08h %08h %b %02h %08h %b %b %08h %08h %h",
                retire_pc,retire_instruction,retire_rd_we,
                retire_rd_we ? retire_rd_addr : 5'b0,
                retire_rd_we ? retire_rd_data : 32'b0,
                retire_mem_valid,retire_mem_write,
                retire_mem_valid ? retire_mem_addr : 32'b0,
                retire_mem_write ? retire_mem_wdata : 32'b0,retire_mem_wstrb);
            if (retire_mem_write) retired_stores=retired_stores+1;
            if (retire_mem_valid) begin
                retired_memory=retired_memory+1;
                if (retired_memory>responses) $fatal(1,"Retired before memory response");
            end
            if (retire_rd_we && retire_rd_addr==31) done=1;
            if (retire_rd_we && retire_rd_addr==30) $fatal(1,"Wrong-path instruction retired");
        end
        if (trap_valid) begin
            $display("ARCH T %08h %08h %08h",trap_pc,trap_cause,trap_tval);
            if (!expect_trap || trap_cause !== expected_cause ||
                trap_pc !== expected_pc || trap_tval !== expected_tval)
                $fatal(1,"Unexpected trap PC=%h cause=%d tval=%h",trap_pc,trap_cause,trap_tval);
            done=1;
        end
    end
    initial begin
        unused=$value$plusargs("TEST=%s",test_name);
        expect_trap=$value$plusargs("EXPECTED_TRAP_CAUSE=%d",expected_cause);
        unused=$value$plusargs("EXPECTED_TRAP_PC=%h",expected_pc);
        unused=$value$plusargs("EXPECTED_TRAP_TVAL=%h",expected_tval);
        unused=$value$plusargs("EXPECTED_STORES=%d",expected_stores);
        reset_mode=0;
        unused=$value$plusargs("RESET_MODE=%d",reset_mode);
        #1; saved_rom=uut.memory.rom[0];
        repeat(3) @(negedge clk);
        rst=0;
        // Reset both endpoints while an operation is outstanding, before
        // its delayed response. Memory contents intentionally survive reset.
        if (reset_mode!=0) begin
            if (reset_mode==1) wait(uut.imem_req_valid && uut.imem_req_ready);
            else wait(uut.dmem_req_valid && uut.dmem_req_ready);
            @(posedge clk); @(negedge clk);
            rst=1;
            repeat(3) @(negedge clk);
            stores=0; retired_stores=0; responses=0; retired_memory=0;
            done=0; resets=1; rst=0;
        end
        while (!done && cycles<10000) begin
            @(negedge clk); cycles=cycles+1;
        end
        #1;
        if (!done) $fatal(1,"Timeout");
        if (reset_mode!=0 && resets!=1) $fatal(1,"Reset not exercised");
        if (stores!=expected_stores) $fatal(1,"Store count %d expected %d",stores,expected_stores);
        if (!expect_trap && retired_stores!=expected_stores) $fatal(1,"Duplicate/lost store retirement");
        if (expect_trap) begin
            if (uut.core.csr_inst.mcause !== expected_cause ||
                uut.core.csr_inst.mepc !== expected_pc ||
                uut.core.csr_inst.mtval !== expected_tval)
                $fatal(1,"Trap CSR metadata mismatch");
            if (uut.memory.memory[0] !== 0 || led_out !== 0 ||
                uut.memory.rom[0] !== saved_rom)
                $fatal(1,"Faulting/wrong-path store changed memory");
        end
        if (test_name=="memory_wait_states") begin
            if (uut.core.regfile.registers[7] !== 14 ||
                uut.core.regfile.registers[9] !== 14 ||
                uut.memory.memory[1] !== 14) $fatal(1,"Stalled operand/load/CSR failed");
        end
        if (test_name=="store_issued_once" &&
            (led_out !== 32'h00005a00 || uut.core.regfile.registers[6] !== 32'h5a00))
            $fatal(1,"GPIO byte lanes failed");
        if (test_name=="fence_executable_ram" &&
            (uut.core.regfile.registers[11] !== 42 || uut.core.regfile.registers[10] !== 43))
            $fatal(1,"Instruction fetch did not observe RAM writes after FENCE.I");
        $display("TEST %0s PASS",test_name);
        $finish;
    end
    initial begin #2000000; $fatal(1,"Watchdog"); end
endmodule
