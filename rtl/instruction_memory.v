// Instruction Memory (ROM) - stores the program

module instruction_memory (
    input  wire [31:0] addr,    // Address to read from
    output wire [31:0] instruction // Instruction at the given address
);

    // 64 words of instruction memory (256 bytes)
    reg [31:0] rom [0:63];

    // Initialize with sample program
    integer i;
    initial begin
        // Fibonacci sequence generator
        // Calculates fibonacci and writes the current number to the LED port.
        
        // NOP all initially
        for (i = 0; i < 64; i = i + 1) begin
            rom[i] = 32'h00000013; // default to NOP
        end

        // Initialization
        rom[0]  = 32'hFFF00413; // addi x8, x0, -1      (x8 = 0xFFFFFFFF, MMIO address)
        rom[1]  = 32'h00000093; // addi x1, x0, 0       (x1 = 0, 'a')
        rom[2]  = 32'h00100113; // addi x2, x0, 1       (x2 = 1, 'b')
        rom[3]  = 32'h00A00213; // addi x4, x0, 10      (x4 = 10, max loops)
        rom[4]  = 32'h00000293; // addi x5, x0, 0       (x5 = 0, counter)

        // loop: (Address 5)
        // if (counter == max) goto end
        rom[5]  = 32'h00428E63; // beq x5, x4, end      (branch +28 to Address 12)
        
        // next = a + b
        rom[6]  = 32'h002081B3; // add x3, x1, x2       (x3 = x1 + x2)
        
        // a = b
        rom[7]  = 32'h002000B3; // add x1, x0, x2       (x1 = x2)
        
        // b = next
        rom[8]  = 32'h00300133; // add x2, x0, x3       (x2 = x3)
        
        // LED = a
        rom[9]  = 32'h00142023; // sw x1, 0(x8)         (Mem[0xFFFFFFFF] = x1)
        
        // counter++
        rom[10] = 32'h00128293; // addi x5, x5, 1       (x5 = x5 + 1)
        
        // goto loop
        rom[11] = 32'hFE0004E3; // beq x0, x0, loop     (branch -24 to Address 5)
        
        // end: (Address 12)
        rom[12] = 32'h00000063; // beq x0, x0, end      (infinite loop)
    end

    // Read instruction - word aligned
    assign instruction = rom[addr[31:2]];

endmodule