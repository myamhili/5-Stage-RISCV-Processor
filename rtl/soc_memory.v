// Generic ROM, shared executable RAM and GPIO. Arrays are not reset.
module soc_memory #(
    parameter ROM_WORDS=16384, parameter RAM_WORDS=16384,
    parameter RAM_BASE=32'h10000000, parameter LEGACY_DATA_MAP=0,
    parameter INIT_FILE=""
) (
    input wire clk, input wire rst,
    output reg [31:0] led_out,
    input wire        imem_req_valid,
    output wire        imem_req_ready,
    input wire [31:0] imem_req_addr,
    output reg        imem_rsp_valid,
    input wire        imem_rsp_ready,
    output reg [31:0] imem_rsp_data,
    output reg        imem_rsp_error,
    input wire        dmem_req_valid,
    output wire        dmem_req_ready,
    input wire        dmem_req_write,
    input wire [31:0] dmem_req_addr,
    input wire [31:0] dmem_req_wdata,
    input wire [3:0]  dmem_req_wstrb,
    output reg        dmem_rsp_valid,
    input wire        dmem_rsp_ready,
    output reg [31:0] dmem_rsp_rdata,
    output reg        dmem_rsp_error
);

    reg [31:0] rom [0:ROM_WORDS-1];
    reg [31:0] memory [0:RAM_WORDS-1];
    integer i, words;
    reg [1023:0] program_file;
    task load_default_program;
        begin
            // Fibonacci sequence generator
            // Calculates fibonacci and writes the current number to the LED port.
            rom[0]  = 32'h40001437; // lui x8, 0x40001      (x8 = 0x40001000, GPIO address)
            rom[1]  = 32'h00000093; // addi x1, x0, 0       (x1 = 0, 'a')
            rom[2]  = 32'h00100113; // addi x2, x0, 1       (x2 = 1, 'b')
            rom[3]  = 32'h00A00213; // addi x4, x0, 10      (x4 = 10, max loops)
            rom[4]  = 32'h00000293; // addi x5, x0, 0       (x5 = 0, counter)
            rom[5]  = 32'h00428E63; // beq x5, x4, end      (branch +28 to Address 12)
            rom[6]  = 32'h002081B3; // add x3, x1, x2       (x3 = x1 + x2)
            rom[7]  = 32'h002000B3; // add x1, x0, x2       (x1 = x2)
            rom[8]  = 32'h00300133; // add x2, x0, x3       (x2 = x3)
            rom[9]  = 32'h00142023; // sw x1, 0(x8)         (GPIO[0x40001000] = x1)
            rom[10] = 32'h00128293; // addi x5, x5, 1       (x5 = x5 + 1)
            rom[11] = 32'hFE0004E3; // beq x0, x0, loop     (branch -24 to Address 5)
            rom[12] = 32'h00000063; // beq x0, x0, end      (infinite loop)
        end
    endtask


    task load_branch_flush_program;
        begin
            rom[0] = 32'h00100093; // addi x1, x0, 1
            rom[1] = 32'h00108663; // beq x1, x1, +12
            rom[2] = 32'h00200113; // addi x2, x0, 2    (wrong path)
            rom[3] = 32'h06300193; // addi x3, x0, 99   (wrong path)
            rom[4] = 32'h00300193; // addi x3, x0, 3
            rom[5] = 32'h00400213; // addi x4, x0, 4
            rom[6] = 32'h00000013; // nop
            rom[7] = 32'h00000013; // nop
        end
    endtask
    initial begin
        for (i=0; i<ROM_WORDS; i=i+1) rom[i]=32'h00000013;
        for (i=0; i<RAM_WORDS; i=i+1) memory[i]=0;
        if (LEGACY_DATA_MAP) begin
            memory[0]=32'hAA; memory[1]=32'h55; memory[2]=32'hFF;
        end
        if (INIT_FILE != "") $readmemh(INIT_FILE,rom);
        else load_default_program();
