// ============================================================================
// Data Forwarding Unit
// Resolves EX/MEM and MEM/WB data hazards by controlling ALU input muxes
// ============================================================================
`default_nettype none
`include "rv64i_types.vh"

module rv64i_forwarding (
    input  wire [4:0] ex_rs1_addr,
    input  wire [4:0] ex_rs2_addr,
    input  wire       mem_reg_write,
    input  wire [4:0] mem_rd_addr,
    input  wire       wb_reg_write,
    input  wire [4:0] wb_rd_addr,
    output reg  [1:0] fwd_a_sel,
    output reg  [1:0] fwd_b_sel
);

    // Forwarding for Operand A (rs1)
    always @(*) begin
        if (mem_reg_write && (mem_rd_addr != 5'd0) && (mem_rd_addr == ex_rs1_addr)) begin
            fwd_a_sel = `FWD_EX;
        end else if (wb_reg_write && (wb_rd_addr != 5'd0) && (wb_rd_addr == ex_rs1_addr)) begin
            fwd_a_sel = `FWD_MEM;
        end else begin
            fwd_a_sel = `FWD_NONE;
        end
    end

    // Forwarding for Operand B (rs2)
    always @(*) begin
        if (mem_reg_write && (mem_rd_addr != 5'd0) && (mem_rd_addr == ex_rs2_addr)) begin
            fwd_b_sel = `FWD_EX;
        end else if (wb_reg_write && (wb_rd_addr != 5'd0) && (wb_rd_addr == ex_rs2_addr)) begin
            fwd_b_sel = `FWD_MEM;
        end else begin
            fwd_b_sel = `FWD_NONE;
        end
    end

endmodule
