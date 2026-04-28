// Instruction Memory (ROM) - stores the program

module instruction_memory (
    input  wire [31:0] addr,    // Address to read from
    output wire [31:0] instruction // Instruction at the given address
);

    // 64 words of instruction memory (256 bytes)
    reg [31:0] rom [0:63];

    // Initialize with sample program
    initial begin
        // Sample RISC-V program:
        // Address 0: add x3, x1, x2  (add x3, x1, x2)
        // Address 4: sub x4, x3, x2
        // Address 8: and x5, x3, x4
        // Address C: or  x6, x4, x5
        // Address 10: lw  x7, 0(x1)
        // Address 14: sw  x7, 4(x1)
        // Address 18: beq x3, x4, 8  (branch to address 0x24 if equal)
        
        // RISC-V encoding (RV32I):
        // add:  R-type (funct7=0000000, rs2=reg, rs1=reg, funct3=000, rd=reg, opcode=0110011)
        // sub:  R-type (funct7=0100000, rs2=reg, rs1=reg, funct3=000, rd=reg, opcode=0110011)
        // and:  R-type (funct7=0000000, rs2=reg, rs1=reg, funct3=111, rd=reg, opcode=0110011)
        // or:   R-type (funct7=0000000, rs2=reg, rs1=reg, funct3=110, rd=reg, opcode=0110011)
        // lw:   I-type (imm[11:0], rs1=reg, funct3=010, rd=reg, opcode=0000011)
        // sw:   S-type (imm[11:5], rs2=reg, rs1=reg, funct3=010, imm[4:0], opcode=0100011)
        // beq:  B-type (imm[12|10:5], rs2, rs1, funct3=000, imm[4:1|11], opcode=1100011)
        
        // add x3, x1, x2  -> 0x002101B3
        rom[0] = 32'h002101B3;
        // sub x4, x3, x2  -> 0x00218233
        rom[1] = 32'h00218233;
        // and x5, x3, x4  -> 0x0031E2B3
        rom[2] = 32'h0031E2B3;
        // or  x6, x4, x5  -> 0x0042C333
        rom[3] = 32'h0042C333;
        // lw  x7, 0(x1)   -> 0x00012083
        rom[4] = 32'h00012083;
        // sw  x7, 4(x1)   -> 0x0041A023
        rom[5] = 32'h0041A023;
        // beq x3, x4, 8   -> 0x00218463
        rom[6] = 32'h00218463;
        
        // Fill rest with NOP (add x0, x0, x0)
        rom[7] = 32'h00000033;
        rom[8] = 32'h00000033;
        rom[9] = 32'h00000033;
        rom[10] = 32'h00000033;
        rom[11] = 32'h00000033;
        rom[12] = 32'h00000033;
        rom[13] = 32'h00000033;
        rom[14] = 32'h00000033;
        rom[15] = 32'h00000033;
    end

    // Read instruction - word aligned
    assign instruction = rom[addr[31:2]];

endmodule