`ifdef BRANCH_FLUSH_TEST
        load_branch_flush_program();
`endif
`ifndef SYNTHESIS
        if ($value$plusargs("PROGRAM=%s",program_file)) begin
            if ($value$plusargs("PROGRAM_WORDS=%d",words))
                $readmemh(program_file,rom,0,words-1);
            else $readmemh(program_file,rom);
        end
`endif
    end
    wire i_rom = imem_req_addr < ROM_WORDS*4;
    wire i_ram = imem_req_addr >= RAM_BASE &&
                 (imem_req_addr-RAM_BASE) < RAM_WORDS*4;
    wire d_ram = dmem_req_addr >= RAM_BASE &&
                 (dmem_req_addr-RAM_BASE) < RAM_WORDS*4;
    wire d_legacy = LEGACY_DATA_MAP && dmem_req_addr < RAM_WORDS*4;
    wire d_rom = !LEGACY_DATA_MAP && dmem_req_addr < ROM_WORDS*4;
    wire d_gpio = dmem_req_addr == 32'h40001000;
    function integer clog2;
        input integer value;
        integer v;
        begin
            v=value-1; clog2=0;
            while (v>0) begin clog2=clog2+1; v=v>>1; end
        end
    endfunction
    localparam RAM_AW=(RAM_WORDS>1) ? clog2(RAM_WORDS) : 1;
    localparam ROM_AW=(ROM_WORDS>1) ? clog2(ROM_WORDS) : 1;
    localparam NONE=2'd0, RAM=2'd1, ROM=2'd2, GPIO=2'd3;
    wire [31:0] i_offset=imem_req_addr-RAM_BASE;
    wire [31:0] d_offset=d_legacy ? dmem_req_addr : dmem_req_addr-RAM_BASE;
    wire [RAM_AW-1:0] i_index=i_offset>>2;
    wire [RAM_AW-1:0] d_index=d_offset>>2;
    wire [ROM_AW-1:0] i_rom_index=imem_req_addr>>2;
    wire [ROM_AW-1:0] d_rom_index=dmem_req_addr>>2;
    wire i_aligned=imem_req_addr[1:0]==0;
    wire d_aligned=dmem_req_addr[1:0]==0;
    wire i_accept=imem_req_valid && imem_req_ready;
    wire d_accept=dmem_req_valid && dmem_req_ready;
    wire ram_d_en=d_accept && (d_ram || d_legacy) && d_aligned;
    wire ram_d_write=ram_d_en && dmem_req_write && (|dmem_req_wstrb);
    // Do not rely on device-specific cross-port read-during-write behavior.
    // Data writes win; the instruction request remains presented until accepted.
    wire collision=imem_req_valid && i_ram && i_aligned && ram_d_write &&
                   (i_index==d_index);
    assign imem_req_ready = !rst && !imem_rsp_valid && !collision;
    assign dmem_req_ready = !rst && !dmem_rsp_valid;
    reg [31:0] ram_i_rdata, ram_d_rdata, rom_i_rdata, rom_d_rdata, gpio_rdata;
    reg [1:0] i_target, d_target;

    // Dedicated synchronous RAM outputs: no reset or ROM/GPIO mux here.
    // This is a read-first data port with byte-wide write enables.
    always @(posedge clk) begin
        if (i_accept && i_ram && i_aligned)
            ram_i_rdata<=memory[i_index];
    end
    always @(posedge clk) begin
        if (ram_d_en) begin
            ram_d_rdata<=memory[d_index];
            if (ram_d_write) begin
                if (dmem_req_wstrb[0]) memory[d_index][7:0]<=dmem_req_wdata[7:0];
                if (dmem_req_wstrb[1]) memory[d_index][15:8]<=dmem_req_wdata[15:8];
                if (dmem_req_wstrb[2]) memory[d_index][23:16]<=dmem_req_wdata[23:16];
                if (dmem_req_wstrb[3]) memory[d_index][31:24]<=dmem_req_wdata[31:24];
            end
        end
    end
    always @(posedge clk) begin
        if (i_accept && i_rom && i_aligned) rom_i_rdata<=rom[i_rom_index];
        if (d_accept && d_rom && !dmem_req_write && d_aligned)
            rom_d_rdata<=rom[d_rom_index];
        if (d_accept && d_gpio && d_aligned) gpio_rdata<=led_out;
        if (i_accept) begin
            if (!i_aligned) i_target<=NONE;
            else if (i_rom) i_target<=ROM;
            else if (i_ram) i_target<=RAM;
            else i_target<=NONE;
        end
        if (d_accept) begin
            if (!d_aligned) d_target<=NONE;
            else if (d_ram || d_legacy) d_target<=RAM;
            else if (d_rom && !dmem_req_write) d_target<=ROM;
            else if (d_gpio) d_target<=GPIO;
            else d_target<=NONE;
        end
    end
    // Target and memory outputs update together on request acceptance and hold
    // throughout response backpressure. Live request addresses cannot change it.
    always @* begin
        case (i_target)
            RAM: imem_rsp_data=ram_i_rdata;
            ROM: imem_rsp_data=rom_i_rdata;
            default: imem_rsp_data=0;
        endcase
        case (d_target)
            RAM: dmem_rsp_rdata=ram_d_rdata;
            ROM: dmem_rsp_rdata=rom_d_rdata;
            GPIO: dmem_rsp_rdata=gpio_rdata;
            default: dmem_rsp_rdata=0;
        endcase
    end
    always @(posedge clk) begin
        if (rst) begin
            imem_rsp_valid<=0; imem_rsp_error<=0;
            dmem_rsp_valid<=0; dmem_rsp_error<=0;
            led_out<=0;
        end else begin
            if (imem_rsp_valid && imem_rsp_ready) imem_rsp_valid<=0;
            if (dmem_rsp_valid && dmem_rsp_ready) dmem_rsp_valid<=0;
            if (imem_req_valid && imem_req_ready) begin
                imem_rsp_valid<=1;
                imem_rsp_error<=!(i_rom || i_ram) || |imem_req_addr[1:0];
            end
            if (dmem_req_valid && dmem_req_ready) begin
                dmem_rsp_valid<=1;
                dmem_rsp_error<=!(d_ram || d_legacy || d_gpio ||
                                   (d_rom && !dmem_req_write)) || |dmem_req_addr[1:0];
                if (d_gpio && dmem_req_write && dmem_req_addr[1:0]==0) begin
                    if (dmem_req_wstrb[0]) led_out[7:0]<=dmem_req_wdata[7:0];
                    if (dmem_req_wstrb[1]) led_out[15:8]<=dmem_req_wdata[15:8];
                    if (dmem_req_wstrb[2]) led_out[23:16]<=dmem_req_wdata[23:16];
                    if (dmem_req_wstrb[3]) led_out[31:24]<=dmem_req_wdata[31:24];
                end
            end
        end
    end
endmodule
