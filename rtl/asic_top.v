// ============================================================================
// Synthesizable ASIC Top-Level Wrapper for OpenLane / SkyWater 130nm Tape-Out
// Features registered I/O boundaries for predictable static timing analysis (STA)
// and Wishbone / SRAM bus interfacing
// ============================================================================
`default_nettype none

module asic_top (
    input  wire        clk,
    input  wire        rst_n,          // Active-low external reset
    // Instruction Memory Bus Interface
    output reg  [63:0] imem_addr_out,
    input  wire [31:0] imem_rdata_in,
    // Data Memory Bus Interface
    output reg  [63:0] dmem_addr_out,
    output reg  [63:0] dmem_wdata_out,
    output reg         dmem_we_out,
    output reg         dmem_re_out,
    output reg  [7:0]  dmem_be_out,
    input  wire [63:0] dmem_rdata_in
);

    wire rst = ~rst_n; // Convert active-low external reset to internal active-high

    wire [63:0] cpu_imem_addr;
    wire [63:0] cpu_dmem_addr;
    wire [63:0] cpu_dmem_wdata;
    wire        cpu_dmem_we;
    wire        cpu_dmem_re;
    wire [7:0]  cpu_dmem_be;

    // Registered Input Data from External Memory
    reg [31:0] imem_rdata_reg;
    reg [63:0] dmem_rdata_reg;

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            imem_rdata_reg <= 32'h0000_0013; // NOP
            dmem_rdata_reg <= 64'h0;
        end else begin
            imem_rdata_reg <= imem_rdata_in;
            dmem_rdata_reg <= dmem_rdata_in;
        end
    end

    // Instantiate RV64I CPU Core
    rv64i_cpu u_cpu (
        .clk        (clk),
        .rst        (rst),
        .imem_addr  (cpu_imem_addr),
        .imem_rdata (imem_rdata_reg),
        .dmem_addr  (cpu_dmem_addr),
        .dmem_wdata (cpu_dmem_wdata),
        .dmem_we    (cpu_dmem_we),
        .dmem_re    (cpu_dmem_re),
        .dmem_be    (cpu_dmem_be),
        .dmem_rdata (dmem_rdata_reg)
    );

    // Registered Output Bus to External Memory
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            imem_addr_out  <= 64'h0;
            dmem_addr_out  <= 64'h0;
            dmem_wdata_out <= 64'h0;
            dmem_we_out    <= 1'b0;
            dmem_re_out    <= 1'b0;
            dmem_be_out    <= 8'h0;
        end else begin
            imem_addr_out  <= cpu_imem_addr;
            dmem_addr_out  <= cpu_dmem_addr;
            dmem_wdata_out <= cpu_dmem_wdata;
            dmem_we_out    <= cpu_dmem_we;
            dmem_re_out    <= cpu_dmem_re;
            dmem_be_out    <= cpu_dmem_be;
        end
    end

endmodule
