// ============================================================================
// 32x64-bit General Purpose Register File
// Dual asynchronous read ports, single synchronous write port on posedge clk
// Register x0 is hardwired to 64'h0
// ============================================================================
`default_nettype none

module rv64i_regfile (
    input  wire        clk,
    input  wire        rst,
    input  wire        we,         // Write enable
    input  wire [4:0]  rs1_addr,   // Read port 1 address
    input  wire [4:0]  rs2_addr,   // Read port 2 address
    input  wire [4:0]  rd_addr,    // Write port address
    input  wire [63:0] rd_data,    // Write data
    output wire [63:0] rs1_data,   // Read port 1 data
    output wire [63:0] rs2_data    // Read port 2 data
);

    reg [63:0] registers [0:31];
    integer i;

    // Asynchronous Read with x0 hardwired to 0
    // Optional internal forwarding if reading rd_addr in the same cycle we write
    assign rs1_data = (rs1_addr == 5'd0) ? 64'h0 : registers[rs1_addr];
    assign rs2_data = (rs2_addr == 5'd0) ? 64'h0 : registers[rs2_addr];

    // Synchronous Write
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            for (i = 0; i < 32; i = i + 1) begin
                registers[i] <= 64'h0;
            end
        end else if (we && (rd_addr != 5'd0)) begin
            registers[rd_addr] <= rd_data;
        end
    end

endmodule
