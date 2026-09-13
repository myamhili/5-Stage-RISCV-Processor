// Simulation-only protocol assertions. Instantiate on each side of an adapter.
module bus_monitor #(
    parameter PAYLOAD_WIDTH=69
) (
    input wire clk, input wire rst,
    input wire req_valid, input wire req_ready,
    input wire [PAYLOAD_WIDTH-1:0] req_payload,
    input wire rsp_valid, input wire rsp_ready,
    input wire [32:0] rsp_payload
);
    reg request_blocked, response_blocked, outstanding;
    reg [PAYLOAD_WIDTH-1:0] saved_request;
    reg [32:0] saved_response;
    initial begin request_blocked=0; response_blocked=0; outstanding=0; end
    always @(posedge clk) begin
        if (rst) begin
            request_blocked=0; response_blocked=0; outstanding=0;
        end else begin
            if (request_blocked && (!req_valid || req_payload !== saved_request))
                $fatal(1,"Request changed under backpressure: %m");
            if (response_blocked && (!rsp_valid || rsp_payload !== saved_response))
                $fatal(1,"Response changed under backpressure: %m");
            if (rsp_valid && !outstanding)
                $fatal(1,"Response without outstanding request: %m");
            if (req_valid && req_ready) begin
                if (outstanding) $fatal(1,"Multiple outstanding requests: %m");
                outstanding=1;
            end
            if (rsp_valid && rsp_ready) outstanding=0;
            request_blocked=req_valid && !req_ready;
            response_blocked=rsp_valid && !rsp_ready;
            saved_request=req_payload;
            saved_response=rsp_payload;
        end
    end
endmodule
