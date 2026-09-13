module simple_soc #(
    parameter RESET_VECTOR = 32'h00000000,
    parameter ROM_WORDS = 16384,
    parameter RAM_WORDS = 16384,
    parameter RAM_BASE = 32'h10000000,
    parameter LEGACY_DATA_MAP = 0,
    parameter INIT_FILE = ""
) (
    input  wire        clk,
    input  wire        rst,
    input  wire        irq_software,
    input  wire        irq_timer,
    input  wire        irq_external,
    output wire [31:0] pc_out,
    output wire [31:0] instruction_out,
    output wire [31:0] alu_result_out,
    output wire [31:0] mem_read_data_out,
    output wire [31:0] led_out,

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
    wire        imem_req_valid;
    wire        imem_req_ready;
    wire [31:0] imem_req_addr;
    wire        imem_rsp_valid;
    wire        imem_rsp_ready;
    wire [31:0] imem_rsp_data;
    wire        imem_rsp_error;
    wire        dmem_req_valid;
    wire        dmem_req_ready;
    wire        dmem_req_write;
    wire [31:0] dmem_req_addr;
    wire [31:0] dmem_req_wdata;
    wire [3:0]  dmem_req_wstrb;
    wire        dmem_rsp_valid;
    wire        dmem_rsp_ready;
    wire [31:0] dmem_rsp_rdata;
    wire        dmem_rsp_error;
    risc_core #(.RESET_VECTOR(RESET_VECTOR)) core (
        .clk(clk),
        .rst(rst),
        .irq_software(irq_software),
        .irq_timer(irq_timer),
        .irq_external(irq_external),
        .pc_out(pc_out),
        .instruction_out(instruction_out),
        .alu_result_out(alu_result_out),
        .mem_read_data_out(mem_read_data_out),
        .retire_valid(retire_valid),
        .retire_pc(retire_pc),
        .retire_instruction(retire_instruction),
        .retire_rd_we(retire_rd_we),
        .retire_rd_addr(retire_rd_addr),
        .retire_rd_data(retire_rd_data),
        .retire_mem_valid(retire_mem_valid),
        .retire_mem_write(retire_mem_write),
        .retire_mem_addr(retire_mem_addr),
        .retire_mem_wdata(retire_mem_wdata),
        .retire_mem_wstrb(retire_mem_wstrb),
        .trap_valid(trap_valid),
        .trap_pc(trap_pc),
        .trap_instruction(trap_instruction),
        .trap_cause(trap_cause),
        .trap_tval(trap_tval),
        .imem_req_valid(imem_req_valid),
        .imem_req_ready(imem_req_ready),
        .imem_req_addr(imem_req_addr),
        .imem_rsp_valid(imem_rsp_valid),
        .imem_rsp_ready(imem_rsp_ready),
        .imem_rsp_data(imem_rsp_data),
        .imem_rsp_error(imem_rsp_error),
        .dmem_req_valid(dmem_req_valid),
        .dmem_req_ready(dmem_req_ready),
        .dmem_req_write(dmem_req_write),
        .dmem_req_addr(dmem_req_addr),
        .dmem_req_wdata(dmem_req_wdata),
        .dmem_req_wstrb(dmem_req_wstrb),
        .dmem_rsp_valid(dmem_rsp_valid),
        .dmem_rsp_ready(dmem_rsp_ready),
        .dmem_rsp_rdata(dmem_rsp_rdata),
        .dmem_rsp_error(dmem_rsp_error)
    );
    wire b_imem_req_valid;
    wire b_imem_req_ready;
    wire [31:0] b_imem_req_addr;
    wire b_imem_rsp_valid;
    wire b_imem_rsp_ready;
    wire [31:0] b_imem_rsp_data;
    wire b_imem_rsp_error;
    wire b_dmem_req_valid;
    wire b_dmem_req_ready;
    wire b_dmem_req_write;
    wire [31:0] b_dmem_req_addr;
    wire [31:0] b_dmem_req_wdata;
    wire [3:0] b_dmem_req_wstrb;
    wire b_dmem_rsp_valid;
    wire b_dmem_rsp_ready;
    wire [31:0] b_dmem_rsp_rdata;
    wire b_dmem_rsp_error;
    memory_delay #(.CHANNEL(0)) imem_delay (
        .clk(clk), .rst(rst),
        .s_req_valid(imem_req_valid),
        .m_req_valid(b_imem_req_valid),
        .s_req_ready(imem_req_ready),
        .m_req_ready(b_imem_req_ready),
        .s_req_addr(imem_req_addr),
        .m_req_addr(b_imem_req_addr),
        .s_req_write(1'b0),
        .m_req_write(),
        .s_req_wdata(32'b0),
        .m_req_wdata(),
        .s_req_wstrb(4'b0),
        .m_req_wstrb(),
        .s_rsp_valid(imem_rsp_valid),
        .m_rsp_valid(b_imem_rsp_valid),
        .s_rsp_ready(imem_rsp_ready),
        .m_rsp_ready(b_imem_rsp_ready),
        .s_rsp_rdata(imem_rsp_data),
        .m_rsp_rdata(b_imem_rsp_data),
        .s_rsp_error(imem_rsp_error),
        .m_rsp_error(b_imem_rsp_error)
    );
    memory_delay #(.CHANNEL(1)) dmem_delay (
        .clk(clk), .rst(rst),
        .s_req_valid(dmem_req_valid),
        .m_req_valid(b_dmem_req_valid),
        .s_req_ready(dmem_req_ready),
        .m_req_ready(b_dmem_req_ready),
        .s_req_addr(dmem_req_addr),
        .m_req_addr(b_dmem_req_addr),
        .s_req_write(dmem_req_write),
        .m_req_write(b_dmem_req_write),
        .s_req_wdata(dmem_req_wdata),
        .m_req_wdata(b_dmem_req_wdata),
        .s_req_wstrb(dmem_req_wstrb),
        .m_req_wstrb(b_dmem_req_wstrb),
        .s_rsp_valid(dmem_rsp_valid),
        .m_rsp_valid(b_dmem_rsp_valid),
        .s_rsp_ready(dmem_rsp_ready),
        .m_rsp_ready(b_dmem_rsp_ready),
        .s_rsp_rdata(dmem_rsp_rdata),
        .m_rsp_rdata(b_dmem_rsp_rdata),
        .s_rsp_error(dmem_rsp_error),
        .m_rsp_error(b_dmem_rsp_error)
    );
    soc_memory #(.ROM_WORDS(ROM_WORDS), .RAM_WORDS(RAM_WORDS),
        .RAM_BASE(RAM_BASE), .LEGACY_DATA_MAP(LEGACY_DATA_MAP),
        .INIT_FILE(INIT_FILE)) memory (
        .clk(clk), .rst(rst), .led_out(led_out),
        .imem_req_valid(b_imem_req_valid),
        .imem_req_ready(b_imem_req_ready),
        .imem_req_addr(b_imem_req_addr),
        .imem_rsp_valid(b_imem_rsp_valid),
        .imem_rsp_ready(b_imem_rsp_ready),
        .imem_rsp_data(b_imem_rsp_data),
        .imem_rsp_error(b_imem_rsp_error),
        .dmem_req_valid(b_dmem_req_valid),
        .dmem_req_ready(b_dmem_req_ready),
        .dmem_req_write(b_dmem_req_write),
        .dmem_req_addr(b_dmem_req_addr),
        .dmem_req_wdata(b_dmem_req_wdata),
        .dmem_req_wstrb(b_dmem_req_wstrb),
        .dmem_rsp_valid(b_dmem_rsp_valid),
        .dmem_rsp_ready(b_dmem_rsp_ready),
        .dmem_rsp_rdata(b_dmem_rsp_rdata),
        .dmem_rsp_error(b_dmem_rsp_error)
    );
endmodule
