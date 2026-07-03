// Top-level 5-Stage Pipelined RISC-V Processor

module risc_processor (
    input  wire        clk,
    input  wire        rst,
    output wire [31:0] pc_out,
    output wire [31:0] instruction_out,
    output wire [31:0] alu_result_out,
    output wire [31:0] mem_read_data_out,
    output wire [31:0] led_out
);

    // =========================================================
    // Forward Declarations & Hazard Signals
    // =========================================================
    wire        load_use_hazard;
    wire        pc_branch;
    wire [31:0] branch_target;

    wire        pc_en = ~load_use_hazard;
    wire        if_id_en = ~load_use_hazard;
    wire        flush_if_id = pc_branch;
    
    wire        flush_id_ex = load_use_hazard;
    wire        flush_id_ex_branch = pc_branch;

    // =========================================================
    // Stage 1: Instruction Fetch (IF)
    // =========================================================
    wire [31:0] if_pc;
    wire [31:0] if_instruction;

    pc pc_inst (
        .clk          (clk),
        .rst          (rst),
        .en           (pc_en),
        .branch       (pc_branch),
        .branch_addr  (branch_target),
        .pc_out       (if_pc)
    );

    instruction_memory imem (
        .addr         (if_pc),
        .instruction  (if_instruction)
    );

    // IF/ID Pipeline Register
    reg [31:0] if_id_pc;
    reg [31:0] if_id_instruction;

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            if_id_pc          <= 32'h0;
            if_id_instruction <= 32'h00000033; // NOP (add x0, x0, x0)
        end else if (if_id_en) begin
            if_id_pc          <= flush_if_id ? 32'h0 : if_pc;
            if_id_instruction <= flush_if_id ? 32'h00000033 : if_instruction; // NOP on branch flush
        end
    end

    // =========================================================
    // Stage 2: Instruction Decode (ID)
    // =========================================================
    wire [6:0]  id_opcode;
    wire [2:0]  id_funct3;
    wire [6:0]  id_funct7;
    wire [4:0]  id_rd;
    wire [4:0]  id_rs1;
    wire [4:0]  id_rs2;
    wire [31:0] id_imm;
    
    wire        id_reg_write;
    wire        id_mem_read;
    wire        id_mem_write;
    wire        id_branch;
    wire [1:0]  id_alu_src;
    wire [3:0]  id_alu_op;

    wire [31:0] id_reg_read_data1;
    wire [31:0] id_reg_read_data2;

    control_unit ctrl (
        .instruction  (if_id_instruction),
        .opcode       (id_opcode),
        .funct3       (id_funct3),
        .funct7       (id_funct7),
        .rd           (id_rd),
        .rs1          (id_rs1),
        .rs2          (id_rs2),
        .imm          (id_imm),
        .reg_write    (id_reg_write),
        .mem_read     (id_mem_read),
        .mem_write    (id_mem_write),
        .branch       (id_branch),
        .alu_src      (id_alu_src),
        .alu_op       (id_alu_op)
    );

    // Write-back data declaration (from WB stage)
    wire [31:0] wb_reg_write_data;
    
    // MEM/WB registers declared early for register file wiring
    reg [4:0]  mem_wb_rd;
    reg        mem_wb_reg_write;

    register_file regfile (
        .clk          (clk),
        .rst          (rst),
        .we           (mem_wb_reg_write),
        .read_addr1   (id_rs1),
        .read_addr2   (id_rs2),
        .write_addr   (mem_wb_rd),
        .write_data   (wb_reg_write_data),
        .read_data1   (id_reg_read_data1),
        .read_data2   (id_reg_read_data2)
    );

    // ID/EX Pipeline Register
    reg [31:0] id_ex_pc;
    reg [31:0] id_ex_reg_read_data1;
    reg [31:0] id_ex_reg_read_data2;
    reg [31:0] id_ex_imm;
    reg [4:0]  id_ex_rs1;
    reg [4:0]  id_ex_rs2;
    reg [4:0]  id_ex_rd;
    reg        id_ex_reg_write;
    reg        id_ex_mem_read;
    reg        id_ex_mem_write;
    reg        id_ex_branch;
    reg [1:0]  id_ex_alu_src;
    reg [3:0]  id_ex_alu_op;

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            id_ex_pc             <= 32'h0;
            id_ex_reg_read_data1 <= 32'h0;
            id_ex_reg_read_data2 <= 32'h0;
            id_ex_imm            <= 32'h0;
            id_ex_rs1            <= 5'h0;
            id_ex_rs2            <= 5'h0;
            id_ex_rd             <= 5'h0;
            id_ex_reg_write      <= 1'b0;
            id_ex_mem_read       <= 1'b0;
            id_ex_mem_write      <= 1'b0;
            id_ex_branch         <= 1'b0;
            id_ex_alu_src        <= 2'b00;
            id_ex_alu_op         <= 4'b0000;
        end else if (flush_id_ex || flush_id_ex_branch) begin
            id_ex_reg_write      <= 1'b0;
            id_ex_mem_read       <= 1'b0;
            id_ex_mem_write      <= 1'b0;
            id_ex_branch         <= 1'b0;
            id_ex_alu_src        <= 2'b00;
            id_ex_alu_op         <= 4'b0000;
        end else begin
            id_ex_pc             <= if_id_pc;
            id_ex_reg_read_data1 <= id_reg_read_data1;
            id_ex_reg_read_data2 <= id_reg_read_data2;
            id_ex_imm            <= id_imm;
            id_ex_rs1            <= id_rs1;
            id_ex_rs2            <= id_rs2;
            id_ex_rd             <= id_rd;
            id_ex_reg_write      <= id_reg_write;
            id_ex_mem_read       <= id_mem_read;
            id_ex_mem_write      <= id_mem_write;
            id_ex_branch         <= id_branch;
            id_ex_alu_src        <= id_alu_src;
            id_ex_alu_op         <= id_alu_op;
        end
    end

    // Load-Use Hazard Detection
    wire id_uses_rs2 = (id_opcode == 7'b0110011) || (id_opcode == 7'b0100011) || (id_opcode == 7'b1100011); // R-type, S-type, B-type
    assign load_use_hazard = id_ex_mem_read && 
                             (id_ex_rd != 5'h0) &&
                             ((id_ex_rd == id_rs1) || (id_uses_rs2 && (id_ex_rd == id_rs2)));

    // =========================================================
    // Stage 3: Execute (EX)
    // =========================================================
    wire [31:0] ex_alu_a;
    wire [31:0] ex_alu_b;
    wire [31:0] ex_forwarded_b;
    wire [31:0] ex_alu_result;
    wire        ex_alu_zero;
    
    // EX/MEM Register definitions (needed for forwarding)
    reg [31:0] ex_mem_alu_result;
    reg [4:0]  ex_mem_rd;
    reg        ex_mem_reg_write;

    // Forwarding Unit logic
    reg [1:0] forward_a;
    reg [1:0] forward_b;

    always @(*) begin
        // Forward A
        if (ex_mem_reg_write && (ex_mem_rd != 0) && (ex_mem_rd == id_ex_rs1))
            forward_a = 2'b10;
        else if (mem_wb_reg_write && (mem_wb_rd != 0) && (mem_wb_rd == id_ex_rs1))
            forward_a = 2'b01;
        else
            forward_a = 2'b00;

        // Forward B
        if (ex_mem_reg_write && (ex_mem_rd != 0) && (ex_mem_rd == id_ex_rs2))
            forward_b = 2'b10;
        else if (mem_wb_reg_write && (mem_wb_rd != 0) && (mem_wb_rd == id_ex_rs2))
            forward_b = 2'b01;
        else
            forward_b = 2'b00;
    end

    // Apply forwarding
    assign ex_alu_a = (forward_a == 2'b10) ? ex_mem_alu_result :
                      (forward_a == 2'b01) ? wb_reg_write_data :
                      id_ex_reg_read_data1;

    assign ex_forwarded_b = (forward_b == 2'b10) ? ex_mem_alu_result :
                            (forward_b == 2'b01) ? wb_reg_write_data :
                            id_ex_reg_read_data2;

    // ALU input B selection
    assign ex_alu_b = (id_ex_alu_src == 2'b00) ? ex_forwarded_b :
                      (id_ex_alu_src == 2'b01) ? id_ex_imm :
                      id_ex_pc;

    alu alu_inst (
        .a            (ex_alu_a),
        .b            (ex_alu_b),
        .op           (id_ex_alu_op),
        .result       (ex_alu_result),
        .zero         (ex_alu_zero)
    );

    // Branch Resolution
    assign pc_branch = id_ex_branch & ex_alu_zero;
    assign branch_target = id_ex_pc + id_ex_imm;

    // EX/MEM Pipeline Register
    reg [31:0] ex_mem_write_data;
    reg        ex_mem_mem_read;
    reg        ex_mem_mem_write;

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            ex_mem_alu_result  <= 32'h0;
            ex_mem_write_data  <= 32'h0;
            ex_mem_rd          <= 5'h0;
            ex_mem_reg_write   <= 1'b0;
            ex_mem_mem_read    <= 1'b0;
            ex_mem_mem_write   <= 1'b0;
        end else begin
            ex_mem_alu_result  <= ex_alu_result;
            ex_mem_write_data  <= ex_forwarded_b; // Data to be written to memory
            ex_mem_rd          <= id_ex_rd;
            ex_mem_reg_write   <= id_ex_reg_write;
            ex_mem_mem_read    <= id_ex_mem_read;
            ex_mem_mem_write   <= id_ex_mem_write;
        end
    end

    // =========================================================
    // Stage 4: Memory (MEM)
    // =========================================================
    wire [31:0] mem_read_data;

    data_memory dmem (
        .clk          (clk),
        .rst          (rst),
        .we           (ex_mem_mem_write),
        .re           (ex_mem_mem_read),
        .addr         (ex_mem_alu_result),
        .write_data   (ex_mem_write_data),
        .read_data    (mem_read_data),
        .led_out      (led_out)
    );

    // MEM/WB Pipeline Register
    reg [31:0] mem_wb_read_data;
    reg [31:0] mem_wb_alu_result;
    reg        mem_wb_mem_read;

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            mem_wb_read_data  <= 32'h0;
            mem_wb_alu_result <= 32'h0;
            mem_wb_rd         <= 5'h0;
            mem_wb_reg_write  <= 1'b0;
            mem_wb_mem_read   <= 1'b0;
        end else begin
            mem_wb_read_data  <= mem_read_data;
            mem_wb_alu_result <= ex_mem_alu_result;
            mem_wb_rd         <= ex_mem_rd;
            mem_wb_reg_write  <= ex_mem_reg_write;
            mem_wb_mem_read   <= ex_mem_mem_read;
        end
    end

    // =========================================================
    // Stage 5: Write-Back (WB)
    // =========================================================
    assign wb_reg_write_data = mem_wb_mem_read ? mem_wb_read_data : mem_wb_alu_result;

    // =========================================================
    // Output Monitoring
    // =========================================================
    assign pc_out = if_pc;
    assign instruction_out = if_instruction;
    assign alu_result_out = ex_alu_result;
    assign mem_read_data_out = mem_read_data;

endmodule
