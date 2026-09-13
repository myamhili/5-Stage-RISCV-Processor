// Instruction Decoder & Control Unit

module control_unit (
    input  wire [31:0] instruction,
    output reg  [6:0]  opcode,
    output reg  [2:0]  funct3,
    output reg  [6:0]  funct7,
    output reg  [4:0]  rd,
    output reg  [4:0]  rs1,
    output reg  [4:0]  rs2,
    output reg  [31:0] imm,

    output reg         valid_instruction,
    output reg         illegal_instruction,
    output reg         uses_rs1,
    output reg         uses_rs2,

    output reg         reg_write,
    output reg         mem_read,
    output reg         mem_write,
    output reg         jump,
    output reg         jump_register,
    output reg         fence_i,
    output reg         ecall,
    output reg         ebreak,
    output reg         mret,
    output reg         csr_enable,
    output reg         csr_use_imm,
    output reg  [1:0]  csr_command,
    output reg  [11:0] csr_address,
    output reg  [4:0]  csr_zimm,
    output reg  [2:0]  branch_op,
    output reg         alu_a_src,
    output reg  [1:0]  alu_b_src,
    output reg  [1:0]  writeback_src,
    output reg  [3:0]  alu_op
);

    // RISC-V opcodes
    localparam OP_LOAD   = 7'b0000011;
    localparam OP_IALU   = 7'b0010011;
    localparam OP_MISC_MEM = 7'b0001111;
    localparam OP_AUIPC  = 7'b0010111;
    localparam OP_STORE  = 7'b0100011;
    localparam OP_RTYPE  = 7'b0110011;
    localparam OP_LUI    = 7'b0110111;
    localparam OP_BRANCH = 7'b1100011;
    localparam OP_JALR   = 7'b1100111;
    localparam OP_JAL    = 7'b1101111;
    localparam OP_SYSTEM = 7'b1110011;

    // ALU operations
    localparam ALU_ADD    = 4'b0000;
    localparam ALU_SUB    = 4'b0001;
    localparam ALU_AND    = 4'b0010;
    localparam ALU_OR     = 4'b0011;
    localparam ALU_XOR    = 4'b0100;
    localparam ALU_PASS_B = 4'b0110;
    localparam ALU_SLT    = 4'b0111;
    localparam ALU_SLTU   = 4'b1000;
    localparam ALU_SLL    = 4'b1001;
    localparam ALU_SRL    = 4'b1010;
    localparam ALU_SRA    = 4'b1011;

    // Operand and writeback selections
    localparam ALU_A_RS1 = 1'b0;
    localparam ALU_A_PC  = 1'b1;
    localparam ALU_B_RS2 = 2'b00;
    localparam ALU_B_IMM = 2'b01;

    localparam WB_ALU = 2'b00;
    localparam WB_MEM = 2'b01;
    localparam WB_PC4 = 2'b10;
    localparam WB_CSR = 2'b11;

    localparam CSR_NONE  = 2'b00;
    localparam CSR_WRITE = 2'b01;
    localparam CSR_SET   = 2'b10;
    localparam CSR_CLEAR = 2'b11;

    localparam BR_NONE = 3'b000;
    localparam BR_EQ   = 3'b001;
    localparam BR_NE   = 3'b010;
    localparam BR_LT   = 3'b011;
    localparam BR_GE   = 3'b100;
    localparam BR_LTU  = 3'b101;
    localparam BR_GEU  = 3'b110;

    always @(*) begin
        opcode = instruction[6:0];
        rd      = instruction[11:7];
        funct3  = instruction[14:12];
        rs1     = instruction[19:15];
        rs2     = instruction[24:20];
        funct7  = instruction[31:25];

        // Safe defaults: an unrecognized encoding has no side effects.
        valid_instruction   = 1'b0;
        illegal_instruction = 1'b1;
        uses_rs1            = 1'b0;
        uses_rs2            = 1'b0;
        reg_write           = 1'b0;
        mem_read            = 1'b0;
        mem_write           = 1'b0;
        jump                = 1'b0;
        jump_register       = 1'b0;
        fence_i             = 1'b0;
        ecall               = 1'b0;
        ebreak              = 1'b0;
        mret                = 1'b0;
        csr_enable          = 1'b0;
        csr_use_imm         = 1'b0;
        csr_command         = CSR_NONE;
        csr_address         = instruction[31:20];
        csr_zimm            = instruction[19:15];
        branch_op           = BR_NONE;
        alu_a_src            = ALU_A_RS1;
        alu_b_src            = ALU_B_RS2;
        writeback_src        = WB_ALU;
        alu_op               = ALU_ADD;
        imm                  = 32'h0000_0000;

        case (opcode)
            OP_RTYPE: begin
                uses_rs1 = 1'b1;
                uses_rs2 = 1'b1;

                case (funct3)
                    3'b000: begin
                        if (funct7 == 7'b0000000) begin
                            valid_instruction = 1'b1;
                            alu_op = ALU_ADD;
                        end else if (funct7 == 7'b0100000) begin
                            valid_instruction = 1'b1;
                            alu_op = ALU_SUB;
                        end
                    end
                    3'b001: begin
                        if (funct7 == 7'b0000000) begin
                            valid_instruction = 1'b1;
                            alu_op = ALU_SLL;
                        end
                    end
                    3'b010: begin
                        if (funct7 == 7'b0000000) begin
                            valid_instruction = 1'b1;
                            alu_op = ALU_SLT;
                        end
                    end
                    3'b011: begin
                        if (funct7 == 7'b0000000) begin
                            valid_instruction = 1'b1;
                            alu_op = ALU_SLTU;
                        end
                    end
                    3'b111: begin
                        if (funct7 == 7'b0000000) begin
                            valid_instruction = 1'b1;
                            alu_op = ALU_AND;
                        end
                    end
                    3'b110: begin
                        if (funct7 == 7'b0000000) begin
                            valid_instruction = 1'b1;
                            alu_op = ALU_OR;
                        end
                    end
                    3'b100: begin
                        if (funct7 == 7'b0000000) begin
                            valid_instruction = 1'b1;
                            alu_op = ALU_XOR;
                        end
                    end
                    3'b101: begin
                        if (funct7 == 7'b0000000) begin
                            valid_instruction = 1'b1;
                            alu_op = ALU_SRL;
                        end else if (funct7 == 7'b0100000) begin
                            valid_instruction = 1'b1;
                            alu_op = ALU_SRA;
                        end
                    end
                    default: begin
                    end
                endcase

                if (valid_instruction) begin
                    illegal_instruction = 1'b0;
                    reg_write = 1'b1;
                    alu_a_src = ALU_A_RS1;
                    alu_b_src = ALU_B_RS2;
                    writeback_src = WB_ALU;
                end
            end

            OP_IALU: begin
                uses_rs1 = 1'b1;
                imm = {{20{instruction[31]}}, instruction[31:20]};

                case (funct3)
                    3'b000: begin
                        valid_instruction = 1'b1;
                        alu_op = ALU_ADD;
                    end
                    3'b001: begin
                        if (funct7 == 7'b0000000) begin
                            valid_instruction = 1'b1;
                            alu_op = ALU_SLL;
                        end
                    end
                    3'b010: begin
                        valid_instruction = 1'b1;
                        alu_op = ALU_SLT;
                    end
                    3'b011: begin
                        valid_instruction = 1'b1;
                        alu_op = ALU_SLTU;
                    end
                    3'b111: begin
                        valid_instruction = 1'b1;
                        alu_op = ALU_AND;
                    end
                    3'b110: begin
                        valid_instruction = 1'b1;
                        alu_op = ALU_OR;
                    end
                    3'b100: begin
                        valid_instruction = 1'b1;
                        alu_op = ALU_XOR;
                    end
                    3'b101: begin
                        if (funct7 == 7'b0000000) begin
                            valid_instruction = 1'b1;
                            alu_op = ALU_SRL;
                        end else if (funct7 == 7'b0100000) begin
                            valid_instruction = 1'b1;
                            alu_op = ALU_SRA;
                        end
                    end
                    default: begin
                    end
                endcase

                if (valid_instruction) begin
                    illegal_instruction = 1'b0;
                    reg_write = 1'b1;
                    alu_a_src = ALU_A_RS1;
                    alu_b_src = ALU_B_IMM;
                    writeback_src = WB_ALU;
                end
            end

            OP_LOAD: begin
                uses_rs1 = 1'b1;
                imm = {{20{instruction[31]}}, instruction[31:20]};

                case (funct3)
                    3'b000, // LB
                    3'b001, // LH
                    3'b010, // LW
                    3'b100, // LBU
                    3'b101: begin // LHU
                        valid_instruction   = 1'b1;
                        illegal_instruction = 1'b0;
                        reg_write           = 1'b1;
                        mem_read            = 1'b1;
                        alu_a_src            = ALU_A_RS1;
                        alu_b_src            = ALU_B_IMM;
                        writeback_src        = WB_MEM;
                        alu_op               = ALU_ADD;
                    end
                    default: begin
                    end
                endcase
            end

            OP_STORE: begin
                uses_rs1 = 1'b1;
                uses_rs2 = 1'b1;
                imm = {{20{instruction[31]}}, instruction[31:25],
                       instruction[11:7]};

                case (funct3)
                    3'b000, // SB
                    3'b001, // SH
                    3'b010: begin // SW
                        valid_instruction   = 1'b1;
                        illegal_instruction = 1'b0;
                        mem_write           = 1'b1;
                        alu_a_src            = ALU_A_RS1;
                        alu_b_src            = ALU_B_IMM;
                        alu_op               = ALU_ADD;
                    end
                    default: begin
                    end
                endcase
            end

            OP_BRANCH: begin
                uses_rs1 = 1'b1;
                uses_rs2 = 1'b1;
                imm = {{19{instruction[31]}}, instruction[31], instruction[7],
                       instruction[30:25], instruction[11:8], 1'b0};

                case (funct3)
                    3'b000: branch_op = BR_EQ;
                    3'b001: branch_op = BR_NE;
                    3'b100: branch_op = BR_LT;
                    3'b101: branch_op = BR_GE;
                    3'b110: branch_op = BR_LTU;
                    3'b111: branch_op = BR_GEU;
                    default: branch_op = BR_NONE;
                endcase

                if (branch_op != BR_NONE) begin
                    valid_instruction   = 1'b1;
                    illegal_instruction = 1'b0;
                    alu_a_src            = ALU_A_RS1;
                    alu_b_src            = ALU_B_RS2;
                    alu_op               = ALU_SUB;
                end
            end

            OP_LUI: begin
                valid_instruction   = 1'b1;
                illegal_instruction = 1'b0;
                reg_write           = 1'b1;
                alu_a_src            = ALU_A_RS1;
                alu_b_src            = ALU_B_IMM;
                writeback_src        = WB_ALU;
                alu_op               = ALU_PASS_B;
                imm                  = {instruction[31:12], 12'b0};
            end

            OP_AUIPC: begin
                valid_instruction   = 1'b1;
                illegal_instruction = 1'b0;
                reg_write           = 1'b1;
                alu_a_src            = ALU_A_PC;
                alu_b_src            = ALU_B_IMM;
                writeback_src        = WB_ALU;
                alu_op               = ALU_ADD;
                imm                  = {instruction[31:12], 12'b0};
            end

            OP_JAL: begin
                valid_instruction   = 1'b1;
                illegal_instruction = 1'b0;
                reg_write           = 1'b1;
                jump                = 1'b1;
                writeback_src        = WB_PC4;
                imm = {{11{instruction[31]}}, instruction[31],
                       instruction[19:12], instruction[20],
                       instruction[30:21], 1'b0};
            end

            OP_JALR: begin
                uses_rs1 = 1'b1;
                imm = {{20{instruction[31]}}, instruction[31:20]};

                if (funct3 == 3'b000) begin
                    valid_instruction   = 1'b1;
                    illegal_instruction = 1'b0;
                    reg_write           = 1'b1;
                    jump                = 1'b1;
                    jump_register       = 1'b1;
                    writeback_src        = WB_PC4;
                end
            end

            OP_MISC_MEM: begin
                if (funct3 == 3'b000) begin
                    // With the current single-hart, strongly ordered memory,
                    // FENCE has no additional hardware effect.
                    valid_instruction   = 1'b1;
                    illegal_instruction = 1'b0;
                end else if ((funct3 == 3'b001) &&
                             (instruction[31:20] == 12'b0) &&
                             (rs1 == 5'b0) && (rd == 5'b0)) begin
                    valid_instruction   = 1'b1;
                    illegal_instruction = 1'b0;
                    fence_i             = 1'b1;
                end
            end

            OP_SYSTEM: begin
                if (instruction == 32'h0000_0073) begin
                    valid_instruction   = 1'b1;
                    illegal_instruction = 1'b0;
                    ecall               = 1'b1;
                end else if (instruction == 32'h0010_0073) begin
                    valid_instruction   = 1'b1;
                    illegal_instruction = 1'b0;
                    ebreak              = 1'b1;
                end else if (instruction == 32'h3020_0073) begin
                    valid_instruction   = 1'b1;
                    illegal_instruction = 1'b0;
                    mret                = 1'b1;
                end else begin
                    case (funct3)
                        3'b001, 3'b101: csr_command = CSR_WRITE;
                        3'b010, 3'b110: csr_command = CSR_SET;
                        3'b011, 3'b111: csr_command = CSR_CLEAR;
                        default: csr_command = CSR_NONE;
                    endcase

                    if (csr_command != CSR_NONE) begin
                        valid_instruction   = 1'b1;
                        illegal_instruction = 1'b0;
                        csr_enable          = 1'b1;
                        csr_use_imm         = funct3[2];
                        uses_rs1            = !funct3[2];
                        reg_write           = 1'b1;
                        writeback_src        = WB_CSR;
                    end
                end
            end

            default: begin
            end
        endcase
    end

endmodule
