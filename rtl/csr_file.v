// Machine-mode CSR file for Zicsr, precise traps, interrupts, and counters.

module csr_file (
    input  wire        clk,
    input  wire        rst,

    input  wire [11:0] read_addr,
    output reg  [31:0] read_data,
    output reg         read_valid,
    output reg         read_only,

    input  wire        write_enable,
    input  wire [11:0] write_addr,
    input  wire [31:0] write_data,

    input  wire        trap_enter,
    input  wire [31:0] trap_pc,
    input  wire [31:0] trap_cause,
    input  wire [31:0] trap_value,
    input  wire        mret_commit,
    input  wire        instruction_retired,

    input  wire        irq_software,
    input  wire        irq_timer,
    input  wire        irq_external,
    output reg         interrupt_request,
    output reg  [31:0] interrupt_cause,

    output wire [31:0] mtvec_value,
    output wire [31:0] mepc_value
);

    localparam CSR_MSTATUS   = 12'h300;
    localparam CSR_MISA      = 12'h301;
    localparam CSR_MIE       = 12'h304;
    localparam CSR_MTVEC     = 12'h305;
    localparam CSR_MSCRATCH  = 12'h340;
    localparam CSR_MEPC      = 12'h341;
    localparam CSR_MCAUSE    = 12'h342;
    localparam CSR_MTVAL     = 12'h343;
    localparam CSR_MIP       = 12'h344;
    localparam CSR_MCYCLE    = 12'hB00;
    localparam CSR_MINSTRET  = 12'hB02;
    localparam CSR_MCYCLEH   = 12'hB80;
    localparam CSR_MINSTRETH = 12'hB82;

    localparam [31:0] MIE_MASK = 32'h0000_0888;

    // RV32 with the I extension. The M bit is added only with the M milestone.
    localparam [31:0] MISA_VALUE = 32'h4000_0100;

    reg        mstatus_mie;
    reg        mstatus_mpie;
    reg [31:0] mie;
    reg [31:0] mtvec;
    reg [31:0] mscratch;
    reg [31:0] mepc;
    reg [31:0] mcause;
    reg [31:0] mtval;
    reg [63:0] mcycle;
    reg [63:0] minstret;

    // State after the instruction currently retiring, but before a trap at
    // that same architectural boundary. Interrupt arbitration uses this
    // state so CSR writes and MRET take effect without admitting an extra
    // instruction before an already-pending interrupt.
    reg        pretrap_mstatus_mie;
    reg        pretrap_mstatus_mpie;
    reg [31:0] pretrap_mie;
    reg [31:0] pretrap_mtvec;
    reg [31:0] pretrap_mscratch;
    reg [31:0] pretrap_mepc;
    reg [31:0] pretrap_mcause;
    reg [31:0] pretrap_mtval;
    reg [63:0] pretrap_mcycle;
    reg [63:0] pretrap_minstret;

    reg        next_mstatus_mie;
    reg        next_mstatus_mpie;
    reg [31:0] next_mie;
    reg [31:0] next_mtvec;
    reg [31:0] next_mscratch;
    reg [31:0] next_mepc;
    reg [31:0] next_mcause;
    reg [31:0] next_mtval;
    reg [63:0] next_mcycle;
    reg [63:0] next_minstret;

    wire [31:0] mstatus_value =
        {19'b0, 2'b11, 3'b0, mstatus_mpie, 3'b0, mstatus_mie, 3'b0};
    wire [31:0] mip_value =
        (irq_external ? 32'h0000_0800 : 32'h0000_0000) |
        (irq_timer    ? 32'h0000_0080 : 32'h0000_0000) |
        (irq_software ? 32'h0000_0008 : 32'h0000_0000);
    wire [31:0] enabled_pending = pretrap_mie & mip_value;

    // Same-cycle mtvec/mepc writes are visible after the retiring CSR.
    assign mtvec_value = pretrap_mtvec;
    assign mepc_value  = pretrap_mepc;

    always @(*) begin
        read_data  = 32'h0000_0000;
        read_valid = 1'b1;
        read_only  = 1'b0;

        case (read_addr)
            CSR_MSTATUS:  read_data = mstatus_value;
            CSR_MISA: begin
                read_data = MISA_VALUE;
                read_only = 1'b1;
            end
            CSR_MIE:      read_data = mie;
            CSR_MTVEC:    read_data = mtvec;
            CSR_MSCRATCH: read_data = mscratch;
            CSR_MEPC:     read_data = mepc;
            CSR_MCAUSE:   read_data = mcause;
            CSR_MTVAL:    read_data = mtval;
            CSR_MIP: begin
                read_data = mip_value;
                read_only = 1'b1;
            end
            CSR_MCYCLE:    read_data = mcycle[31:0];
            CSR_MINSTRET:  read_data = minstret[31:0];
            CSR_MCYCLEH:   read_data = mcycle[63:32];
            CSR_MINSTRETH: read_data = minstret[63:32];
            default: begin
                read_data  = 32'h0000_0000;
                read_valid = 1'b0;
            end
        endcase
    end

    // Compute normal retirement effects first. Counter writes take precedence
    // over their automatic increment in the same cycle.
    always @(*) begin
        pretrap_mstatus_mie  = mstatus_mie;
        pretrap_mstatus_mpie = mstatus_mpie;
        pretrap_mie          = mie;
        pretrap_mtvec        = mtvec;
        pretrap_mscratch     = mscratch;
        pretrap_mepc         = mepc;
        pretrap_mcause       = mcause;
        pretrap_mtval        = mtval;
        pretrap_mcycle       = mcycle + 64'd1;
        pretrap_minstret     = minstret +
                               (instruction_retired ? 64'd1 : 64'd0);

        if (write_enable) begin
            case (write_addr)
                CSR_MSTATUS: begin
                    pretrap_mstatus_mie  = write_data[3];
                    pretrap_mstatus_mpie = write_data[7];
                end
                CSR_MIE:       pretrap_mie = write_data & MIE_MASK;
                CSR_MTVEC:     pretrap_mtvec = {write_data[31:2], 2'b00};
                CSR_MSCRATCH:  pretrap_mscratch = write_data;
                CSR_MEPC:      pretrap_mepc = {write_data[31:2], 2'b00};
                CSR_MCAUSE:    pretrap_mcause = write_data;
                CSR_MTVAL:     pretrap_mtval = write_data;
                CSR_MCYCLE:    pretrap_mcycle[31:0] = write_data;
                CSR_MINSTRET:  pretrap_minstret[31:0] = write_data;
                CSR_MCYCLEH:   pretrap_mcycle[63:32] = write_data;
                CSR_MINSTRETH: pretrap_minstret[63:32] = write_data;
                default: begin
                end
            endcase
        end

        if (mret_commit) begin
            pretrap_mstatus_mie  = mstatus_mpie;
            pretrap_mstatus_mpie = 1'b1;
        end
    end

    // Standard Machine interrupt priority: external, software, then timer.
    always @(*) begin
        interrupt_request = 1'b0;
        interrupt_cause   = 32'h0000_0000;

        if (pretrap_mstatus_mie) begin
            if (enabled_pending[11]) begin
                interrupt_request = 1'b1;
                interrupt_cause   = 32'h8000_000B;
            end else if (enabled_pending[3]) begin
                interrupt_request = 1'b1;
                interrupt_cause   = 32'h8000_0003;
            end else if (enabled_pending[7]) begin
                interrupt_request = 1'b1;
                interrupt_cause   = 32'h8000_0007;
            end
        end
    end

    // Trap entry is applied after retirement effects, preserving a CSR write
    // or MRET that retires on the same boundary as an interrupt.
    always @(*) begin
        next_mstatus_mie  = pretrap_mstatus_mie;
        next_mstatus_mpie = pretrap_mstatus_mpie;
        next_mie          = pretrap_mie;
        next_mtvec        = pretrap_mtvec;
        next_mscratch     = pretrap_mscratch;
        next_mepc         = pretrap_mepc;
        next_mcause       = pretrap_mcause;
        next_mtval        = pretrap_mtval;
        next_mcycle       = pretrap_mcycle;
        next_minstret     = pretrap_minstret;

        if (trap_enter) begin
            next_mstatus_mpie = pretrap_mstatus_mie;
            next_mstatus_mie  = 1'b0;
            next_mepc         = trap_pc & 32'hFFFF_FFFC;
            next_mcause       = trap_cause;
            next_mtval        = trap_value;
        end
    end

    always @(posedge clk) begin
        if (rst) begin
            mstatus_mie  <= 1'b0;
            mstatus_mpie <= 1'b0;
            mie          <= 32'h0000_0000;
            mtvec        <= 32'h0000_0000;
            mscratch     <= 32'h0000_0000;
            mepc         <= 32'h0000_0000;
            mcause       <= 32'h0000_0000;
            mtval        <= 32'h0000_0000;
            mcycle       <= 64'h0000_0000_0000_0000;
            minstret     <= 64'h0000_0000_0000_0000;
        end else begin
            mstatus_mie  <= next_mstatus_mie;
            mstatus_mpie <= next_mstatus_mpie;
            mie          <= next_mie;
            mtvec        <= next_mtvec;
            mscratch     <= next_mscratch;
            mepc         <= next_mepc;
            mcause       <= next_mcause;
            mtval        <= next_mtval;
            mcycle       <= next_mcycle;
            minstret     <= next_minstret;
        end
    end

endmodule
