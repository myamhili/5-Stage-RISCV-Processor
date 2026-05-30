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

    // Instantiate processor
    risc_processor cpu (
        .clk(clk),
        .rst(btnC),
        .pc_out(pc_out),
        .instruction_out(instruction_out),
        .alu_result_out(alu_result_out),
        .mem_read_data_out(mem_read_data_out),
        .led_out(led_out)
    );

    // Map the lowest 16 bits of the processor's LED output to the physical LEDs
    assign led = led_out[15:0];

endmodule
