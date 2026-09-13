// Top-level 5-Stage Pipelined RISC-V Processor

module risc_core #(parameter RESET_VECTOR = 32'h0000_0000) (
    input  wire        clk,
    input  wire        rst,
    input  wire        irq_software,
    input  wire        irq_timer,
    input  wire        irq_external,
    output wire [31:0] pc_out,
    output wire [31:0] instruction_out,
    output wire [31:0] alu_result_out,
    output wire [31:0] mem_read_data_out,
    output wire        imem_req_valid,
    input  wire        imem_req_ready,
    output wire [31:0] imem_req_addr,
    input  wire        imem_rsp_valid,
    output wire        imem_rsp_ready,
    input  wire [31:0] imem_rsp_data,
    input  wire        imem_rsp_error,
    output wire        dmem_req_valid,
    input  wire        dmem_req_ready,
    output wire        dmem_req_write,
    output wire [31:0] dmem_req_addr,
    output wire [31:0] dmem_req_wdata,
    output wire [3:0]  dmem_req_wstrb,
    input  wire        dmem_rsp_valid,
    output wire        dmem_rsp_ready,
    input  wire [31:0] dmem_rsp_rdata,
    input  wire        dmem_rsp_error,

    output wire        retire_valid,
    output wire [31:0] retire_pc,
    output wire [31:0] retire_instruction,

    output wire        retire_rd_we,
    output wire [4:0]  retire_rd_addr,
    output wire [31:0] retire_rd_data,

    output wire        retire_mem_valid,
    output wire        retire_mem_write,
    output wire [31:0] retire_mem_addr,
    output wire [31:0] retire_mem_wdata,
    output wire [3:0]  retire_mem_wstrb,

    output wire        trap_valid,
    output wire [31:0] trap_pc,
    output wire [31:0] trap_instruction,
    output wire [31:0] trap_cause,
    output wire [31:0] trap_tval
);

    // =========================================================
    // Forward Declarations & Hazard Signals
    // =========================================================
    wire        load_use_hazard;
    wire        csr_hazard;
    wire        decode_stall;
    wire        pc_redirect;
    wire [31:0] redirect_target;
    wire        ex_exception_valid;
    wire        trap_inflight;
    wire        wb_trap;
    wire        interrupt_trap;
    wire        trap_take;
    wire        interrupt_request;
    wire [31:0] interrupt_cause;

    // Pipeline declarations are kept ahead of all combinational users.  This
    // avoids tool-dependent implicit-net behavior in strict Verilog flows.
    wire [31:0] ex_forwarded_a;
    wire [31:0] ex_forwarded_b;

    reg        ex_mem_valid;
    reg [31:0] ex_mem_pc;
    reg [31:0] ex_mem_instruction;
    reg [31:0] ex_mem_alu_result;
    reg [31:0] ex_mem_pc_plus_four;
    reg [31:0] ex_mem_write_data;
    reg [4:0]  ex_mem_rd;
    reg        ex_mem_reg_write;
    reg [1:0]  ex_mem_writeback_src;
    reg [2:0]  ex_mem_mem_funct3;
    reg [3:0]  ex_mem_mem_strobe;
    reg        ex_mem_mem_read;
    reg        ex_mem_mem_write;
    reg [31:0] ex_mem_csr_read_data;
    reg        ex_mem_csr_write_enable;
    reg [11:0] ex_mem_csr_address;
    reg [31:0] ex_mem_csr_write_data;
    reg        ex_mem_mret;
    reg        ex_mem_redirect_valid;
    reg [31:0] ex_mem_redirect_target;
    reg        ex_mem_exception_valid;
    reg [31:0] ex_mem_exception_cause;
    reg [31:0] ex_mem_exception_tval;
    reg [31:0] ex_mem_next_pc;

    reg        mem_wb_valid;
    reg [31:0] mem_wb_pc;
    reg [31:0] mem_wb_instruction;
    reg [31:0] mem_wb_read_data;
    reg [31:0] mem_wb_alu_result;
    reg [31:0] mem_wb_pc_plus_four;
    reg [4:0]  mem_wb_rd;
    reg        mem_wb_reg_write;
    reg        mem_wb_mem_read;
    reg [1:0]  mem_wb_writeback_src;
    reg        mem_wb_mem_write;
    reg [31:0] mem_wb_mem_data;
    reg [3:0]  mem_wb_mem_strobe;
    reg [31:0] mem_wb_csr_read_data;
    reg        mem_wb_csr_write_enable;
    reg [11:0] mem_wb_csr_address;
    reg [31:0] mem_wb_csr_write_data;
    reg        mem_wb_mret;
    reg        mem_wb_exception_valid;
    reg [31:0] mem_wb_exception_cause;
    reg [31:0] mem_wb_exception_tval;
    reg [31:0] mem_wb_next_pc;
    reg [31:0] architectural_next_pc;

    // Control encodings shared with the decoder.
    localparam ALU_A_RS1 = 1'b0;
    localparam ALU_A_PC  = 1'b1;
    localparam ALU_B_RS2 = 2'b00;
    localparam ALU_B_IMM = 2'b01;
    localparam ALU_B_FOUR = 2'b10;

    localparam WB_ALU = 2'b00;
    localparam WB_MEM = 2'b01;
    localparam WB_PC4 = 2'b10;
    localparam WB_CSR = 2'b11;

    localparam CSR_NONE  = 2'b00;
    localparam CSR_WRITE = 2'b01;
    localparam CSR_SET   = 2'b10;
    localparam CSR_CLEAR = 2'b11;

    localparam CAUSE_INST_MISALIGNED  = 32'd0;
    localparam CAUSE_ILLEGAL_INST     = 32'd2;
    localparam CAUSE_BREAKPOINT       = 32'd3;
    localparam CAUSE_LOAD_MISALIGNED  = 32'd4;
    localparam CAUSE_STORE_MISALIGNED = 32'd6;
    localparam CAUSE_ECALL_M          = 32'd11;

    localparam BR_NONE = 3'b000;
    localparam BR_EQ   = 3'b001;
    localparam BR_NE   = 3'b010;
    localparam BR_LT   = 3'b011;
    localparam BR_GE   = 3'b100;
    localparam BR_LTU  = 3'b101;
    localparam BR_GEU  = 3'b110;

    // A memory instruction occupies MEM through response acceptance. EX resumes
    // on the following cycle, when a completed load is available from WB.
    wire mem_operation = ex_mem_valid && !ex_mem_exception_valid &&
                         (ex_mem_mem_read || ex_mem_mem_write);
    wire mem_hold = mem_operation;
    reg dmem_request_sent;
    wire dmem_done = dmem_rsp_valid && dmem_rsp_ready;
    wire mem_access_fault = dmem_done && dmem_rsp_error;
    wire older_exception = (ex_mem_valid && ex_mem_exception_valid) || wb_trap;
    wire kill_younger = older_exception || mem_access_fault ||
                        ex_mem_redirect_valid || interrupt_trap;
    assign dmem_req_valid = !rst && mem_operation && !dmem_request_sent &&
                            !trap_take;
    assign dmem_req_write = ex_mem_mem_write;
    assign dmem_req_addr = {ex_mem_alu_result[31:2], 2'b00};
    assign dmem_req_wdata = ex_mem_write_data;
    assign dmem_req_wstrb = ex_mem_mem_write ? ex_mem_mem_strobe : 4'b0000;
    assign dmem_rsp_ready = !rst && dmem_request_sent;
    always @(posedge clk) begin
        if (rst)
            dmem_request_sent <= 1'b0;
        else if (dmem_done)
            dmem_request_sent <= 1'b0;
        else if (dmem_req_valid && dmem_req_ready)
            dmem_request_sent <= 1'b1;
    end

    assign decode_stall = load_use_hazard || csr_hazard;
    // EX exceptions are first captured in EX/MEM.  The registered exception
    // then squashes all younger work on the following cycle, before any of it
    // can enter MEM or commit.  This keeps exceptions precise without placing
    // the full EX datapath on the fetch and ID/EX register control inputs.
    wire flush_if_id = pc_redirect || kill_younger;
    wire flush_id_ex = decode_stall;
    wire flush_id_ex_redirect = flush_if_id;
    wire decode_fire = !decode_stall && !mem_hold && !trap_inflight;

    // One transaction at a time, with a reserved IF/ID response slot.
    // A REQUEST cannot be withdrawn on redirect, even before acceptance.
    localparam FETCH_IDLE = 2'd0, FETCH_REQUEST = 2'd1, FETCH_RESPONSE = 2'd2;
    reg [1:0] fetch_state;
    reg [31:0] if_pc;
    reg [31:0] fetch_address;
    reg fetch_discard;
    wire [31:0] if_instruction = imem_rsp_data;
    reg if_id_valid;
    reg [31:0] if_id_pc;
    reg [31:0] if_id_instruction;
    reg if_id_fetch_fault;

    assign imem_req_valid = !rst && fetch_state == FETCH_REQUEST;
    assign imem_req_addr = fetch_address;
    assign imem_rsp_ready = !rst && fetch_state == FETCH_RESPONSE &&
        (fetch_discard || flush_if_id || !if_id_valid || decode_fire);

    always @(posedge clk) begin
        if (rst) begin
            fetch_state <= FETCH_IDLE;
            if_pc <= RESET_VECTOR;
            fetch_address <= RESET_VECTOR;
            fetch_discard <= 1'b0;
            if_id_valid <= 1'b0;
            if_id_pc <= 0;
            if_id_instruction <= 32'h00000013;
            if_id_fetch_fault <= 1'b0;
        end else begin
            if (decode_fire)
                if_id_valid <= 1'b0;
            case (fetch_state)
                FETCH_IDLE: begin
                    if ((!if_id_valid || decode_fire) && !mem_hold &&
                        !trap_inflight && !flush_if_id) begin
                        fetch_address <= if_pc;
                        fetch_discard <= 1'b0;
                        fetch_state <= FETCH_REQUEST;
                        if_pc <= if_pc + 32'd4;
                    end
                end
                FETCH_REQUEST: begin
                    if (imem_req_ready)
                        fetch_state <= FETCH_RESPONSE;
                end
                FETCH_RESPONSE: begin
                    if (imem_rsp_valid && imem_rsp_ready) begin
                        fetch_state <= FETCH_IDLE;
                        fetch_discard <= 1'b0;
                        if (!fetch_discard && !flush_if_id) begin
                            if_id_valid <= 1'b1;
                            if_id_pc <= fetch_address;
                            if_id_instruction <= imem_rsp_error ? 32'h00000013 : imem_rsp_data;
                            if_id_fetch_fault <= imem_rsp_error;
                        end
                    end
                end
                default: fetch_state <= FETCH_IDLE;
            endcase
            if (flush_if_id) begin
                if_id_valid <= 1'b0;
                if (fetch_state != FETCH_IDLE)
                    fetch_discard <= 1'b1;
            end
            if (pc_redirect)
                if_pc <= redirect_target;
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
    wire        id_valid_instruction;
    wire        id_illegal_instruction;
    wire        id_uses_rs1;
    wire        id_uses_rs2;
    wire        id_jump;
    wire        id_jump_register;
    wire        id_fence_i;
    wire        id_ecall;
    wire        id_ebreak;
    wire        id_mret;
    wire        id_csr_enable;
    wire        id_csr_use_imm;
    wire [1:0]  id_csr_command;
    wire [11:0] id_csr_address;
    wire [4:0]  id_csr_zimm;
    wire [2:0]  id_branch_op;
    wire        id_alu_a_src;
    wire [1:0]  id_alu_b_src;
    wire [1:0]  id_writeback_src;
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
        .valid_instruction   (id_valid_instruction),
        .illegal_instruction (id_illegal_instruction),
        .uses_rs1     (id_uses_rs1),
        .uses_rs2     (id_uses_rs2),
        .reg_write    (id_reg_write),
        .mem_read     (id_mem_read),
        .mem_write    (id_mem_write),
        .jump         (id_jump),
        .jump_register(id_jump_register),
        .fence_i      (id_fence_i),
        .ecall        (id_ecall),
        .ebreak       (id_ebreak),
        .mret         (id_mret),
        .csr_enable   (id_csr_enable),
        .csr_use_imm  (id_csr_use_imm),
        .csr_command  (id_csr_command),
        .csr_address  (id_csr_address),
        .csr_zimm     (id_csr_zimm),
        .branch_op    (id_branch_op),
        .alu_a_src    (id_alu_a_src),
        .alu_b_src    (id_alu_b_src),
        .writeback_src(id_writeback_src),
        .alu_op       (id_alu_op)
    );

    // Write-back data declaration (from WB stage)
    wire [31:0] wb_reg_write_data;
    
    register_file regfile (
        .clk          (clk),
        .rst          (rst),
        .we           (mem_wb_valid && mem_wb_reg_write),
        .read_addr1   (id_rs1),
        .read_addr2   (id_rs2),
        .write_addr   (mem_wb_rd),
        .write_data   (wb_reg_write_data),
        .read_data1   (id_reg_read_data1),
        .read_data2   (id_reg_read_data2)
    );

    // ID/EX Pipeline Register
    reg        id_ex_fetch_fault;
    reg        id_ex_valid;
    reg [31:0] id_ex_pc;
    reg [31:0] id_ex_instruction;
    reg [31:0] id_ex_reg_read_data1;
    reg [31:0] id_ex_reg_read_data2;
    reg [31:0] id_ex_imm;
    reg [4:0]  id_ex_rs1;
    reg [4:0]  id_ex_rs2;
    reg [4:0]  id_ex_rd;
    reg        id_ex_reg_write;
    reg        id_ex_mem_read;
    reg        id_ex_mem_write;
    reg [2:0]  id_ex_mem_funct3;
    reg        id_ex_illegal;
    reg        id_ex_jump;
    reg        id_ex_jump_register;
    reg        id_ex_fence_i;
    reg        id_ex_ecall;
    reg        id_ex_ebreak;
    reg        id_ex_mret;
    reg        id_ex_csr_enable;
    reg        id_ex_csr_use_imm;
    reg [1:0]  id_ex_csr_command;
    reg [11:0] id_ex_csr_address;
    reg [4:0]  id_ex_csr_zimm;
    reg [2:0]  id_ex_branch_op;
    reg        id_ex_alu_a_src;
    reg [1:0]  id_ex_alu_b_src;
    reg [1:0]  id_ex_writeback_src;
    reg [3:0]  id_ex_alu_op;

    wire id_ex_flush = flush_id_ex_redirect ||
                       (!mem_hold && (flush_id_ex || trap_inflight));

    // Side-effecting controls are reset and explicitly cleared on a bubble.
    // Keeping this separate from payload storage prevents the forwarding and
    // hazard logic from becoming a clock-enable path for every ID/EX bit.
    always @(posedge clk) begin
        if (rst) begin
            id_ex_fetch_fault    <= 1'b0;
            id_ex_valid          <= 1'b0;
            id_ex_reg_write      <= 1'b0;
            id_ex_mem_read       <= 1'b0;
            id_ex_mem_write      <= 1'b0;
            id_ex_mem_funct3     <= 3'b000;
            id_ex_illegal        <= 1'b0;
            id_ex_jump           <= 1'b0;
            id_ex_jump_register  <= 1'b0;
            id_ex_fence_i        <= 1'b0;
            id_ex_ecall          <= 1'b0;
            id_ex_ebreak         <= 1'b0;
            id_ex_mret           <= 1'b0;
            id_ex_csr_enable     <= 1'b0;
            id_ex_csr_use_imm    <= 1'b0;
            id_ex_csr_command    <= CSR_NONE;
            id_ex_csr_address    <= 12'h000;
            id_ex_csr_zimm       <= 5'h00;
            id_ex_branch_op      <= BR_NONE;
            id_ex_alu_a_src      <= ALU_A_RS1;
            id_ex_alu_b_src      <= ALU_B_RS2;
            id_ex_writeback_src  <= WB_ALU;
            id_ex_alu_op         <= 4'b0000;
        end else if (id_ex_flush) begin
            id_ex_fetch_fault    <= 1'b0;
            id_ex_valid          <= 1'b0;
            id_ex_reg_write      <= 1'b0;
            id_ex_mem_read       <= 1'b0;
            id_ex_mem_write      <= 1'b0;
            id_ex_mem_funct3     <= 3'b000;
            id_ex_illegal        <= 1'b0;
            id_ex_jump           <= 1'b0;
            id_ex_jump_register  <= 1'b0;
            id_ex_fence_i        <= 1'b0;
            id_ex_ecall          <= 1'b0;
            id_ex_ebreak         <= 1'b0;
            id_ex_mret           <= 1'b0;
            id_ex_csr_enable     <= 1'b0;
            id_ex_csr_use_imm    <= 1'b0;
            id_ex_csr_command    <= CSR_NONE;
            id_ex_branch_op      <= BR_NONE;
            id_ex_alu_a_src      <= ALU_A_RS1;
            id_ex_alu_b_src      <= ALU_B_RS2;
            id_ex_writeback_src  <= WB_ALU;
            id_ex_alu_op         <= 4'b0000;
        end else if (!mem_hold) begin
            id_ex_fetch_fault <= if_id_fetch_fault;
            id_ex_valid          <= if_id_valid;
            id_ex_reg_write      <= id_reg_write;
            id_ex_mem_read       <= id_mem_read;
            id_ex_mem_write      <= id_mem_write;
            id_ex_mem_funct3     <= id_funct3;
            id_ex_illegal        <= id_illegal_instruction;
            id_ex_jump           <= id_jump;
            id_ex_jump_register  <= id_jump_register;
            id_ex_fence_i        <= id_fence_i;
            id_ex_ecall          <= id_ecall;
            id_ex_ebreak         <= id_ebreak;
            id_ex_mret           <= id_mret;
            id_ex_csr_enable     <= id_csr_enable;
            id_ex_csr_use_imm    <= id_csr_use_imm;
            id_ex_csr_command    <= id_csr_command;
            id_ex_csr_address    <= id_csr_address;
            id_ex_csr_zimm       <= id_csr_zimm;
            id_ex_branch_op      <= id_branch_op;
            id_ex_alu_a_src      <= id_alu_a_src;
            id_ex_alu_b_src      <= id_alu_b_src;
            id_ex_writeback_src  <= id_writeback_src;
            id_ex_alu_op         <= id_alu_op;
        end
    end

    // Instruction metadata advances only when the stage accepts a new item.
    // Its enable no longer depends on register-forwarding comparisons.
    always @(posedge clk) begin
        if (rst) begin
            id_ex_pc          <= 32'h0;
            id_ex_instruction <= 32'h00000013;
            id_ex_imm         <= 32'h0;
            id_ex_rs1         <= 5'h0;
            id_ex_rs2         <= 5'h0;
            id_ex_rd          <= 5'h0;
        end else if (!mem_hold) begin
            id_ex_pc          <= if_id_pc;
            id_ex_instruction <= if_id_instruction;
            id_ex_imm         <= id_imm;
            id_ex_rs1         <= id_rs1;
            id_ex_rs2         <= id_rs2;
            id_ex_rd          <= id_rd;
        end
    end

    // WB can drain during a long MEM stall.  Capture only a matching WB value
    // while stalled so the held instruction does not lose a just-retired
    // operand.  EX/MEM is the memory operation causing the stall, so feeding
    // the full EX forwarding network back here is unnecessary and creates a
    // long EX -> exception/redirect -> fetch control path.
    always @(posedge clk) begin
        if (rst) begin
            id_ex_reg_read_data1 <= 32'h0;
            id_ex_reg_read_data2 <= 32'h0;
        end else if (mem_hold) begin
            if (mem_wb_valid && mem_wb_reg_write &&
                (mem_wb_rd != 5'h0) && (mem_wb_rd == id_ex_rs1))
                id_ex_reg_read_data1 <= wb_reg_write_data;
            if (mem_wb_valid && mem_wb_reg_write &&
                (mem_wb_rd != 5'h0) && (mem_wb_rd == id_ex_rs2))
                id_ex_reg_read_data2 <= wb_reg_write_data;
        end else begin
            id_ex_reg_read_data1 <= id_reg_read_data1;
            id_ex_reg_read_data2 <= id_reg_read_data2;
        end
    end

    // Load-Use Hazard Detection
    assign load_use_hazard = if_id_valid && id_ex_valid && id_ex_mem_read &&
                             (id_ex_rd != 5'h0) &&
                             ((id_uses_rs1 && (id_ex_rd == id_rs1)) ||
                              (id_uses_rs2 && (id_ex_rd == id_rs2)));

    // A same-address CSR dependency waits until the older CSR write commits.
    // MRET also waits behind older CSR operations so it observes current mepc.
    assign csr_hazard = if_id_valid &&
        ((id_csr_enable &&
          ((id_ex_valid && id_ex_csr_enable &&
            (id_csr_address == id_ex_csr_address)) ||
           (ex_mem_valid && ex_mem_csr_write_enable &&
            (id_csr_address == ex_mem_csr_address)))) ||
         (id_mret &&
          ((id_ex_valid && id_ex_csr_enable) ||
           (ex_mem_valid && ex_mem_csr_write_enable))));

    // =========================================================
    // Stage 3: Execute (EX)
    // =========================================================
    wire [31:0] ex_alu_a;
    wire [31:0] ex_alu_b;
    wire [31:0] ex_alu_result;
    wire [1:0]  ex_memory_byte_offset;
    wire        ex_alu_zero;
    wire [31:0] ex_pc_plus_four;
    wire        ex_branch_taken;
    wire        ex_jump_taken;
    wire        ex_fence_i_taken;
    wire        ex_mret_taken;
    wire        ex_halfword_access;
    wire        ex_word_access;
    wire        ex_load_misaligned;
    wire        ex_store_misaligned;
    wire        ex_control_target_misaligned;
    wire [31:0] ex_control_target;
    wire        ex_normal_redirect;
    wire [31:0] ex_normal_redirect_target;
    reg         ex_exception_valid_reg;
    reg  [31:0] ex_exception_cause_reg;
    reg  [31:0] ex_exception_tval_reg;
    assign ex_exception_valid = ex_exception_valid_reg;
    wire [31:0] csr_read_data;
    wire        csr_read_valid;
    wire        csr_read_only;
    wire [31:0] csr_mtvec;
    wire [31:0] csr_mepc;
    wire [31:0] ex_csr_operand;
    reg  [31:0] ex_csr_new_value;
    wire        ex_csr_write_enable;
    wire        ex_csr_illegal;
    wire        csr_commit_write;
    reg         ex_branch_condition;
    reg [31:0]  ex_store_data;
    reg [3:0]   ex_store_strobe;
    
    wire [31:0] ex_mem_forward_data =
        (ex_mem_writeback_src == WB_PC4) ? ex_mem_pc_plus_four :
        (ex_mem_writeback_src == WB_CSR) ? ex_mem_csr_read_data :
                                           ex_mem_alu_result;

    // Forwarding Unit logic
    reg [1:0] forward_a;
    reg [1:0] forward_b;

    always @(*) begin
        // Forward A
        if (ex_mem_valid && ex_mem_reg_write &&
            (ex_mem_writeback_src != WB_MEM) &&
            (ex_mem_rd != 0) && (ex_mem_rd == id_ex_rs1))
            forward_a = 2'b10;
        else if (mem_wb_valid && mem_wb_reg_write &&
                 (mem_wb_rd != 0) && (mem_wb_rd == id_ex_rs1))
            forward_a = 2'b01;
        else
            forward_a = 2'b00;

        // Forward B
        if (ex_mem_valid && ex_mem_reg_write &&
            (ex_mem_writeback_src != WB_MEM) &&
            (ex_mem_rd != 0) && (ex_mem_rd == id_ex_rs2))
            forward_b = 2'b10;
        else if (mem_wb_valid && mem_wb_reg_write &&
                 (mem_wb_rd != 0) && (mem_wb_rd == id_ex_rs2))
            forward_b = 2'b01;
        else
            forward_b = 2'b00;
    end

    // Apply forwarding
    assign ex_forwarded_a = (forward_a == 2'b10) ? ex_mem_forward_data :
                            (forward_a == 2'b01) ? wb_reg_write_data :
                            id_ex_reg_read_data1;

    assign ex_forwarded_b = (forward_b == 2'b10) ? ex_mem_forward_data :
                            (forward_b == 2'b01) ? wb_reg_write_data :
                            id_ex_reg_read_data2;

    assign ex_csr_operand = id_ex_csr_use_imm ?
                            {27'b0, id_ex_csr_zimm} : ex_forwarded_a;

    assign ex_csr_write_enable = id_ex_csr_enable &&
        ((id_ex_csr_command == CSR_WRITE) ||
         (((id_ex_csr_command == CSR_SET) ||
           (id_ex_csr_command == CSR_CLEAR)) &&
          (ex_csr_operand != 32'h0000_0000)));

    assign ex_csr_illegal = id_ex_valid && id_ex_csr_enable &&
                            (!csr_read_valid ||
                             (ex_csr_write_enable && csr_read_only));

    always @(*) begin
        case (id_ex_csr_command)
            CSR_WRITE: ex_csr_new_value = ex_csr_operand;
            CSR_SET:   ex_csr_new_value = csr_read_data | ex_csr_operand;
            CSR_CLEAR: ex_csr_new_value = csr_read_data & ~ex_csr_operand;
            default:   ex_csr_new_value = csr_read_data;
        endcase
    end

    // ALU operand selection supports register, immediate, and PC-relative work.
    assign ex_alu_a = (id_ex_alu_a_src == ALU_A_PC) ? id_ex_pc :
                                                            ex_forwarded_a;

    assign ex_alu_b = (id_ex_alu_b_src == ALU_B_RS2) ? ex_forwarded_b :
                      (id_ex_alu_b_src == ALU_B_IMM)  ? id_ex_imm :
                      (id_ex_alu_b_src == ALU_B_FOUR) ? 32'd4 :
                                                       32'h0000_0000;

    alu alu_inst (
        .a            (ex_alu_a),
        .b            (ex_alu_b),
        .op           (id_ex_alu_op),
        .result       (ex_alu_result),
        .zero         (ex_alu_zero)
    );

    // Loads and stores always form their effective address as rs1 + imm.  The
    // byte-lane and alignment logic needs only the low two sum bits, which do
    // not depend on carry from any higher bit.  Compute those bits locally so
    // store formatting does not sit behind the complete 32-bit ALU/mux cone.
    assign ex_memory_byte_offset = ex_forwarded_a[1:0] + id_ex_imm[1:0];

    // Format stores into the addressed little-endian byte lanes.
    always @(*) begin
        ex_store_data   = 32'h0000_0000;
        ex_store_strobe = 4'b0000;

        case (id_ex_mem_funct3)
            3'b000: begin // SB
                case (ex_memory_byte_offset)
                    2'b00: begin
                        ex_store_data   = {24'b0, ex_forwarded_b[7:0]};
                        ex_store_strobe = 4'b0001;
                    end
                    2'b01: begin
                        ex_store_data   = {16'b0, ex_forwarded_b[7:0], 8'b0};
                        ex_store_strobe = 4'b0010;
                    end
                    2'b10: begin
                        ex_store_data   = {8'b0, ex_forwarded_b[7:0], 16'b0};
                        ex_store_strobe = 4'b0100;
                    end
                    2'b11: begin
                        ex_store_data   = {ex_forwarded_b[7:0], 24'b0};
                        ex_store_strobe = 4'b1000;
                    end
                endcase
            end

            3'b001: begin // SH; misaligned offsets are rejected before a bus request.
                if (ex_memory_byte_offset[1]) begin
                    ex_store_data   = {ex_forwarded_b[15:0], 16'b0};
                    ex_store_strobe = 4'b1100;
                end else begin
                    ex_store_data   = {16'b0, ex_forwarded_b[15:0]};
                    ex_store_strobe = 4'b0011;
                end
            end

            3'b010: begin // SW
                ex_store_data   = ex_forwarded_b;
                ex_store_strobe = 4'b1111;
            end

            default: begin
            end
        endcase
    end

    // Misaligned accesses trap instead of being split into bus transactions.
    assign ex_halfword_access = (id_ex_mem_funct3 == 3'b001) ||
                                (id_ex_mem_funct3 == 3'b101);
    assign ex_word_access = (id_ex_mem_funct3 == 3'b010);
    assign ex_load_misaligned = id_ex_valid && id_ex_mem_read &&
        ((ex_halfword_access && ex_memory_byte_offset[0]) ||
         (ex_word_access && |ex_memory_byte_offset));
    assign ex_store_misaligned = id_ex_valid && id_ex_mem_write &&
        ((ex_halfword_access && ex_memory_byte_offset[0]) ||
         (ex_word_access && |ex_memory_byte_offset));
    wire ex_memory_misaligned = ex_load_misaligned || ex_store_misaligned;

    // Branch and jump resolution. Both invalidate the two younger stages.
    assign ex_pc_plus_four = id_ex_pc + 32'd4;
    always @(*) begin
        case (id_ex_branch_op)
            BR_EQ: begin
                ex_branch_condition = (ex_forwarded_a == ex_forwarded_b);
            end
            BR_NE: begin
                ex_branch_condition = (ex_forwarded_a != ex_forwarded_b);
            end
            BR_LT: begin
                ex_branch_condition =
                    ($signed(ex_forwarded_a) < $signed(ex_forwarded_b));
            end
            BR_GE: begin
                ex_branch_condition =
                    !($signed(ex_forwarded_a) < $signed(ex_forwarded_b));
            end
            BR_LTU: begin
                ex_branch_condition = (ex_forwarded_a < ex_forwarded_b);
            end
            BR_GEU: begin
                ex_branch_condition = !(ex_forwarded_a < ex_forwarded_b);
            end
            default: begin
                ex_branch_condition = 1'b0;
            end
        endcase
    end

    assign ex_branch_taken = id_ex_valid &&
                             (id_ex_branch_op != BR_NONE) &&
                             ex_branch_condition;
    assign ex_jump_taken = id_ex_valid && id_ex_jump;
    assign ex_fence_i_taken = id_ex_valid && id_ex_fence_i;
    assign ex_mret_taken = id_ex_valid && id_ex_mret;
    assign ex_control_target = id_ex_jump_register ?
        ((ex_forwarded_a + id_ex_imm) & 32'hFFFF_FFFE) :
        (id_ex_pc + id_ex_imm);
    assign ex_control_target_misaligned =
        (ex_branch_taken || ex_jump_taken) && |ex_control_target[1:0];

    // Decode EX exceptions into parallel, mutually exclusive terms.  The
    // decoder gives every legal instruction exactly one operation class, and
    // a fetch fault substitutes a NOP, so these terms cannot legitimately
    // overlap.  Keeping the cause encoding parallel avoids a long priority
    // chain from CSR-address validation through unrelated load/store causes.
    wire ex_exception_active = id_ex_valid && !mem_hold && !kill_younger;
    wire ex_exception_ecall = ex_exception_active && id_ex_ecall;
    wire ex_exception_ebreak = ex_exception_active && id_ex_ebreak;
    wire ex_exception_fetch_fault = ex_exception_active && id_ex_fetch_fault;
    wire ex_exception_illegal = ex_exception_active &&
                                (id_ex_illegal || ex_csr_illegal);
    wire ex_exception_control_misaligned = ex_exception_active &&
                                           ex_control_target_misaligned;
    wire ex_exception_load_misaligned = ex_exception_active &&
                                        ex_load_misaligned;
    wire ex_exception_store_misaligned = ex_exception_active &&
                                         ex_store_misaligned;

    // Build one precise synchronous-exception record in EX.  Cause constants
    // are ORed rather than priority-muxed; because the terms above are
    // mutually exclusive, architectural behavior is identical while each
    // cause bit depends only on the exception classes that can set that bit.
    always @(*) begin
        ex_exception_valid_reg = ex_exception_ecall ||
                                 ex_exception_ebreak ||
                                 ex_exception_fetch_fault ||
                                 ex_exception_illegal ||
                                 ex_exception_control_misaligned ||
                                 ex_exception_load_misaligned ||
                                 ex_exception_store_misaligned;
        ex_exception_cause_reg =
            (ex_exception_ecall ? CAUSE_ECALL_M : 32'h0000_0000) |
            (ex_exception_ebreak ? CAUSE_BREAKPOINT : 32'h0000_0000) |
            (ex_exception_fetch_fault ? 32'd1 : 32'h0000_0000) |
            (ex_exception_illegal ? CAUSE_ILLEGAL_INST : 32'h0000_0000) |
            (ex_exception_control_misaligned ?
                CAUSE_INST_MISALIGNED : 32'h0000_0000) |
            (ex_exception_load_misaligned ?
                CAUSE_LOAD_MISALIGNED : 32'h0000_0000) |
            (ex_exception_store_misaligned ?
                CAUSE_STORE_MISALIGNED : 32'h0000_0000);
        ex_exception_tval_reg  = 32'h0000_0000;

        if (ex_exception_fetch_fault)
            ex_exception_tval_reg = id_ex_pc;
        else if (ex_exception_illegal)
            ex_exception_tval_reg = id_ex_instruction;
        // Misaligned control and data addresses are already registered in
        // ex_mem_redirect_target and ex_mem_alu_result respectively, then
        // selected into mtval in MEM.
    end

    // Of the EX exceptions, only a misaligned control target can coincide with
    // an otherwise valid redirect.  Gating with that specific condition keeps
    // load/store/CSR exception logic out of the redirect and pipeline-clear
    // timing cone.
    assign ex_normal_redirect = !mem_hold && !kill_younger &&
        !ex_control_target_misaligned &&
        (ex_branch_taken || ex_jump_taken || ex_fence_i_taken || ex_mret_taken);
    assign ex_normal_redirect_target = ex_mret_taken ? csr_mepc :
        ex_fence_i_taken ? ex_pc_plus_four : ex_control_target;

    assign wb_trap = mem_wb_valid && mem_wb_exception_valid;
    wire wb_normal_retirement = mem_wb_valid && !mem_wb_exception_valid;
    wire pipeline_empty = !if_id_valid && !id_ex_valid && !ex_mem_valid &&
                          !mem_wb_valid && !dmem_request_sent;
    wire interrupt_boundary_safe = !mem_hold && !dmem_request_sent && !wb_trap;
    wire interrupt_after_retirement = interrupt_request &&
        interrupt_boundary_safe && wb_normal_retirement;
    wire interrupt_while_idle = interrupt_request && pipeline_empty &&
                                interrupt_boundary_safe;
    assign interrupt_trap = interrupt_after_retirement || interrupt_while_idle;
    wire [31:0] interrupt_trap_pc = interrupt_after_retirement ?
                                    mem_wb_next_pc : architectural_next_pc;
    assign trap_take = wb_trap || interrupt_trap;

    wire [31:0] selected_trap_pc = wb_trap ? mem_wb_pc : interrupt_trap_pc;
    wire [31:0] selected_trap_instruction = wb_trap ?
                                               mem_wb_instruction : 32'h0;
    wire [31:0] selected_trap_cause = wb_trap ?
                                         mem_wb_exception_cause : interrupt_cause;
    wire [31:0] selected_trap_tval = wb_trap ?
                                        mem_wb_exception_tval : 32'h0;

    assign trap_inflight = older_exception || mem_access_fault || interrupt_trap;
    assign pc_redirect = trap_take || ex_mem_redirect_valid;
    assign redirect_target = trap_take ? csr_mtvec : ex_mem_redirect_target;

    // EX/MEM Pipeline Register
    always @(posedge clk) begin
        if (rst) begin
            ex_mem_valid       <= 1'b0;
            ex_mem_pc          <= 32'h00000000;
            ex_mem_instruction <= 32'h00000013;
            ex_mem_alu_result  <= 32'h0;
            ex_mem_pc_plus_four<= 32'h0;
            ex_mem_write_data  <= 32'h0;
            ex_mem_rd          <= 5'h0;
            ex_mem_reg_write   <= 1'b0;
            ex_mem_writeback_src <= WB_ALU;
            ex_mem_mem_funct3  <= 3'b000;
            // Strobe payload is don't-care while mem_write is reset low.
            ex_mem_mem_read    <= 1'b0;
            ex_mem_mem_write   <= 1'b0;
            ex_mem_csr_read_data <= 32'h0000_0000;
            ex_mem_csr_write_enable <= 1'b0;
            ex_mem_csr_address <= 12'h000;
            ex_mem_csr_write_data <= 32'h0000_0000;
            ex_mem_mret        <= 1'b0;
            ex_mem_redirect_valid <= 1'b0;
            ex_mem_redirect_target <= RESET_VECTOR;
            ex_mem_exception_valid <= 1'b0;
            ex_mem_exception_cause <= 32'h0000_0000;
            ex_mem_exception_tval <= 32'h0000_0000;
            ex_mem_next_pc <= RESET_VECTOR;
        end else if (kill_younger) begin
            ex_mem_valid <= 1'b0;
            ex_mem_redirect_valid <= 1'b0;
            ex_mem_exception_valid <= 1'b0;
        end else if (mem_hold) begin
            if (dmem_done)
                ex_mem_valid <= 1'b0;
        end else begin
            ex_mem_valid       <= id_ex_valid;
            ex_mem_pc          <= id_ex_pc;
            ex_mem_instruction <= id_ex_instruction;
            ex_mem_alu_result  <= ex_alu_result;
            ex_mem_pc_plus_four<= ex_pc_plus_four;
            ex_mem_write_data  <= ex_store_data;
            ex_mem_rd          <= id_ex_rd;
            ex_mem_reg_write   <= id_ex_reg_write && !ex_exception_valid;
            ex_mem_writeback_src <= id_ex_writeback_src;
            ex_mem_mem_funct3  <= id_ex_mem_funct3;
            // This payload is observed only when ex_mem_mem_write is high.
            // Keep its register free of the redundant store-valid/misalignment
            // control cone; the qualified write bit below masks it completely.
            ex_mem_mem_strobe  <= ex_store_strobe;
            ex_mem_mem_read    <= id_ex_mem_read && !ex_load_misaligned;
            ex_mem_mem_write   <= id_ex_mem_write && !ex_store_misaligned;
            ex_mem_csr_read_data <= csr_read_data;
            // Carry the decoded CSR write intent independently of exception
            // qualification.  mem_wb_exception_valid already blocks the
            // architectural write at csr_commit_write, so qualifying this
            // payload here only adds the complete exception-detection cone to
            // the EX/MEM timing path.  An illegal CSR may therefore carry a
            // don't-care write-intent bit for one stage, but it can never
            // commit that write.
            ex_mem_csr_write_enable <= ex_csr_write_enable;
            ex_mem_csr_address <= id_ex_csr_address;
            ex_mem_csr_write_data <= ex_csr_new_value;
            // As with CSR write intent, MRET is qualified at the architectural
            // commit point by mem_wb_exception_valid.  Carrying the raw intent
            // here prevents exception detection from becoming the EX/MEM
            // register's critical input without permitting a faulting MRET to
            // update machine state.
            ex_mem_mret        <= id_ex_mret;
            ex_mem_redirect_valid <= ex_normal_redirect;
            ex_mem_redirect_target <= ex_normal_redirect_target;
            ex_mem_exception_valid <= ex_exception_valid;
            ex_mem_exception_cause <= ex_exception_cause_reg;
            ex_mem_exception_tval <= ex_exception_tval_reg;
            ex_mem_next_pc <= ex_normal_redirect ?
                              ex_normal_redirect_target : ex_pc_plus_four;
        end
    end

    // =========================================================
    // Stage 4: Memory (MEM)
    // =========================================================
    wire [31:0] mem_read_data = dmem_rsp_rdata;
    wire [4:0]  mem_load_shift_amount;
    wire [31:0] mem_load_shifted;
    reg  [31:0] mem_load_value;

    assign mem_load_shift_amount = {ex_mem_alu_result[1:0], 3'b000};
    assign mem_load_shifted = mem_read_data >> mem_load_shift_amount;

    always @(*) begin
        case (ex_mem_mem_funct3)
            3'b000: begin // LB
                mem_load_value = {{24{mem_load_shifted[7]}},
                                  mem_load_shifted[7:0]};
            end
            3'b001: begin // LH
                mem_load_value = {{16{mem_load_shifted[15]}},
                                  mem_load_shifted[15:0]};
            end
            3'b010: begin // LW
                mem_load_value = mem_read_data;
            end
            3'b100: begin // LBU
                mem_load_value = {24'b0, mem_load_shifted[7:0]};
            end
            3'b101: begin // LHU
                mem_load_value = {16'b0, mem_load_shifted[15:0]};
            end
            default: begin
                mem_load_value = 32'h0000_0000;
            end
        endcase
    end

    csr_file csr_inst (
        .clk             (clk),
        .rst             (rst),
        .read_addr       (id_ex_csr_address),
        .read_data       (csr_read_data),
        .read_valid      (csr_read_valid),
        .read_only       (csr_read_only),
        .write_enable    (csr_commit_write),
        .write_addr      (mem_wb_csr_address),
        .write_data      (mem_wb_csr_write_data),
        .trap_enter      (trap_take),
        .trap_pc         (selected_trap_pc),
        .trap_cause      (selected_trap_cause),
        .trap_value      (selected_trap_tval),
        .mret_commit     (mem_wb_valid && mem_wb_mret &&
                          !mem_wb_exception_valid),
        .instruction_retired(retire_valid),
        .irq_software    (irq_software),
        .irq_timer       (irq_timer),
        .irq_external    (irq_external),
        .interrupt_request(interrupt_request),
        .interrupt_cause (interrupt_cause),
        .mtvec_value     (csr_mtvec),
        .mepc_value      (csr_mepc)
    );

    always @(posedge clk) begin
        if (rst) begin
            mem_wb_valid      <= 1'b0;
            mem_wb_pc         <= 32'h00000000;
            mem_wb_instruction<= 32'h00000013;
            mem_wb_read_data  <= 32'h0;
            mem_wb_alu_result <= 32'h0;
            mem_wb_pc_plus_four <= 32'h0;
            mem_wb_rd         <= 5'h0;
            mem_wb_reg_write  <= 1'b0;
            mem_wb_mem_read   <= 1'b0;
            mem_wb_writeback_src <= WB_ALU;
            mem_wb_mem_write  <= 1'b0;
            mem_wb_mem_data   <= 32'h00000000;
            mem_wb_mem_strobe <= 4'b0000;
            mem_wb_csr_read_data <= 32'h0000_0000;
            mem_wb_csr_write_enable <= 1'b0;
            mem_wb_csr_address <= 12'h000;
            mem_wb_csr_write_data <= 32'h0000_0000;
            mem_wb_mret        <= 1'b0;
            mem_wb_exception_valid <= 1'b0;
            mem_wb_exception_cause <= 32'h0000_0000;
            mem_wb_exception_tval <= 32'h0000_0000;
            mem_wb_next_pc <= RESET_VECTOR;
        end else if (trap_take || (mem_hold && !dmem_done)) begin
            mem_wb_valid <= 1'b0;
            mem_wb_exception_valid <= 1'b0;
        end else begin
            mem_wb_valid      <= ex_mem_valid;
            mem_wb_pc         <= ex_mem_pc;
            mem_wb_instruction<= ex_mem_instruction;
            mem_wb_read_data  <= mem_load_value;
            mem_wb_alu_result <= ex_mem_alu_result;
            mem_wb_pc_plus_four <= ex_mem_pc_plus_four;
            mem_wb_rd         <= ex_mem_rd;
            mem_wb_reg_write  <= ex_mem_reg_write && !mem_access_fault;
            mem_wb_mem_read   <= ex_mem_mem_read;
            mem_wb_writeback_src <= ex_mem_writeback_src;
            mem_wb_mem_write  <= ex_mem_mem_write;
            mem_wb_mem_data   <= ex_mem_write_data;
            mem_wb_mem_strobe <= ex_mem_mem_write ? ex_mem_mem_strobe : 4'b0000;
            mem_wb_csr_read_data <= ex_mem_csr_read_data;
            mem_wb_csr_write_enable <= ex_mem_csr_write_enable;
            mem_wb_csr_address <= ex_mem_csr_address;
            mem_wb_csr_write_data <= ex_mem_csr_write_data;
            mem_wb_mret        <= ex_mem_mret;
            mem_wb_exception_valid <= ex_mem_exception_valid || mem_access_fault;
            mem_wb_exception_cause <= mem_access_fault ? (ex_mem_mem_write ? 32'd7 : 32'd5) : ex_mem_exception_cause;
            mem_wb_exception_tval <= mem_access_fault ? ex_mem_alu_result :
                ((ex_mem_exception_valid &&
                  (ex_mem_exception_cause == CAUSE_INST_MISALIGNED)) ?
                    ex_mem_redirect_target :
                 (ex_mem_exception_valid &&
                  ((ex_mem_exception_cause == CAUSE_LOAD_MISALIGNED) ||
                   (ex_mem_exception_cause == CAUSE_STORE_MISALIGNED))) ?
                    ex_mem_alu_result : ex_mem_exception_tval);
            mem_wb_next_pc <= ex_mem_next_pc;
        end
    end

    // =========================================================
    // Stage 5: Write-Back (WB)
    // =========================================================
    assign wb_reg_write_data =
        (mem_wb_writeback_src == WB_MEM) ? mem_wb_read_data :
        (mem_wb_writeback_src == WB_PC4) ? mem_wb_pc_plus_four :
        (mem_wb_writeback_src == WB_CSR) ? mem_wb_csr_read_data :
                                          mem_wb_alu_result;

    assign csr_commit_write = mem_wb_valid && !mem_wb_exception_valid &&
                              mem_wb_csr_write_enable;

    // =========================================================
    // Output Monitoring
    // =========================================================
    assign pc_out = if_pc;
    assign instruction_out = if_instruction;
    assign alu_result_out = ex_alu_result;
    assign mem_read_data_out = mem_read_data;

    // Retirement/debug outputs
    assign retire_valid         = mem_wb_valid && !mem_wb_exception_valid;
    assign retire_pc            = mem_wb_pc;
    assign retire_instruction   = mem_wb_instruction;
    assign retire_rd_we         = retire_valid && mem_wb_reg_write && (mem_wb_rd != 5'd0);
    assign retire_rd_addr       = mem_wb_rd;
    assign retire_rd_data       = wb_reg_write_data;
    assign retire_mem_valid     = retire_valid && (mem_wb_mem_read || mem_wb_mem_write);
    assign retire_mem_write     = retire_valid && mem_wb_mem_write;
    assign retire_mem_addr      = mem_wb_alu_result;
    assign retire_mem_wdata     = mem_wb_mem_data;
    assign retire_mem_wstrb     = retire_mem_write ? mem_wb_mem_strobe : 4'b0000;

    // Trap Assignment
    assign trap_valid       = trap_take;
    assign trap_pc          = selected_trap_pc;
    assign trap_instruction = selected_trap_instruction;
    assign trap_cause       = selected_trap_cause;
    assign trap_tval        = selected_trap_tval;

    // Tracks the next instruction at the committed architectural boundary.
    // It supplies mepc when an interrupt arrives while the pipeline is empty.
    always @(posedge clk) begin
        if (rst)
            architectural_next_pc <= RESET_VECTOR;
        else if (retire_valid)
            architectural_next_pc <= mem_wb_next_pc;
    end

endmodule
