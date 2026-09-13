`timescale 1ns/1ps
// Exercise both physical RAM ports, including collision arbitration and a
// pending instruction response while the data port overwrites its address.
module tb_ram_ports;
    reg clk=0, rst=1;
    always #5 clk=~clk;
    reg iv=0, ir=0, dv=0, dr=0, dw=0;
    reg [31:0] ia=0, da=0, wd=0;
    reg [3:0] ws=0;
    wire iq, ov, oe, dq, rv, re;
    wire [31:0] idata, rd, led;
    integer icount=0, dcount=0, writes=0;
    soc_memory #(.ROM_WORDS(64), .RAM_WORDS(64)) uut (
        .clk(clk),.rst(rst),.led_out(led),
        .imem_req_valid(iv),.imem_req_ready(iq),.imem_req_addr(ia),
        .imem_rsp_valid(ov),.imem_rsp_ready(ir),.imem_rsp_data(idata),.imem_rsp_error(oe),
        .dmem_req_valid(dv),.dmem_req_ready(dq),.dmem_req_write(dw),
        .dmem_req_addr(da),.dmem_req_wdata(wd),.dmem_req_wstrb(ws),
        .dmem_rsp_valid(rv),.dmem_rsp_ready(dr),.dmem_rsp_rdata(rd),.dmem_rsp_error(re)
    );
    bus_monitor #(.PAYLOAD_WIDTH(32)) imon (
        .clk(clk),.rst(rst),.req_valid(iv),.req_ready(iq),.req_payload(ia),
        .rsp_valid(ov),.rsp_ready(ir),.rsp_payload({oe,idata})
    );
    bus_monitor dmon (
        .clk(clk),.rst(rst),.req_valid(dv),.req_ready(dq),.req_payload({dw,da,wd,ws}),
        .rsp_valid(rv),.rsp_ready(dr),.rsp_payload({re,rd})
    );
    always @(posedge clk) if (!rst) begin
        if (iv && iq) icount=icount+1;
        if (dv && dq) begin
            dcount=dcount+1;
            if (dw) writes=writes+1;
        end
    end
    task drain;
        begin
            ir=1; dr=1;
            @(negedge clk); ir=0; dr=0;
        end
    endtask
    initial begin
        repeat(3) @(negedge clk); rst=0;
        // Simultaneous write and fetch of word zero: only the write may enter.
        dv=1; dw=1; da=32'h10000000; wd=32'h44332211; ws=15;
        iv=1; ia=32'h10000000;
        #1;
        if (iq!==0 || dq!==1) $fatal(1,"Collision must prioritize data write");
        @(negedge clk); dv=0;
        if (!rv || re || ov) $fatal(1,"Collision response ordering");
        @(negedge clk); iv=0;
        if (!ov || oe || idata!==32'h44332211) $fatal(1,"Fetch did not see committed write");
        // Live addresses must not select another device while responses wait.
        ia=0; da=32'h40001000;
        repeat(4) @(negedge clk);
        if (idata!==32'h44332211) $fatal(1,"Response followed live address");
        // Drain only the data response; hold instruction response across a write.
        dr=1; @(negedge clk); dr=0;
        dv=1; da=32'h10000000; wd=32'h0000aa00; ws=2;
        @(negedge clk); dv=0;
        if (!rv || re || idata!==32'h44332211)
            $fatal(1,"Pending instruction response changed during overwrite");
        repeat(4) @(negedge clk);
        if (idata!==32'h44332211) $fatal(1,"Instruction response did not hold");
        drain;
        // Both ports can read the same word concurrently and see the byte update.
        iv=1; ia=32'h10000000;
        dv=1; dw=0; da=32'h10000000; ws=0;
        #1; if (!iq || !dq) $fatal(1,"Read/read unnecessarily stalled");
        @(negedge clk); iv=0; dv=0;
        if (!ov || !rv || oe || re || idata!==32'h4433aa11 || rd!==32'h4433aa11)
            $fatal(1,"Dual-port read or byte preservation failed");
        drain;
        // Different-word write and fetch must also run concurrently.
        iv=1; ia=32'h10000000;
        dv=1; dw=1; da=32'h10000004; wd=32'habcdef12; ws=15;
        #1; if (!iq || !dq) $fatal(1,"Different-word access stalled");
        @(negedge clk); iv=0; dv=0;
        if (!ov || !rv || oe || re || idata!==32'h4433aa11)
            $fatal(1,"Different-word access failed");
        drain;
        // Separate ROM/RAM output selection, then instruction-side range errors.
        iv=1; ia=0; dv=1; dw=0; da=32'h10000004; ws=0;
        @(negedge clk); iv=0; dv=0;
        if (!ov || !rv || oe || re || idata!==32'h40001437 || rd!==32'habcdef12)
            $fatal(1,"ROM/RAM selection failed");
        drain;
        iv=1; ia=32'h10000100;
        @(negedge clk); iv=0;
        if (!ov || !oe) $fatal(1,"Out-of-range fetch did not fault");
        drain;
        iv=1; ia=32'h10000001;
        @(negedge clk); iv=0;
        if (!ov || !oe) $fatal(1,"Misaligned fetch did not fault");
        drain;
        if (icount!=6 || dcount!=5 || writes!=3)
            $fatal(1,"Transaction count mismatch i=%0d d=%0d writes=%0d",icount,dcount,writes);
        $display("TEST ram_ports PASS");
        $finish;
    end
    initial begin #100000; $fatal(1,"RAM ports timeout"); end
endmodule
