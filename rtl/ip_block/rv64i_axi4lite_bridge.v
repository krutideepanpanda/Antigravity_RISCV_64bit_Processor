// ============================================================================
// AMBA AXI4-Lite Master/Slave Bridge for RV64I CPU Core
// Bridges Instruction Memory and Data Memory buses to an AXI4-Lite Master bus.
// Implements priority-based arbitration (DMEM > IMEM) and pipeline stalling.
// ============================================================================
`default_nettype none

module rv64i_axi4lite_bridge #(
    parameter int ADDR_WIDTH = 64,
    parameter int DATA_WIDTH = 64
) (
    // Clock and Reset
    input  wire                      clk,
    input  wire                      rst_n,      // Active-low system reset

    // CPU Instruction Memory Slave Bus
    input  wire [ADDR_WIDTH-1:0]     imem_addr,
    input  wire                      imem_req,   // Instruction fetch request enable
    output reg  [31:0]               imem_rdata,
    output reg                       imem_valid,
    output wire                      imem_stall,

    // CPU Data Memory Slave Bus
    input  wire [ADDR_WIDTH-1:0]     dmem_addr,
    input  wire [DATA_WIDTH-1:0]     dmem_wdata,
    input  wire                      dmem_we,
    input  wire                      dmem_re,
    input  wire [(DATA_WIDTH/8)-1:0] dmem_be,
    output reg  [DATA_WIDTH-1:0]     dmem_rdata,
    output reg                       dmem_valid,
    output wire                      dmem_stall,

    // Unified CPU Pipeline Control
    output wire                      cpu_stall,

    // AMBA AXI4-Lite Master Interface
    // Write Address Channel (AW)
    output reg  [ADDR_WIDTH-1:0]     m_axi_awaddr,
    output reg  [2:0]                m_axi_awprot,
    output reg                       m_axi_awvalid,
    input  wire                      m_axi_awready,

    // Write Data Channel (W)
    output reg  [DATA_WIDTH-1:0]     m_axi_wdata,
    output reg  [(DATA_WIDTH/8)-1:0] m_axi_wstrb,
    output reg                       m_axi_wvalid,
    input  wire                      m_axi_wready,

    // Write Response Channel (B)
    input  wire [1:0]                m_axi_bresp,
    input  wire                      m_axi_bvalid,
    output reg                       m_axi_bready,

    // Read Address Channel (AR)
    output reg  [ADDR_WIDTH-1:0]     m_axi_araddr,
    output reg  [2:0]                m_axi_arprot,
    output reg                       m_axi_arvalid,
    input  wire                      m_axi_arready,

    // Read Data Channel (R)
    input  wire [DATA_WIDTH-1:0]     m_axi_rdata,
    input  wire [1:0]                m_axi_rresp,
    input  wire                      m_axi_rvalid,
    output reg                       m_axi_rready
);

    // Internal reset conversion
    wire rst = ~rst_n;

    // Prevent unused signal warnings for response codes in basic AXI4-Lite
    wire _unused_ok = &{1'b0, m_axi_bresp, m_axi_rresp, 1'b0};

    // FSM State Encoding
    localparam [2:0] STATE_IDLE       = 3'b000;
    localparam [2:0] STATE_READ_AR    = 3'b001;
    localparam [2:0] STATE_READ_R     = 3'b010;
    localparam [2:0] STATE_WRITE_AW_W = 3'b011;
    localparam [2:0] STATE_WRITE_W    = 3'b100;
    localparam [2:0] STATE_WRITE_AW   = 3'b101;
    localparam [2:0] STATE_WRITE_B    = 3'b110;

    reg [2:0] state_reg;

    // Transaction tracking
    reg is_dmem_read;
    reg [ADDR_WIDTH-1:0] last_imem_addr;
    reg last_served_imem;

    // Stall logic: Freeze CPU when a request is pending and data is not yet valid
    assign dmem_stall = (dmem_re || dmem_we) && !dmem_valid;
    assign imem_stall = imem_req && (imem_addr != last_imem_addr || !imem_valid);
    assign cpu_stall  = dmem_stall || imem_stall;

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            state_reg      <= STATE_IDLE;
            m_axi_awaddr   <= {ADDR_WIDTH{1'b0}};
            m_axi_awprot   <= 3'b000;
            m_axi_awvalid  <= 1'b0;
            m_axi_wdata    <= {DATA_WIDTH{1'b0}};
            m_axi_wstrb    <= {(DATA_WIDTH/8){1'b0}};
            m_axi_wvalid   <= 1'b0;
            m_axi_bready   <= 1'b0;
            m_axi_araddr   <= {ADDR_WIDTH{1'b0}};
            m_axi_arprot   <= 3'b000;
            m_axi_arvalid  <= 1'b0;
            m_axi_rready   <= 1'b0;
            imem_rdata     <= 32'h0000_0013; // NOP instruction
            imem_valid     <= 1'b0;
            dmem_rdata     <= {DATA_WIDTH{1'b0}};
            dmem_valid     <= 1'b0;
            is_dmem_read   <= 1'b0;
            last_imem_addr <= {ADDR_WIDTH{1'b1}}; // Reset to invalid address to force initial fetch
            last_served_imem <= 1'b0;
        end else begin
            case (state_reg)
                STATE_IDLE: begin
                    // Clear valid flags when new requests arrive or address changes
                    if (dmem_re || dmem_we) begin
                        dmem_valid <= 1'b0;
                    end
                    if (imem_addr != last_imem_addr) begin
                        imem_valid <= 1'b0;
                    end

                    // QoS Round-Robin Arbitration: prevent DMEM from starving IMEM when both request bus
                    if (imem_req && (imem_addr != last_imem_addr || !imem_valid) && !last_served_imem && (dmem_we || dmem_re)) begin
                        state_reg        <= STATE_READ_AR;
                        is_dmem_read     <= 1'b0;
                        m_axi_araddr     <= imem_addr;
                        m_axi_arprot     <= 3'b100; // Normal, secure, instruction access
                        m_axi_arvalid    <= 1'b1;
                        m_axi_rready     <= 1'b1;
                        imem_valid       <= 1'b0;
                        last_served_imem <= 1'b1;
                    end
                    // Priority 1: Data Memory Write
                    else if (dmem_we) begin
                        state_reg        <= STATE_WRITE_AW_W;
                        m_axi_awaddr     <= dmem_addr;
                        m_axi_awprot     <= 3'b000; // Normal, secure, data access
                        m_axi_awvalid    <= 1'b1;
                        m_axi_wdata      <= dmem_wdata;
                        m_axi_wstrb      <= dmem_be;
                        m_axi_wvalid     <= 1'b1;
                        m_axi_bready     <= 1'b1;
                        dmem_valid       <= 1'b0;
                        last_served_imem <= 1'b0;
                    end
                    // Priority 2: Data Memory Read
                    else if (dmem_re) begin
                        state_reg        <= STATE_READ_AR;
                        is_dmem_read     <= 1'b1;
                        m_axi_araddr     <= dmem_addr;
                        m_axi_arprot     <= 3'b000; // Normal, secure, data access
                        m_axi_arvalid    <= 1'b1;
                        m_axi_rready     <= 1'b1;
                        dmem_valid       <= 1'b0;
                        last_served_imem <= 1'b0;
                    end
                    // Priority 3: Instruction Memory Read
                    else if (imem_req && (imem_addr != last_imem_addr || !imem_valid)) begin
                        state_reg        <= STATE_READ_AR;
                        is_dmem_read     <= 1'b0;
                        m_axi_araddr     <= imem_addr;
                        m_axi_arprot     <= 3'b100; // Normal, secure, instruction access
                        m_axi_arvalid    <= 1'b1;
                        m_axi_rready     <= 1'b1;
                        imem_valid       <= 1'b0;
                        last_served_imem <= 1'b1;
                    end
                end

                STATE_READ_AR: begin
                    if (m_axi_arready && m_axi_arvalid) begin
                        m_axi_arvalid <= 1'b0;
                        state_reg     <= STATE_READ_R;
                    end
                end

                STATE_READ_R: begin
                    if (m_axi_rvalid && m_axi_rready) begin
                        m_axi_rready <= 1'b0;
                        if (is_dmem_read) begin
                            dmem_rdata <= m_axi_rdata;
                            dmem_valid <= 1'b1;
                        end else begin
                            imem_rdata     <= m_axi_rdata[31:0];
                            imem_valid     <= 1'b1;
                            last_imem_addr <= m_axi_araddr;
                        end
                        state_reg <= STATE_IDLE;
                    end
                end

                STATE_WRITE_AW_W: begin
                    case ({m_axi_awready && m_axi_awvalid, m_axi_wready && m_axi_wvalid})
                        2'b11: begin
                            m_axi_awvalid <= 1'b0;
                            m_axi_wvalid  <= 1'b0;
                            state_reg     <= STATE_WRITE_B;
                        end
                        2'b10: begin
                            m_axi_awvalid <= 1'b0;
                            state_reg     <= STATE_WRITE_W;
                        end
                        2'b01: begin
                            m_axi_wvalid  <= 1'b0;
                            state_reg     <= STATE_WRITE_AW;
                        end
                        default: begin
                            // Keep both valid asserted until ready is received
                        end
                    endcase
                end

                STATE_WRITE_W: begin
                    if (m_axi_wready && m_axi_wvalid) begin
                        m_axi_wvalid <= 1'b0;
                        state_reg    <= STATE_WRITE_B;
                    end
                end

                STATE_WRITE_AW: begin
                    if (m_axi_awready && m_axi_awvalid) begin
                        m_axi_awvalid <= 1'b0;
                        state_reg     <= STATE_WRITE_B;
                    end
                end

                STATE_WRITE_B: begin
                    if (m_axi_bvalid && m_axi_bready) begin
                        m_axi_bready <= 1'b0;
                        dmem_valid   <= 1'b1;
                        state_reg    <= STATE_IDLE;
                    end
                end

                default: state_reg <= STATE_IDLE;
            endcase
        end
    end

endmodule
