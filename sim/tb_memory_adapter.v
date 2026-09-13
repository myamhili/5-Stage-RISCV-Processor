`timescale 1ns/1ps
module tb_memory_adapter;
    reg clk=0, rst=1;
    always #5 clk=~clk;
    reg req_valid=0, req_write=0, rsp_ready=0;
    reg [31:0] req_addr=0, req_wdata=0;
    reg [3:0] req_wstrb=0;
    wire req_ready, rsp_valid, rsp_error;
    wire [31:0] rsp_rdata, led;
    integer requests=0, responses=0;
    soc_memory #(.ROM_WORDS(64),.RAM_WORDS(64)) uut(
        .clk(clk),.rst(rst),.led_out(led),
        .imem_req_valid(1'b0),.imem_req_addr(32'b0),.imem_rsp_ready(1'b1),
        .dmem_req_valid(req_valid),.dmem_req_ready(req_ready),
        .dmem_req_addr(req_addr),.dmem_req_write(req_write),
        .dmem_req_wdata(req_wdata),.dmem_req_wstrb(req_wstrb),
        .dmem_rsp_valid(rsp_valid),.dmem_rsp_ready(rsp_ready),
        .dmem_rsp_rdata(rsp_rdata),.dmem_rsp_error(rsp_error)
    );
    bus_monitor monitor(
        .clk(clk),.rst(rst),.req_valid(req_valid),.req_ready(req_ready),
        .req_payload({req_write,req_addr,req_wdata,req_wstrb}),
        .rsp_valid(rsp_valid),.rsp_ready(rsp_ready),.rsp_payload({rsp_error,rsp_rdata})
    );
    task access;
        input wr; input [31:0] addr,data; input [3:0] mask;
        input error_expected; input [31:0] expected;
        begin
            @(negedge clk);
            req_valid=1; req_write=wr; req_addr=addr; req_wdata=data; req_wstrb=mask;
            @(posedge clk);
            while(!req_ready) @(posedge clk);
            requests=requests+1;
            @(negedge clk); req_valid=0;
            while(!rsp_valid) @(negedge clk);
            if(rsp_error !== error_expected) $fatal(1,"Adapter error decode");
            if(!wr && !error_expected && rsp_rdata !== expected)
                $fatal(1,"Adapter read data %h expected %h",rsp_rdata,expected);
            // Receiver refuses the response: adapter must retain it.
            repeat(5) @(negedge clk);
            rsp_ready=1;
            @(posedge clk); responses=responses+1;
            @(negedge clk); rsp_ready=0;
        end
    endtask
    initial begin
        repeat(3) @(negedge clk); rst=0;
        access(1,32'h10000000,32'h44332211,15,0,0);
        access(1,32'h10000000,32'h0000aa00,2,0,0);
        access(0,32'h10000000,0,0,0,32'h4433aa11);
        access(1,32'h10000000,32'hbbcc0000,12,0,0);
        access(0,32'h10000000,0,0,0,32'hbbccaa11);
        access(1,32'h100000fc,32'h12345678,15,0,0);
        access(0,32'h100000fc,0,0,0,32'h12345678);
        access(1,32'h10000100,32'hffffffff,15,1,0);
        access(1,32'h10000001,32'hffffffff,15,1,0);
        access(0,32'h10000000,0,0,0,32'hbbccaa11);
        access(1,0,32'hffffffff,15,1,0);
        access(0,32'h90000000,0,0,1,0);
        access(1,32'h40001000,32'h12345678,15,0,0);
        access(1,32'h40001004,32'hffffffff,15,1,0);
        access(0,32'h40001000,0,0,0,32'h12345678);
        if(requests!=responses) $fatal(1,"Lost adapter response");
        $display("TEST memory_adapter PASS");
        $finish;
    end
    initial begin #100000; $fatal(1,"Adapter timeout"); end
endmodule
