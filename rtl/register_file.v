// Register File - 32 general-purpose registers (x0 to x31)

module register_file (
    input  wire        clk,
    input  wire        rst,
    input  wire        we,          // Write enable
    input  wire [4:0]  read_addr1,  // Read address 1
    input  wire [4:0]  read_addr2,  // Read address 2
    input  wire [4:0]  write_addr,  // Write address
    input  wire [31:0] write_data,  // Data to write
    output wire [31:0] read_data1,  // Data from register 1
    output wire [31:0] read_data2   // Data from register 2
);

    // 32 registers, each 32 bits wide
    reg [31:0] registers [0:31];

    integer i;
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            // Initialize all registers to 0
            for (i = 0; i < 32; i = i + 1) begin
                registers[i] <= 32'h00000000;
            end
        end else if (we && write_addr != 5'b0) begin
            // x0 is hardwired to 0, cannot be written
            registers[write_addr] <= write_data;
        end
    end

    // Read port 1 - asynchronous read with internal forwarding
    assign read_data1 = (read_addr1 == 5'b0) ? 32'h0 : 
                        (we && (write_addr == read_addr1)) ? write_data : 
                        registers[read_addr1];
    
    // Read port 2 - asynchronous read with internal forwarding
    assign read_data2 = (read_addr2 == 5'b0) ? 32'h0 : 
                        (we && (write_addr == read_addr2)) ? write_data : 
                        registers[read_addr2];

endmodule