// Top-level Single-Cycle RISC-V Processor

module risc_processor (
    input  wire        clk,
    input  wire        rst,
    output wire [31:0] pc_out,
    output wire [31:0] instruction_out,
    output wire [31:0] alu_result_out,
    output wire [31:0] mem_read_data_out
);

    // Internal wires
    wire [31:0] instruction;
    wire [31:0] pc_next;
    wire [31:0] branch_addr;
    
    // Control signals
    wire [6:0]  opcode;
    wire [2:0]  funct3;
    wire [6:0]  funct7;
    wire [4:0]  rd, rs1, rs2;
    wire [31:0] imm;
    wire        reg_write, mem_read, mem_write, branch;
    wire [1:0]  alu_src;
    wire [3:0]  alu_op;
    
    // Register file signals
    wire [31:0] reg_read_data1, reg_read_data2;
    wire [31:0] reg_write_data;
    
    // ALU signals
    wire [31:0] alu_a, alu_b, alu_result;
    wire        alu_zero;
    
    // Data memory signals
    wire [31:0] mem_read_data;

    // ===== INSTANTIATION =====

    // Program Counter
    pc pc_inst (
        .clk          (clk),
        .rst          (rst),
        .branch       (branch & alu_zero),  // Branch only if zero flag is set
        .branch_addr  (pc_out + imm),       // PC-relative branch
        .pc_out       (pc_out)
    );

    // Instruction Memory
    instruction_memory imem (
        .addr         (pc_out),
        .instruction  (instruction)
    );

    // Control Unit / Instruction Decoder
    control_unit ctrl (
        .instruction  (instruction),
        .opcode       (opcode),
        .funct3       (funct3),
        .funct7       (funct7),
        .rd           (rd),
        .rs1          (rs1),
        .rs2          (rs2),
        .imm          (imm),
        .reg_write    (reg_write),
        .mem_read     (mem_read),
        .mem_write    (mem_write),
        .branch       (branch),
        .alu_src      (alu_src),
        .alu_op       (alu_op)
    );

    // Register File
    register_file regfile (
        .clk          (clk),
        .rst          (rst),
        .we           (reg_write),
        .read_addr1   (rs1),
        .read_addr2   (rs2),
        .write_addr   (rd),
        .write_data   (reg_write_data),
        .read_data1   (reg_read_data1),
        .read_data2   (reg_read_data2)
    );

    // ALU input selection
    assign alu_a = reg_read_data1;
    assign alu_b = (alu_src == 2'b00) ? reg_read_data2 :  // Use register
                   (alu_src == 2'b01) ? imm :              // Use immediate
                   pc_out;                                  // Use PC (for AUIPC)

    // ALU
    alu alu_inst (
        .a            (alu_a),
        .b            (alu_b),
        .op           (alu_op),
        .result       (alu_result),
        .zero         (alu_zero)
    );

    // Data Memory
    data_memory dmem (
        .clk          (clk),
        .rst          (rst),
        .we           (mem_write),
        .re           (mem_read),
        .addr         (alu_result),
        .write_data   (reg_read_data2),
        .read_data    (mem_read_data)
    );

    // Write-back: Select data to write to register
    // Either from ALU result or from memory (for lw)
    assign reg_write_data = mem_read ? mem_read_data : alu_result;

    // Output for monitoring
    assign instruction_out = instruction;
    assign alu_result_out = alu_result;
    assign mem_read_data_out = mem_read_data;

endmodule