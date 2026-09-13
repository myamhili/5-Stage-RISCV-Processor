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
    localparam ALU_XOR    = 4'b0100;
    localparam ALU_SUB_BEQ = 4'b0101;  // Legacy branch subtraction code
    localparam ALU_PASS_B = 4'b0110;
    localparam ALU_SLT    = 4'b0111;
    localparam ALU_SLTU   = 4'b1000;
    localparam ALU_SLL    = 4'b1001;
    localparam ALU_SRL    = 4'b1010;
    localparam ALU_SRA    = 4'b1011;

    always @(*) begin
        case (op)
            ALU_ADD:    result = a + b;           // Addition
            ALU_SUB, 
            ALU_SUB_BEQ: result = a - b;           // Subtraction
            ALU_AND:    result = a & b;           // Bitwise AND
            ALU_OR:     result = a | b;           // Bitwise OR
            ALU_XOR:    result = a ^ b;           // Bitwise XOR
            ALU_PASS_B: result = b;               // Immediate pass-through (LUI)
            ALU_SLT:    result = {31'b0, ($signed(a) < $signed(b))};
            ALU_SLTU:   result = {31'b0, (a < b)};
            ALU_SLL:    result = a << b[4:0];
            ALU_SRL:    result = a >> b[4:0];
            ALU_SRA:    result = $signed(a) >>> b[4:0];
            default:    result = 32'h0;
        endcase
    end

    // Zero flag - used for branch decision
    assign zero = (result == 32'h0);

endmodule
