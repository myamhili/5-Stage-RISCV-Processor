`timescale 1ns/1ps
// An older JAL redirects while the next sequential fetch is being presented.
// That fetch returns an error; the error must be drained without taking a trap.
module tb_fetch_discard;
    reg clk=0, rst=1;
    always #5 clk=~clk;
    wire imem_req_valid, imem_req_ready, imem_rsp_ready;
    wire [31:0] imem_req_addr;
    reg imem_rsp_valid=0, imem_rsp_error=0;
    reg [31:0] imem_rsp_data=0;
    wire retire_valid, trap_valid, retire_rd_we;
    wire [31:0] retire_pc, retire_rd_data;
    wire [4:0] retire_rd_addr;
    integer delay_mode, unused, request_wait=0, discarded_errors=0, retired=0;
    assign imem_req_ready=!rst && !imem_rsp_valid &&
        (imem_req_addr!=4 || request_wait>=delay_mode);
    risc_core uut(
        .clk(clk),.rst(rst),
        .irq_software(1'b0),.irq_timer(1'b0),.irq_external(1'b0),
        .imem_req_valid(imem_req_valid),.imem_req_ready(imem_req_ready),
        .imem_req_addr(imem_req_addr),.imem_rsp_valid(imem_rsp_valid),
        .imem_rsp_ready(imem_rsp_ready),.imem_rsp_data(imem_rsp_data),
        .imem_rsp_error(imem_rsp_error),
        .dmem_req_ready(1'b0),.dmem_rsp_valid(1'b0),
        .dmem_rsp_rdata(32'b0),.dmem_rsp_error(1'b0),
        .retire_valid(retire_valid),.retire_pc(retire_pc),
        .retire_rd_we(retire_rd_we),.retire_rd_addr(retire_rd_addr),
        .retire_rd_data(retire_rd_data),.trap_valid(trap_valid)
    );
    bus_monitor #(.PAYLOAD_WIDTH(32)) monitor(
        .clk(clk),.rst(rst),.req_valid(imem_req_valid),.req_ready(imem_req_ready),
        .req_payload(imem_req_addr),.rsp_valid(imem_rsp_valid),
        .rsp_ready(imem_rsp_ready),.rsp_payload({imem_rsp_error,imem_rsp_data})
    );
    always @(posedge clk) begin
        if(rst) begin
            imem_rsp_valid<=0; request_wait<=0;
            discarded_errors<=0; retired<=0;
        end else begin
            if (imem_req_valid && !imem_req_ready) request_wait<=request_wait+1;
            if (imem_rsp_valid && imem_rsp_ready) begin
                imem_rsp_valid<=0;
                if (imem_rsp_error) discarded_errors<=discarded_errors+1;
            end
            if (imem_req_valid && imem_req_ready) begin
                imem_rsp_valid<=1; imem_rsp_error<=0;
                case(imem_req_addr)
                    0: imem_rsp_data<=32'h0200006f; // jal x0,32
                    4: begin imem_rsp_data<=32'hffffffff; imem_rsp_error<=1; end
                    32: imem_rsp_data<=32'h00100f93; // completion
                    default: imem_rsp_data<=32'h0000006f;
                endcase
            end
            if (trap_valid) $fatal(1,"Wrong-path fetch error became a trap");
            if (retire_valid) begin
                if (retired==0 && retire_pc!=0) $fatal(1,"Initial PC");
                if (retired==1 && retire_pc!=32) $fatal(1,"Wrong path retired");
                retired<=retired+1;
                if (retire_rd_we && retire_rd_addr==31) begin
                    if (retire_rd_data!=1 || discarded_errors!=1)
                        $fatal(1,"Discard path not exercised");
                    $display("TEST fetch_discard PASS delay=%0d",delay_mode);
                    $finish;
                end
            end
        end
    end
    initial begin
        delay_mode=0; unused=$value$plusargs("REQUEST_WAIT=%d",delay_mode);
        repeat(3) @(negedge clk); rst=0;
        #10000; $fatal(1,"Fetch discard timeout");
    end
endmodule
