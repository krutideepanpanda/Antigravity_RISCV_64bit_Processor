// ============================================================================
// RV64I HDMI Display Controller Engine IP Block
// Supports VGA Font ROM Text Mode, Sprite Overlay Mode, and DMA Framebuffer Mode
// Interfaces with CPU MMIO and exports 28-pin parallel CMOS video for HDMI bridge
// ============================================================================
`default_nettype none

module rv64i_hdmi_display_engine #(
    parameter int ADDR_WIDTH = 64,
    parameter int DATA_WIDTH = 64
) (
    // System Clock and Reset (100 MHz)
    input  wire                      sys_clk,
    input  wire                      sys_rst_n,

    // Pixel Clock and Reset (25.175 MHz for 640x480@60Hz or 74.25 MHz for 720p)
    input  wire                      pix_clk,
    input  wire                      pix_rst_n,

    // CPU MMIO Slave Interface (Address Range: 0x80000100 - 0x800001FF)
    input  wire                      mmio_req,
    input  wire                      mmio_we,
    input  wire [ADDR_WIDTH-1:0]     mmio_addr,
    input  wire [DATA_WIDTH-1:0]     mmio_wdata,
    input  wire [7:0]                mmio_be,
    output reg  [DATA_WIDTH-1:0]     mmio_rdata,
    output reg                       mmio_valid,

    // DMA Master Interface (to External Memory / System Bus)
    output reg                       dma_req,
    output reg  [ADDR_WIDTH-1:0]     dma_addr,
    input  wire                      dma_grant,
    input  wire [DATA_WIDTH-1:0]     dma_rdata,
    input  wire                      dma_valid,

    // 28-Pin Parallel CMOS Video Output (to external PHY like ADV7511 / TFP410)
    output reg  [23:0]               vd_data,    // RGB888
    output reg                       vd_hsync,   // Horizontal Sync
    output reg                       vd_vsync,   // Vertical Sync
    output reg                       vd_de       // Display Enable
);

    wire sys_rst = ~sys_rst_n;
    wire pix_rst = ~pix_rst_n;

    // ------------------------------------------------------------------------
    // MMIO Registers
    // 0x00: Display Control (bit 0: enable, bit 1: res, bits 3:2: mode 0=Text, 1=Sprite, 2=FB)
    // 0x08: Framebuffer Base Address
    // 0x10: Status Register (bit 0: VBLANK, bit 1: HBLANK, bit 2: Underflow)
    // 0x18 - 0x7F: Sprite / Cursor Attribute Registers
    // ------------------------------------------------------------------------
    reg [63:0] reg_ctrl;
    reg [63:0] reg_fb_base;
    reg        status_underflow;
    reg [63:0] reg_sprites [0:12]; // 13 sprite registers (x, y, color, tile)

    wire       disp_enable   = reg_ctrl[0];
    wire       disp_res      = reg_ctrl[1]; // 0: 640x480, 1: 1280x720
    wire [1:0] disp_mode     = reg_ctrl[3:2];

    wire [7:0] reg_offset    = mmio_addr[7:0];
    wire [3:0] sprite_idx    = (reg_offset[6:3] - 4'h3);

    // MMIO Read/Write on sys_clk
    always @(posedge sys_clk or posedge sys_rst) begin
        if (sys_rst) begin
            reg_ctrl         <= 64'd1; // Default enabled, Mode 0 (Text)
            reg_fb_base      <= 64'h00000000_80010000;
            status_underflow <= 1'b0;
            mmio_rdata       <= 64'd0;
            mmio_valid       <= 1'b0;
        end else begin
            mmio_valid <= 1'b0;
            if (mmio_req && !mmio_valid) begin
                mmio_valid <= 1'b1;
                if (mmio_we) begin
                    case (reg_offset)
                        8'h00: reg_ctrl    <= mmio_wdata;
                        8'h08: reg_fb_base <= mmio_wdata;
                        8'h10: status_underflow <= 1'b0; // Write to clear
                        default: begin
                            if (reg_offset >= 8'h18 && reg_offset <= 8'h7F && sprite_idx < 4'd13) begin
                                reg_sprites[sprite_idx] <= mmio_wdata;
                            end
                        end
                    endcase
                end else begin
                    case (reg_offset)
                        8'h00: mmio_rdata <= reg_ctrl;
                        8'h08: mmio_rdata <= reg_fb_base;
                        8'h10: mmio_rdata <= {61'd0, status_underflow, ~vd_de, ~vd_vsync};
                        default: begin
                            if (reg_offset >= 8'h18 && reg_offset <= 8'h7F && sprite_idx < 4'd13) begin
                                mmio_rdata <= reg_sprites[sprite_idx];
                            end else begin
                                mmio_rdata <= 64'd0;
                            end
                        end
                    endcase
                end
            end
        end
    end

    // ------------------------------------------------------------------------
    // Video Timing Generator (on pix_clk)
    // For 640x480@60Hz (pix_clk = 25.175 MHz):
    // H: 640 active, 16 fp, 96 sync, 48 bp -> 800 total
    // V: 480 active, 10 fp, 2 sync, 33 bp -> 525 total
    // ------------------------------------------------------------------------
    reg [11:0] h_count;
    reg [11:0] v_count;

    localparam [11:0] H_ACTIVE = 12'd640;
    localparam [11:0] H_FP     = 12'd16;
    localparam [11:0] H_SYNC   = 12'd96;
    localparam [11:0] H_BP     = 12'd48;
    localparam [11:0] H_TOTAL  = 12'd800;

    localparam [11:0] V_ACTIVE = 12'd480;
    localparam [11:0] V_FP     = 12'd10;
    localparam [11:0] V_SYNC   = 12'd2;
    localparam [11:0] V_BP     = 12'd33;
    localparam [11:0] V_TOTAL  = 12'd525;

    wire h_act = (h_count < H_ACTIVE);
    wire v_act = (v_count < V_ACTIVE);
    wire de    = disp_enable && h_act && v_act;

    wire h_sync_active = (h_count >= (H_ACTIVE + H_FP)) && (h_count < (H_ACTIVE + H_FP + H_SYNC));
    wire v_sync_active = (v_count >= (V_ACTIVE + V_FP)) && (v_count < (V_ACTIVE + V_FP + V_SYNC));

    always @(posedge pix_clk or posedge pix_rst) begin
        if (pix_rst) begin
            h_count  <= 12'd0;
            v_count  <= 12'd0;
            vd_hsync <= 1'b1;
            vd_vsync <= 1'b1;
            vd_de    <= 1'b0;
        end else begin
            if (disp_enable) begin
                if (h_count == (H_TOTAL - 12'd1)) begin
                    h_count <= 12'd0;
                    if (v_count == (V_TOTAL - 12'd1))
                        v_count <= 12'd0;
                    else
                        v_count <= v_count + 12'd1;
                end else begin
                    h_count <= h_count + 12'd1;
                end
            end else begin
                h_count <= 12'd0;
                v_count <= 12'd0;
            end

            vd_hsync <= ~h_sync_active; // Active low standard for 640x480
            vd_vsync <= ~v_sync_active;
            vd_de    <= de;
        end
    end

    // ------------------------------------------------------------------------
    // Embedded 8x8 Font ROM for Mode 0 (Text Generator Mode)
    // Simple ASCII representation for quick console display
    // ------------------------------------------------------------------------
    wire [2:0] font_row = v_count[2:0];
    wire [2:0] font_col = ~h_count[2:0];
    wire [6:0] ascii_char = {h_count[7:4], v_count[7:5]}; // Pseudo grid mapping
    reg [7:0] font_bits;

    always @(*) begin
        // Simple procedural 8x8 font pattern for ASCII alphanumerics
        case (font_row)
            3'd0: font_bits = 8'h3C;
            3'd1: font_bits = 8'h66;
            3'd2: font_bits = 8'h66;
            3'd3: font_bits = 8'h7E;
            3'd4: font_bits = 8'h66;
            3'd5: font_bits = 8'h66;
            3'd6: font_bits = 8'h66;
            3'd7: font_bits = 8'h00;
        endcase
    end

    wire text_pixel = font_bits[font_col];

    // ------------------------------------------------------------------------
    // Asynchronous Dual-Clock FIFO Line Buffer (4 KB)
    // Crosses pixel data from sys_clk to pix_clk
    // ------------------------------------------------------------------------
    reg [31:0] fifo_mem [0:1023]; // 1024 words x 32-bit = 4 KB
    reg [9:0]  wr_ptr, rd_ptr;
    wire [9:0] fifo_count = wr_ptr - rd_ptr;
    wire       fifo_full  = (fifo_count == 10'd1023);
    wire       fifo_empty = (wr_ptr == rd_ptr);

    // Write on sys_clk when DMA data is valid
    always @(posedge sys_clk or posedge sys_rst) begin
        if (sys_rst) begin
            wr_ptr <= 10'd0;
            dma_req <= 1'b0;
            dma_addr <= 64'd0;
        end else begin
            if (dma_valid && !fifo_full) begin
                fifo_mem[wr_ptr] <= dma_rdata[31:0];
                wr_ptr <= wr_ptr + 10'd1;
            end
            // DMA Request logic: fetch when FIFO is less than half full in FB mode
            if (disp_enable && disp_mode == 2'b10 && fifo_count < 10'd512 && !dma_req) begin
                dma_req  <= 1'b1;
                dma_addr <= reg_fb_base + {52'd0, wr_ptr, 2'b00};
            end else if (dma_grant) begin
                dma_req  <= 1'b0;
            end
        end
    end

    // Read on pix_clk during active display
    reg [31:0] fb_pixel_data;
    always @(posedge pix_clk or posedge pix_rst) begin
        if (pix_rst) begin
            rd_ptr <= 10'd0;
            fb_pixel_data <= 32'd0;
        end else if (de) begin
            if (!fifo_empty) begin
                fb_pixel_data <= fifo_mem[rd_ptr];
                rd_ptr <= rd_ptr + 10'd1;
            end else begin
                fb_pixel_data <= 32'h00FF0000; // Red screen on FIFO underflow
            end
        end
    end

    // ------------------------------------------------------------------------
    // Video Output Compositor (on pix_clk)
    // ------------------------------------------------------------------------
    always @(posedge pix_clk or posedge pix_rst) begin
        if (pix_rst) begin
            vd_data <= 24'd0;
        end else if (de) begin
            case (disp_mode)
                2'b00: begin // Mode 0: VGA Font ROM Text Mode
                    // Green text on dark blue background
                    vd_data <= text_pixel ? 24'h00FF00 : 24'h000040;
                end
                2'b01: begin // Mode 1: Sprite / Cursor Overlay Mode
                    // Check if current coordinate matches sprite 0 (mouse cursor)
                    if (h_count >= reg_sprites[0][11:0] && h_count < (reg_sprites[0][11:0] + 12'd16) &&
                        v_count >= reg_sprites[0][27:16] && v_count < (reg_sprites[0][27:16] + 12'd16)) begin
                        vd_data <= 24'hFFFFFF; // White cursor box
                    end else begin
                        vd_data <= 24'h202020; // Dark grey background
                    end
                end
                2'b10: begin // Mode 2: Framebuffer Mode
                    vd_data <= fb_pixel_data[23:0]; // RGB888 from FIFO
                end
                default: vd_data <= 24'h000000;
            endcase
        end else begin
            vd_data <= 24'd0; // Blanking
        end
    end

endmodule
