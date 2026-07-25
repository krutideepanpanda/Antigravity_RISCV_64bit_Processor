// ============================================================================
// AMD ROCm / HSA Architectural Queue Language (AQL) Packet Structures
// Defines standard kernel dispatch packet formats, memory-mapped register
// offsets, fence scopes, and SIMD co-processor interface definitions for RV64I.
// ============================================================================
`ifndef ROCM_DISPATCH_PKT_VH
`define ROCM_DISPATCH_PKT_VH

// ----------------------------------------------------------------------------
// HSA Packet Type Definitions (header[7:0])
// ----------------------------------------------------------------------------
`define HSA_PACKET_TYPE_VENDOR_SPECIFIC 8'd0
`define HSA_PACKET_TYPE_INVALID         8'd1
`define HSA_PACKET_TYPE_KERNEL_DISPATCH 8'd2
`define HSA_PACKET_TYPE_BARRIER_AND     8'd3
`define HSA_PACKET_TYPE_AGENT_DISPATCH  8'd4
`define HSA_PACKET_TYPE_BARRIER_OR      8'd5

// ----------------------------------------------------------------------------
// HSA Memory Fence Scope Definitions (header[9:8] barrier, [11:10] acq, [13:12] rel)
// ----------------------------------------------------------------------------
`define HSA_FENCE_SCOPE_NONE   2'b00
`define HSA_FENCE_SCOPE_AGENT  2'b01
`define HSA_FENCE_SCOPE_SYSTEM 2'b10

// ----------------------------------------------------------------------------
// ROCm Co-Processor Memory-Mapped Register Offsets (Base: 0x8000_0000)
// Address Range: 0x8000_0000 to 0x8000_00FF
// ----------------------------------------------------------------------------
`define ROCM_AQL_PKT_BASE      8'h00 // 0x00 - 0x3F: 64-byte AQL Dispatch Packet
`define ROCM_REG_DOORBELL      8'h40 // Write queue index / doorbell to trigger execution
`define ROCM_REG_STATUS        8'h48 // Status: [0]=active, [1]=irq_pending, [2]=done, [63:32]=cycle_count
`define ROCM_REG_IRQ_ACK       8'h50 // Write 1 to acknowledge and clear rocm_irq
`define ROCM_REG_CTRL          8'h58 // Control: [0]=enable_irq, [1]=reset_accelerator
`define ROCM_REG_VECTOR_ACC0   8'h60 // Read simulated vector SIMD accumulator 0
`define ROCM_REG_VECTOR_ACC1   8'h68 // Read simulated vector SIMD accumulator 1
`define ROCM_REG_VECTOR_ACC2   8'h70 // Read simulated vector SIMD accumulator 2
`define ROCM_REG_VECTOR_ACC3   8'h78 // Read simulated vector SIMD accumulator 3

// ----------------------------------------------------------------------------
// AQL 64-Bit Word Offsets inside 64-Byte Kernel Dispatch Packet
// ----------------------------------------------------------------------------
`define AQL_WORD_HEADER_SETUP  8'h00 // [15:0]=header, [31:16]=setup, [47:32]=wg_x, [63:48]=wg_y
`define AQL_WORD_GRID_XY       8'h08 // [15:0]=wg_z, [31:16]=res0, [63:32]=grid_x
`define AQL_WORD_GRID_Z_SEG    8'h10 // [31:0]=grid_y, [63:32]=grid_z
`define AQL_WORD_SEG_SIZES     8'h18 // [31:0]=private_seg_size, [63:32]=group_seg_size
`define AQL_WORD_KERNEL_OBJ    8'h20 // [63:0]=kernel_object pointer (instruction address)
`define AQL_WORD_KERNARG       8'h28 // [63:0]=kernarg_address pointer (argument payload)
`define AQL_WORD_RESERVED      8'h30 // [63:0]=reserved2
`define AQL_WORD_COMPL_SIG     8'h38 // [63:0]=completion_signal handle (signal address)

// ----------------------------------------------------------------------------
// SystemVerilog Struct Representation for HSA AQL Kernel Dispatch Packet
// ----------------------------------------------------------------------------
`ifdef SYSTEMVERILOG
typedef struct packed {
    logic [63:0] completion_signal;
    logic [63:0] reserved2;
    logic [63:0] kernarg_address;
    logic [63:0] kernel_object;
    logic [31:0] group_segment_size;
    logic [31:0] private_segment_size;
    logic [31:0] grid_size_z;
    logic [31:0] grid_size_y;
    logic [31:0] grid_size_x;
    logic [15:0] reserved0;
    logic [15:0] workgroup_size_z;
    logic [15:0] workgroup_size_y;
    logic [15:0] workgroup_size_x;
    logic [15:0] setup;
    logic [15:0] header;
} hsa_kernel_dispatch_packet_t;
`endif

`endif // ROCM_DISPATCH_PKT_VH
