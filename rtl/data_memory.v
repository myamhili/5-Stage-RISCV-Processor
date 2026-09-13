// Data Memory (RAM) - for lw and sw instructions

module data_memory (
    input  wire        clk,
    input  wire        rst,
    input  wire        we,          // Write enable
    input  wire        re,          // Read enable
    input  wire [31:0] addr,        // Memory address
    input  wire [31:0] write_data,  // Data to write
    input  wire [3:0]  write_strobe,// Byte lanes to write
    output reg  [31:0] read_data,   // Data read from memory
    output reg  [31:0] led_out      // MMIO LED output
);

    localparam GPIO_ADDRESS = 32'h4000_1000;

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
            led_out <= 32'h00000000;
        end else if (we) begin
            if ({addr[31:2], 2'b00} == GPIO_ADDRESS) begin
                if (write_strobe[0])
                    led_out[7:0] <= write_data[7:0];
                if (write_strobe[1])
                    led_out[15:8] <= write_data[15:8];
                if (write_strobe[2])
                    led_out[23:16] <= write_data[23:16];
                if (write_strobe[3])
                    led_out[31:24] <= write_data[31:24];
            end else begin
                if (write_strobe[0])
                    memory[addr[31:2]][7:0] <= write_data[7:0];
                if (write_strobe[1])
                    memory[addr[31:2]][15:8] <= write_data[15:8];
                if (write_strobe[2])
                    memory[addr[31:2]][23:16] <= write_data[23:16];
                if (write_strobe[3])
                    memory[addr[31:2]][31:24] <= write_data[31:24];
            end
        end
    end

    // Asynchronous read
    always @(*) begin
        if (re) begin
            if ({addr[31:2], 2'b00} == GPIO_ADDRESS)
                read_data = led_out;
            else
                read_data = memory[addr[31:2]];
        end else begin
            read_data = 32'h0;
        end
    end

endmodule
