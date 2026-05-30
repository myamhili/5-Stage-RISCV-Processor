// Instruction Decoder & Control Unit

module control_unit (
    input  wire [31:0] instruction,
    output reg  [6:0]  opcode,
    output reg  [2:0]  funct3,
    output reg  [6:0]  funct7,
    output reg  [4:0]  rd,         // Destination register
    output reg  [4:0]  rs1,        // Source register 1
    output reg  [4:0]  rs2,        // Source register 2
    output reg  [31:0] imm,        // Immediate value (sign-extended)
    
    // Control signals
    output reg         reg_write,  // Enable register write
    output reg         mem_read,   // Enable memory read
    output reg         mem_write,  // Enable memory write
    output reg         branch,     // Branch enable
    output reg  [1:0]  alu_src,    // ALU source: 00=reg, 01=imm, 10=pc
    output reg  [3:0]  alu_op      // ALU operation
);

    // RISC-V opcodes
    localparam OP_RTYPE = 7'b0110011;  // R-type (add, sub, and, or)
    localparam OP_ITYPE = 7'b0000011;  // I-type (lw)
    localparam OP_IALU  = 7'b0010011;  // I-type ALU (addi, etc.)
    localparam OP_STYPE = 7'b0100011;  // S-type (sw)
    localparam OP_BTYPE = 7'b1100011;  // B-type (beq)

    // Extract instruction fields
    always @(*) begin
        opcode = instruction[6:0];
        rd     = instruction[11:7];
        funct3 = instruction[14:12];
        rs1    = instruction[19:15];
        rs2    = instruction[24:20];
        funct7 = instruction[31:25];
        
        // Default control signals
        reg_write = 1'b0;
        mem_read  = 1'b0;
        mem_write = 1'b0;
        branch    = 1'b0;
        alu_src   = 2'b00;
        alu_op    = 4'b0000;
        imm       = 32'h0;

        case (opcode)
            OP_RTYPE: begin  // R-type: add, sub, and, or
                reg_write = 1'b1;
                alu_src   = 2'b00;
                
                case (funct3)
                    3'b000: begin  // add or sub
                        if (funct7[5])  // sub (bit 5 of funct7)
                            alu_op = 4'b0001;  // SUB
                        else
                            alu_op = 4'b0000;  // ADD
                    end
                    3'b111: alu_op = 4'b0010;  // AND
                    3'b110: alu_op = 4'b0011;  // OR
                    3'b100: alu_op = 4'b0100;  // XOR
                    default: alu_op = 4'b0000;
                endcase
            end
            
            OP_IALU: begin  // I-type ALU: addi, etc.
                reg_write = 1'b1;
                alu_src   = 2'b01;  // Use immediate
                
                case (funct3)
                    3'b000: alu_op = 4'b0000;  // ADDI (ADD operation)
                    3'b111: alu_op = 4'b0010;  // ANDI
                    3'b110: alu_op = 4'b0011;  // ORI
                    3'b100: alu_op = 4'b0100;  // XORI
                    default: alu_op = 4'b0000;
                endcase
                
                // Sign-extend immediate (12-bit)
                imm = {{20{instruction[31]}}, instruction[31:20]};
            end
            
            OP_ITYPE: begin  // I-type: lw
                reg_write = 1'b1;
                mem_read  = 1'b1;
                alu_src   = 2'b01;  // Use immediate
                alu_op    = 4'b0000;  // ADD for address calculation
                
                // Sign-extend immediate (12-bit)
                imm = {{20{instruction[31]}}, instruction[31:20]};
            end
            
            OP_STYPE: begin  // S-type: sw
                mem_write = 1'b1;
                alu_src   = 2'b01;  // Use immediate
                alu_op    = 4'b0000;  // ADD for address calculation
                
                // Sign-extend immediate (12-bit)
                imm = {{20{instruction[31]}}, instruction[31:25], instruction[11:7]};
            end
            
            OP_BTYPE: begin  // B-type: beq
                branch = 1'b1;
                alu_src = 2'b00;
                alu_op  = 4'b0101;  // SUB for comparison
                
                // Sign-extend immediate (13-bit, word-aligned)
                imm = {{19{instruction[31]}}, instruction[31], instruction[7], 
                       instruction[30:25], instruction[11:8], 1'b0};
            end
            
            default: begin
                // NOP or unknown - all signals default
            end
        endcase
    end

endmodule