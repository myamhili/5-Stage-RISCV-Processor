// Single outstanding transaction; deterministic simulation latency injection.
module memory_delay #(
    parameter CHANNEL=0, parameter REQUEST_DELAY=0, parameter RESPONSE_DELAY=0
) (
    input wire clk, input wire rst,
    input wire s_req_valid, output wire s_req_ready,
    input wire [31:0] s_req_addr, input wire s_req_write,
    input wire [31:0] s_req_wdata, input wire [3:0] s_req_wstrb,
    output wire s_rsp_valid, input wire s_rsp_ready,
    output wire [31:0] s_rsp_rdata, output wire s_rsp_error,
    output wire m_req_valid, input wire m_req_ready,
    output wire [31:0] m_req_addr, output wire m_req_write,
    output wire [31:0] m_req_wdata, output wire [3:0] m_req_wstrb,
    input wire m_rsp_valid, output wire m_rsp_ready,
    input wire [31:0] m_rsp_rdata, input wire m_rsp_error
);
`ifdef SYNTHESIS
    // Hardware uses the native memory handshake directly.  This module exists
    // to inject deterministic and randomized wait states into simulation; its
    // delay counters would be dead weight when all synthesis delays are zero.
    assign m_req_valid = !rst && s_req_valid;
    assign s_req_ready = !rst && m_req_ready;
    assign m_req_addr  = s_req_addr;
    assign m_req_write = s_req_write;
    assign m_req_wdata = s_req_wdata;
    assign m_req_wstrb = s_req_wstrb;
    assign s_rsp_valid = !rst && m_rsp_valid;
    assign m_rsp_ready = !rst && s_rsp_ready;
    assign s_rsp_rdata = m_rsp_rdata;
    assign s_rsp_error = m_rsp_error;
`else
    localparam IDLE=0, WAIT_RESPONSE=1, DELIVER=2;
    reg [1:0] state;
    integer req_delay, rsp_delay, random_delay, seed, unused;
    integer countdown;
    reg [31:0] rng;
    reg [31:0] s_rsp_rdata_reg;
    reg s_rsp_error_reg;
    wire [31:0] next_rng = {rng[30:0], rng[31]^rng[21]^rng[1]^rng[0]};
    initial begin
        req_delay=REQUEST_DELAY; rsp_delay=RESPONSE_DELAY;
        random_delay=0; seed=1;
        if (CHANNEL == 0) begin
            unused=$value$plusargs("IMEM_REQ_DELAY=%d", req_delay);
            unused=$value$plusargs("IMEM_RSP_DELAY=%d", rsp_delay);
        end else begin
            unused=$value$plusargs("DMEM_REQ_DELAY=%d", req_delay);
            unused=$value$plusargs("DMEM_RSP_DELAY=%d", rsp_delay);
        end
        unused=$value$plusargs("RANDOM_DELAY=%d", random_delay);
        unused=$value$plusargs("SEED=%d", seed);
    end
    assign m_req_valid = !rst && state==IDLE && countdown==0 && s_req_valid;
    assign s_req_ready = !rst && state==IDLE && countdown==0 && m_req_ready;
    assign m_req_addr=s_req_addr;
    assign m_req_write=s_req_write;
    assign m_req_wdata=s_req_wdata;
    assign m_req_wstrb=s_req_wstrb;
    assign m_rsp_ready=!rst && state==WAIT_RESPONSE;
    assign s_rsp_valid=!rst && state==DELIVER && countdown==0;
    assign s_rsp_rdata=s_rsp_rdata_reg;
    assign s_rsp_error=s_rsp_error_reg;
    always @(posedge clk) begin
        if (rst) begin
            state<=IDLE; countdown<=req_delay;
            rng<=seed+CHANNEL+1;
            s_rsp_rdata_reg<=0; s_rsp_error_reg<=0;
        end else begin
            if (countdown>0) countdown<=countdown-1;
            case (state)
                IDLE: if (s_req_valid && s_req_ready)
                    state<=WAIT_RESPONSE;
                WAIT_RESPONSE: if (m_rsp_valid && m_rsp_ready) begin
                    s_rsp_rdata_reg<=m_rsp_rdata;
                    s_rsp_error_reg<=m_rsp_error;
                    state<=DELIVER;
                    countdown<=rsp_delay;
                    if (random_delay>0)
                        countdown<=rsp_delay+(rng % (random_delay+1));
                    rng<=next_rng;
                end
                DELIVER: if (s_rsp_valid && s_rsp_ready) begin
                    state<=IDLE;
                    countdown<=req_delay;
                    if (random_delay>0)
                        countdown<=req_delay+(rng % (random_delay+1));
                    rng<=next_rng;
                end
            endcase
        end
    end
`endif
endmodule
