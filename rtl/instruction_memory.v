// Instruction Memory (ROM) - stores the program

module instruction_memory (
    input  wire [31:0] addr,    // Address to read from
    output wire [31:0] instruction // Instruction at the given address
);

    // 64 words of instruction memory (256 bytes)
    reg [31:0] rom [0:63];

    // Initialize with sample program, or load a directed simulation test.
    integer i;
    integer program_words;
    reg [1023:0] program_file;

    task load_default_program;
        begin
            // Fibonacci sequence generator
            // Calculates fibonacci and writes the current number to the LED port.
            rom[0]  = 32'hFFF00413; // addi x8, x0, -1      (x8 = 0xFFFFFFFF, MMIO address)
            rom[1]  = 32'h00000093; // addi x1, x0, 0       (x1 = 0, 'a')
            rom[2]  = 32'h00100113; // addi x2, x0, 1       (x2 = 1, 'b')
            rom[3]  = 32'h00A00213; // addi x4, x0, 10      (x4 = 10, max loops)
            rom[4]  = 32'h00000293; // addi x5, x0, 0       (x5 = 0, counter)
            rom[5]  = 32'h00428E63; // beq x5, x4, end      (branch +28 to Address 12)
            rom[6]  = 32'h002081B3; // add x3, x1, x2       (x3 = x1 + x2)
            rom[7]  = 32'h002000B3; // add x1, x0, x2       (x1 = x2)
            rom[8]  = 32'h00300133; // add x2, x0, x3       (x2 = x3)
            rom[9]  = 32'h00142023; // sw x1, 0(x8)         (Mem[0xFFFFFFFF] = x1)
            rom[10] = 32'h00128293; // addi x5, x5, 1       (x5 = x5 + 1)
            rom[11] = 32'hFE0004E3; // beq x0, x0, loop     (branch -24 to Address 5)
            rom[12] = 32'h00000063; // beq x0, x0, end      (infinite loop)
        end
    endtask

    task load_branch_flush_program;
        begin
            rom[0] = 32'h00100093; // addi x1, x0, 1
            rom[1] = 32'h00108663; // beq x1, x1, +12
            rom[2] = 32'h00200113; // addi x2, x0, 2    (wrong path)
            rom[3] = 32'h06300193; // addi x3, x0, 99   (wrong path)
            rom[4] = 32'h00300193; // addi x3, x0, 3
            rom[5] = 32'h00400213; // addi x4, x0, 4
            rom[6] = 32'h00000013; // nop
            rom[7] = 32'h00000013; // nop
        end
    endtask

    initial begin
        // NOP all initially
        for (i = 0; i < 64; i = i + 1) begin
            rom[i] = 32'h00000013; // default to NOP
        end

`ifdef BRANCH_FLUSH_TEST
        load_branch_flush_program();
`else
`ifndef SYNTHESIS
        if ($value$plusargs("PROGRAM=%s", program_file)) begin
            $display("Loading program: %0s", program_file);
            if ($value$plusargs("PROGRAM_WORDS=%d", program_words)) begin
                $readmemh(program_file, rom, 0, program_words - 1);
            end else begin
                $readmemh(program_file, rom);
            end
        end else begin
            load_default_program();
        end
`else
        load_default_program();
`endif
`endif
    end

    // Read instruction - word aligned
    assign instruction = rom[addr[31:2]];

endmodule
