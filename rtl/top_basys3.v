module top_basys3 (
    input  wire        clk,
    input  wire        btnC, // Center button for reset
    output wire [15:0] led   // 16 LEDs on the Basys 3
);

    // Unconnected outputs from processor
    wire [31:0] pc_out;
    wire [31:0] instruction_out;
    wire [31:0] alu_result_out;
    wire [31:0] mem_read_data_out;
    wire [31:0] led_out;

    // Accept an asynchronous board button, then release reset only on clock
    // edges.  The processor itself therefore sees a clean synchronous reset.
    reg [1:0] reset_sync = 2'b11;
    always @(posedge clk or posedge btnC) begin
        if (btnC)
            reset_sync <= 2'b11;
        else
            reset_sync <= {reset_sync[0], 1'b0};
    end
    wire core_rst = reset_sync[1];

    // Instantiate processor
    risc_processor cpu (
        .clk(clk),
        .rst(core_rst),
        .irq_software(1'b0),
        .irq_timer(1'b0),
        .irq_external(1'b0),
        .pc_out(pc_out),
        .instruction_out(instruction_out),
        .alu_result_out(alu_result_out),
        .mem_read_data_out(mem_read_data_out),
        .led_out(led_out),

        .retire_valid         (),
        .retire_pc            (),
        .retire_instruction   (),
        .retire_rd_we         (),
        .retire_rd_addr       (),
        .retire_rd_data       (),

        .retire_mem_valid     (),
        .retire_mem_write     (),
        .retire_mem_addr      (),
        .retire_mem_wdata     (),
        .retire_mem_wstrb     (),

        .trap_valid           (),
        .trap_pc              (),
        .trap_instruction     (),
        .trap_cause           (),
        .trap_tval            ()
    );

    // Map the lowest 16 bits of the processor's LED output to the physical LEDs
    assign led = led_out[15:0];

endmodule
