// Arithmetic Logic Unit (ALU)

module alu (
    input  wire [31:0] a,           // Operand A
    input  wire [31:0] b,           // Operand B
    input  wire [3:0]  op,          // Operation select
    output reg  [31:0] result,      // ALU result
    output wire        zero         // Zero flag (result == 0)
);

    // ALU operations
    localparam ALU_ADD  = 4'b0000;
    localparam ALU_SUB  = 4'b0001;
    localparam ALU_AND  = 4'b0010;
    localparam ALU_OR   = 4'b0011;
    localparam ALU_XOR  = 4'b0100;
    localparam ALU_SUB_BEQ = 4'b0101;  // For branch comparison

    always @(*) begin
        case (op)
            ALU_ADD:    result = a + b;           // Addition
            ALU_SUB, 
            ALU_SUB_BEQ: result = a - b;           // Subtraction
            ALU_AND:    result = a & b;           // Bitwise AND
            ALU_OR:     result = a | b;           // Bitwise OR
            ALU_XOR:    result = a ^ b;           // Bitwise XOR
            default:    result = 32'h0;
        endcase
    end

    // Zero flag - used for branch decision
    assign zero = (result == 32'h0);

endmodule