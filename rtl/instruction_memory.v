// Instruction Memory (ROM) - stores the program

module instruction_memory (
    input  wire [31:0] addr,    // Address to read from
    output wire [31:0] instruction // Instruction at the given address
);

    // 64 words of instruction memory (256 bytes)
    reg [31:0] rom [0:63];

    // Initialize with sample program
    initial begin
        // RISC-V encoding (RV32I):
        // add:  R-type (funct7=0000000, rs2=reg, rs1=reg, funct3=000, rd=reg, opcode=0110011)
        // sub:  R-type (funct7=0100000, rs2=reg, rs1=reg, funct3=000, rd=reg, opcode=0110011)
        // and:  R-type (funct7=0000000, rs2=reg, rs1=reg, funct3=111, rd=reg, opcode=0110011)
        // or:   R-type (funct7=0000000, rs2=reg, rs1=reg, funct3=110, rd=reg, opcode=0110011)
        // lw:   I-type (imm[11:0], rs1=reg, funct3=010, rd=reg, opcode=0000011)
        // sw:   S-type (imm[11:5], rs2=reg, rs1=reg, funct3=010, imm[4:0], opcode=0100011)
        // beq:  B-type (imm[12|10:5], rs2, rs1, funct3=000, imm[4:1|11], opcode=1100011)
        
        // Let's set initial registers: we assume x1=4, x2=2 (but actually they are 0 at start)
        // Actually register_file initializes to 0. So x1=0, x2=0.
        // add x3, x1, x2  -> rs2=x2(00010) rs1=x1(00001) rd=x3(00011) -> 0000000 00010 00001 000 00011 0110011 -> 0x002081B3
        rom[0] = 32'h002081B3;
        
        // sub x4, x3, x2  -> rs2=x2(00010) rs1=x3(00011) rd=x4(00100) -> 0100000 00010 00011 000 00100 0110011 -> 0x40218233
        rom[1] = 32'h40218233;
        
        // and x5, x3, x4  -> rs2=x4(00100) rs1=x3(00011) rd=x5(00101) -> 0000000 00100 00011 111 00101 0110011 -> 0x0041F2B3
        rom[2] = 32'h0041F2B3;
        
        // or  x6, x4, x5  -> rs2=x5(00101) rs1=x4(00100) rd=x6(00110) -> 0000000 00101 00100 110 00110 0110011 -> 0x00526333
        rom[3] = 32'h00526333;
        
        // lw  x7, 0(x1)   -> imm=0 rs1=x1(00001) rd=x7(00111)         -> 000000000000 00001 010 00111 0000011 -> 0x0000A383
        rom[4] = 32'h0000A383;
        
        // sw  x7, 4(x1)   -> imm=4 rs2=x7(00111) rs1=x1(00001)        -> 0000000 00111 00001 010 00100 0100011 -> 0x0070A223
        rom[5] = 32'h0070A223;
        
        // beq x3, x4, 8   -> rs2=x4(00100) rs1=x3(00011) imm=8(000000001000) -> 0000000 00100 00011 000 01000 1100011 -> 0x00418463
        rom[6] = 32'h00418463;
        
        // Fill rest with NOP (addi x0, x0, 0)
        rom[7] = 32'h00000013;
        rom[8] = 32'h00000013;
        rom[9] = 32'h00000013;
        rom[10] = 32'h00000013;
        rom[11] = 32'h00000013;
        rom[12] = 32'h00000013;
        rom[13] = 32'h00000013;
        rom[14] = 32'h00000013;
        rom[15] = 32'h00000013;
    end

    // Read instruction - word aligned
    assign instruction = rom[addr[31:2]];

endmodule