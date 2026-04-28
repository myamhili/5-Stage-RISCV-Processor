// Program Counter - holds the address of the current instruction

module pc (
    input  wire        clk,        // Clock signal
    input  wire        rst,        // Reset signal
    input  wire        branch,     // Branch taken signal
    input  wire [31:0] branch_addr, // Target address for branch
    output reg  [31:0] pc_out      // Current PC value (output)
);

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            pc_out <= 32'h00000000;  // Reset to start of memory
        end else if (branch) begin
            pc_out <= branch_addr;   // Jump to branch target
        end else begin
            pc_out <= pc_out + 4;    // Increment by 4 (32-bit instruction)
        end
    end

endmodule