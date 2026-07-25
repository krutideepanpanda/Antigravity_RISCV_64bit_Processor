// ============================================================================
// AMD ROCm / HIP / HSA C Runtime Driver Library for RISC-V (RV64I)
// Provides heterogenous compute APIs: hipMalloc, hipMemcpy, hipLaunchKernelGGL,
// hsa_queue_create, and hsa_kernel_dispatch for memory-mapped co-processors.
// ============================================================================
#ifndef ROCM_RISCV_RUNTIME_H
#define ROCM_RISCV_RUNTIME_H

#include <stdint.h>
#include <stddef.h>
#include <stdbool.h>

#ifdef __cplusplus
extern "C" {
#endif

// ----------------------------------------------------------------------------
// ROCm Hardware Accelerator Physical Base Address & Register Offsets
// ----------------------------------------------------------------------------
#define ROCM_ACCEL_BASE_ADDR        0x80000000ULL
#define ROCM_REG_OFFSET_DOORBELL    0x40
#define ROCM_REG_OFFSET_STATUS      0x48
#define ROCM_REG_OFFSET_IRQ_ACK     0x50
#define ROCM_REG_OFFSET_CTRL        0x58
#define ROCM_REG_OFFSET_VEC_ACC0    0x60
#define ROCM_REG_OFFSET_VEC_ACC1    0x68

// ----------------------------------------------------------------------------
// HSA Status Codes and Packet Constants
// ----------------------------------------------------------------------------
typedef enum {
    HSA_STATUS_SUCCESS = 0,
    HSA_STATUS_ERROR = 1,
    HSA_STATUS_ERROR_OUT_OF_RESOURCES = 2,
    HSA_STATUS_ERROR_INVALID_ARGUMENT = 3
} hsa_status_t;

#define HSA_PACKET_TYPE_KERNEL_DISPATCH 2
#define HSA_FENCE_SCOPE_SYSTEM          2
#define HSA_PACKET_HEADER_CREATE(type, barrier, acq, rel) \
    ((type & 0xFF) | ((barrier & 1) << 8) | ((acq & 3) << 10) | ((rel & 3) << 12))
#define HSA_KERNEL_DISPATCH_SETUP_CREATE(dims) (dims & 0x3)

// ----------------------------------------------------------------------------
// HSA Architectural Queue Language (AQL) Kernel Dispatch Packet
// Exactly 64 bytes (aligned to 64-bit word boundaries for Wishbone/RV64 bus)
// ----------------------------------------------------------------------------
typedef struct hsa_kernel_dispatch_packet_s {
    uint16_t header;
    uint16_t setup;
    uint16_t workgroup_size_x;
    uint16_t workgroup_size_y;
    uint16_t workgroup_size_z;
    uint16_t reserved0;
    uint32_t grid_size_x;
    uint32_t grid_size_y;
    uint32_t grid_size_z;
    uint32_t private_segment_size;
    uint32_t group_segment_size;
    uint64_t kernel_object;
    uint64_t kernarg_address;
    uint64_t reserved2;
    uint64_t completion_signal;
} __attribute__((aligned(8))) hsa_kernel_dispatch_packet_t;

// ----------------------------------------------------------------------------
// HSA Queue Structure
// ----------------------------------------------------------------------------
typedef struct hsa_queue_s {
    uint32_t type;
    uint32_t features;
    volatile uint64_t* base_address;
    volatile uint32_t* doorbell_signal;
    uint32_t size;
    uint32_t id;
} hsa_queue_t;

// ----------------------------------------------------------------------------
// HIP (Heterogeneous-compute Interface for Portability) Types
// ----------------------------------------------------------------------------
typedef enum {
    hipSuccess = 0,
    hipErrorMemoryAllocation = 1,
    hipErrorInvalidValue = 2,
    hipErrorLaunchFailure = 3
} hipError_t;

typedef enum {
    hipMemcpyHostToDevice = 1,
    hipMemcpyDeviceToHost = 2,
    hipMemcpyDeviceToDevice = 3
} hipMemcpyKind;

typedef struct {
    uint32_t x;
    uint32_t y;
    uint32_t z;
} dim3;

typedef void* hipStream_t;

// ----------------------------------------------------------------------------
// Core HSA Runtime API Declarations
// ----------------------------------------------------------------------------
hsa_status_t hsa_queue_create(uint32_t size, uint32_t type, hsa_queue_t** queue);
hsa_status_t hsa_queue_destroy(hsa_queue_t* queue);
hsa_status_t hsa_kernel_dispatch(hsa_queue_t* queue, const hsa_kernel_dispatch_packet_t* packet);

// ----------------------------------------------------------------------------
// Core HIP Runtime API Declarations
// ----------------------------------------------------------------------------
hipError_t hipMalloc(void** devPtr, size_t size);
hipError_t hipFree(void* devPtr);
hipError_t hipMemcpy(void* dst, const void* src, size_t sizeBytes, hipMemcpyKind kind);
hipError_t hipLaunchKernelGGL(const void* func, dim3 gridDim, dim3 blockDim,
                              uint32_t sharedMem, hipStream_t stream, void** args);

// ----------------------------------------------------------------------------
// ROCm Co-Processor Hardware Driver Helpers
// ----------------------------------------------------------------------------
void rocm_init_accelerator(uint64_t base_addr);
uint64_t rocm_read_status(void);
bool rocm_is_kernel_active(void);
bool rocm_is_irq_pending(void);
void rocm_ack_irq(void);
uint64_t rocm_read_vector_acc(uint32_t index);

#ifdef __cplusplus
}
#endif

#endif // ROCM_RISCV_RUNTIME_H
