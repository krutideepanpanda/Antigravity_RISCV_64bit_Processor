// ============================================================================
// Stage 5: Writeback (WB)
// Multiplexes ALU result, Memory read data, and PC+4 (for JAL/JALR) to RegFile
// ============================================================================
`default_nettype none

module rv64i_wb (
    input  wire [63:0] wb_alu_result,
    input  wire [63:0] wb_mem_rdata,
    input  wire [63:0] wb_pc_plus4,
    input  wire        wb_mem_to_reg,
    input  wire        wb_jump,
    output reg  [63:0] wb_rd_data
);

    always @(*) begin
        if (wb_jump) begin
            wb_rd_data = wb_pc_plus4;
        end else if (wb_mem_to_reg) begin
            wb_rd_data = wb_mem_rdata;
        end else begin
            wb_rd_data = wb_alu_result;
        end
    end

endmodule
