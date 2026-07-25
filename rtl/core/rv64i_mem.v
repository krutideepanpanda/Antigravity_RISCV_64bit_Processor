// ============================================================================
// Stage 4: Memory Access (MEM)
// Data Memory Bus Interface, Byte/Halfword/Word Alignment, MEM/WB Reg
// ============================================================================
`default_nettype none
`include "rv64i_types.vh"

module rv64i_mem (
    input  wire        clk,
    input  wire        rst,
    input  wire [63:0] mem_alu_result,
    input  wire [63:0] mem_wdata,
    input  wire [4:0]  mem_rd_addr,
    input  wire        mem_reg_write,
    input  wire        mem_mem_to_reg,
    input  wire        mem_mem_write,
    input  wire        mem_mem_read,
    input  wire [2:0]  mem_mem_width,
    input  wire [63:0] mem_pc_plus4,
    input  wire        mem_jump,
    // Data Memory Interface
    output wire [63:0] dmem_addr,
    output reg  [63:0] dmem_wdata,
    output wire        dmem_we,
    output wire        dmem_re,
    output reg  [7:0]  dmem_be,
    input  wire [63:0] dmem_rdata,
    // Outputs to WB stage (via MEM/WB register)
    output reg  [63:0] wb_alu_result,
    output reg  [63:0] wb_mem_rdata,
    output reg  [4:0]  wb_rd_addr,
    output reg         wb_reg_write,
    output reg         wb_mem_to_reg,
    output reg  [63:0] wb_pc_plus4,
    output reg         wb_jump
);

    assign dmem_addr = mem_alu_result;
    assign dmem_we   = mem_mem_write;
    assign dmem_re   = mem_mem_read;

    wire [2:0] byte_offset = mem_alu_result[2:0];

    // Formatted Write Data and Byte Enables for Store Instructions
    always @(*) begin
        dmem_be    = 8'b1111_1111;
        dmem_wdata = mem_wdata;

        if (mem_mem_write) begin
            case (mem_mem_width)
                `MEM_BYTE: begin
                    dmem_be    = 8'b0000_0001 << byte_offset;
                    dmem_wdata = {8{mem_wdata[7:0]}};
                end
                `MEM_HALF: begin
                    dmem_be    = 8'b0000_0011 << byte_offset;
                    dmem_wdata = {4{mem_wdata[15:0]}};
                end
                `MEM_WORD: begin
                    dmem_be    = 8'b0000_1111 << byte_offset;
                    dmem_wdata = {2{mem_wdata[31:0]}};
                end
                `MEM_DWORD: begin
                    dmem_be    = 8'b1111_1111;
                    dmem_wdata = mem_wdata;
                end
                default: begin
                    dmem_be    = 8'b1111_1111;
                    dmem_wdata = mem_wdata;
                end
            endcase
        end else if (mem_mem_read) begin
            case (mem_mem_width)
                `MEM_BYTE, `MEM_UBYTE:   dmem_be = 8'b0000_0001 << byte_offset;
                `MEM_HALF, `MEM_UHALF:   dmem_be = 8'b0000_0011 << byte_offset;
                `MEM_WORD, `MEM_UWORD:   dmem_be = 8'b0000_1111 << byte_offset;
                `MEM_DWORD:              dmem_be = 8'b1111_1111;
                default:                 dmem_be = 8'b1111_1111;
            endcase
        end
    end

    // Formatted Read Data for Load Instructions
    reg [63:0] formatted_rdata;
    wire [7:0]  rbyte  = dmem_rdata[8*byte_offset +: 8];
    wire [15:0] rhalf  = dmem_rdata[8*byte_offset +: 16];
    wire [31:0] rword  = dmem_rdata[8*byte_offset +: 32];

    always @(*) begin
        case (mem_mem_width)
            `MEM_BYTE:  formatted_rdata = {{56{rbyte[7]}}, rbyte};
            `MEM_HALF:  formatted_rdata = {{48{rhalf[15]}}, rhalf};
            `MEM_WORD:  formatted_rdata = {{32{rword[31]}}, rword};
            `MEM_DWORD: formatted_rdata = dmem_rdata;
            `MEM_UBYTE: formatted_rdata = {56'b0, rbyte};
            `MEM_UHALF: formatted_rdata = {48'b0, rhalf};
            `MEM_UWORD: formatted_rdata = {32'b0, rword};
            default:    formatted_rdata = dmem_rdata;
        endcase
    end

    // MEM/WB Synchronous Pipeline Register
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            wb_alu_result <= 64'h0;
            wb_mem_rdata  <= 64'h0;
            wb_rd_addr    <= 5'h0;
            wb_reg_write  <= 1'b0;
            wb_mem_to_reg <= 1'b0;
            wb_pc_plus4   <= 64'h0;
            wb_jump       <= 1'b0;
        end else begin
            wb_alu_result <= mem_alu_result;
            wb_mem_rdata  <= formatted_rdata;
            wb_rd_addr    <= mem_rd_addr;
            wb_reg_write  <= mem_reg_write;
            wb_mem_to_reg <= mem_mem_to_reg;
            wb_pc_plus4   <= mem_pc_plus4;
            wb_jump       <= mem_jump;
        end
    end

endmodule
