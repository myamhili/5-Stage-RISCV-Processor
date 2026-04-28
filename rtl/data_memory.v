// Data Memory (RAM) - for lw and sw instructions

module data_memory (
    input  wire        clk,
    input  wire        rst,
    input  wire        we,          // Write enable
    input  wire        re,          // Read enable
    input  wire [31:0] addr,        // Memory address
    input  wire [31:0] write_data,  // Data to write
    output reg  [31:0] read_data    // Data read from memory
);

    // 64 words of data memory (256 bytes)
    reg [31:0] memory [0:63];

    integer i;
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            // Initialize memory to 0
            for (i = 0; i < 64; i = i + 1) begin
                memory[i] <= 32'h00000000;
            end
            // Initialize some test data
            memory[0] <= 32'h000000AA;  // Test data at address 0
            memory[1] <= 32'h00000055;  // Test data at address 4
            memory[2] <= 32'h000000FF;  // Test data at address 8
        end else if (we) begin
            // Write data at word-aligned address
            memory[addr[31:2]] <= write_data;
        end
    end

    // Asynchronous read
    always @(*) begin
        if (re)
            read_data = memory[addr[31:2]];
        else
            read_data = 32'h0;
    end

endmodule