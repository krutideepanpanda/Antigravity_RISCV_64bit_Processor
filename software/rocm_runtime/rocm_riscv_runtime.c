// ============================================================================
// AMD ROCm / HIP / HSA C Runtime Driver Library Implementation for RISC-V
// Implements freestanding GPU memory management, HSA AQL packet generation,
// queue dispatching, and co-processor hardware register interfacing.
// ============================================================================
#include "rocm_riscv_runtime.h"

// ----------------------------------------------------------------------------
// Internal Driver State & Freestanding Memory Pool
// ----------------------------------------------------------------------------
static uint64_t g_rocm_base_addr = ROCM_ACCEL_BASE_ADDR;

#define GPU_MEM_POOL_SIZE 65536
static uint8_t g_gpu_mem_pool[GPU_MEM_POOL_SIZE] __attribute__((aligned(8)));
static size_t g_gpu_mem_offset = 0;

static hsa_queue_t g_default_queue;
static bool g_queue_initialized = false;

// ----------------------------------------------------------------------------
// ROCm Co-Processor Hardware Driver Helpers
// ----------------------------------------------------------------------------
void rocm_init_accelerator(uint64_t base_addr) {
    g_rocm_base_addr = base_addr;
}

uint64_t rocm_read_status(void) {
    volatile uint64_t* status_reg = (volatile uint64_t*)(uintptr_t)(g_rocm_base_addr + ROCM_REG_OFFSET_STATUS);
    return *status_reg;
}

bool rocm_is_kernel_active(void) {
    uint64_t status = rocm_read_status();
    return (status & 1ULL) != 0;
}

bool rocm_is_irq_pending(void) {
    uint64_t status = rocm_read_status();
    return (status & 2ULL) != 0;
}

void rocm_ack_irq(void) {
    volatile uint64_t* ack_reg = (volatile uint64_t*)(uintptr_t)(g_rocm_base_addr + ROCM_REG_OFFSET_IRQ_ACK);
    *ack_reg = 1ULL;
}

uint64_t rocm_read_vector_acc(uint32_t index) {
    uint64_t offset = ROCM_REG_OFFSET_VEC_ACC0 + (index * 8ULL);
    volatile uint64_t* acc_reg = (volatile uint64_t*)(uintptr_t)(g_rocm_base_addr + offset);
    return *acc_reg;
}

// ----------------------------------------------------------------------------
// Core HSA Runtime API Implementation
// ----------------------------------------------------------------------------
hsa_status_t hsa_queue_create(uint32_t size, uint32_t type, hsa_queue_t** queue) {
    if (!queue) {
        return HSA_STATUS_ERROR_INVALID_ARGUMENT;
    }

    g_default_queue.type = type;
    g_default_queue.features = 0;
    g_default_queue.base_address = (volatile uint64_t*)(uintptr_t)g_rocm_base_addr;
    g_default_queue.doorbell_signal = (volatile uint32_t*)(uintptr_t)(g_rocm_base_addr + ROCM_REG_OFFSET_DOORBELL);
    g_default_queue.size = size;
    g_default_queue.id = 1;

    g_queue_initialized = true;
    *queue = &g_default_queue;
    return HSA_STATUS_SUCCESS;
}

hsa_status_t hsa_queue_destroy(hsa_queue_t* queue) {
    if (!queue) {
        return HSA_STATUS_ERROR_INVALID_ARGUMENT;
    }
    g_queue_initialized = false;
    return HSA_STATUS_SUCCESS;
}

hsa_status_t hsa_kernel_dispatch(hsa_queue_t* queue, const hsa_kernel_dispatch_packet_t* packet) {
    if (!queue || !packet || !queue->base_address || !queue->doorbell_signal) {
        return HSA_STATUS_ERROR_INVALID_ARGUMENT;
    }

    // Write 64-byte AQL packet as 8 consecutive 64-bit words to co-processor queue
    volatile uint64_t* dst = queue->base_address;
    const uint64_t* src = (const uint64_t*)packet;

    for (int i = 0; i < 8; i++) {
        dst[i] = src[i];
    }

    // Ring hardware doorbell register to trigger kernel execution on accelerator
    *(queue->doorbell_signal) = queue->id++;

    return HSA_STATUS_SUCCESS;
}

// ----------------------------------------------------------------------------
// Core HIP Runtime API Implementation
// ----------------------------------------------------------------------------
hipError_t hipMalloc(void** devPtr, size_t size) {
    if (!devPtr || size == 0) {
        return hipErrorInvalidValue;
    }

    // Align allocation to 8-byte boundary
    size_t aligned_size = (size + 7) & ~7ULL;
    if (g_gpu_mem_offset + aligned_size > GPU_MEM_POOL_SIZE) {
        return hipErrorMemoryAllocation;
    }

    *devPtr = &g_gpu_mem_pool[g_gpu_mem_offset];
    g_gpu_mem_offset += aligned_size;
    return hipSuccess;
}

hipError_t hipFree(void* devPtr) {
    // In our freestanding static pool, free is a no-op unless resetting all pool
    (void)devPtr;
    return hipSuccess;
}

hipError_t hipMemcpy(void* dst, const void* src, size_t sizeBytes, hipMemcpyKind kind) {
    if (!dst || !src) {
        return hipErrorInvalidValue;
    }
    (void)kind; // Unified memory model: host and device memory share physical address space

    uint8_t* d = (uint8_t*)dst;
    const uint8_t* s = (const uint8_t*)src;
    for (size_t i = 0; i < sizeBytes; i++) {
        d[i] = s[i];
    }
    return hipSuccess;
}

hipError_t hipLaunchKernelGGL(const void* func, dim3 gridDim, dim3 blockDim,
                              uint32_t sharedMem, hipStream_t stream, void** args) {
    (void)stream;

    if (!g_queue_initialized) {
        hsa_queue_t* q = NULL;
        hsa_status_t status = hsa_queue_create(64, 0, &q);
        if (status != HSA_STATUS_SUCCESS) {
            return hipErrorLaunchFailure;
        }
    }

    hsa_kernel_dispatch_packet_t pkt;
    for (int i = 0; i < 8; i++) {
        ((uint64_t*)&pkt)[i] = 0ULL;
    }

    pkt.header = HSA_PACKET_HEADER_CREATE(HSA_PACKET_TYPE_KERNEL_DISPATCH, 1,
                                          HSA_FENCE_SCOPE_SYSTEM, HSA_FENCE_SCOPE_SYSTEM);
    pkt.setup  = HSA_KERNEL_DISPATCH_SETUP_CREATE(3); // 3D dimensions

    pkt.workgroup_size_x = (uint16_t)blockDim.x;
    pkt.workgroup_size_y = (uint16_t)blockDim.y;
    pkt.workgroup_size_z = (uint16_t)blockDim.z;

    pkt.grid_size_x = gridDim.x * blockDim.x;
    pkt.grid_size_y = gridDim.y * blockDim.y;
    pkt.grid_size_z = gridDim.z * blockDim.z;

    pkt.group_segment_size   = sharedMem;
    pkt.private_segment_size = 0;

    pkt.kernel_object   = (uint64_t)(uintptr_t)func;
    pkt.kernarg_address = (uint64_t)(uintptr_t)args;
    pkt.completion_signal = 0ULL;

    hsa_status_t status = hsa_kernel_dispatch(&g_default_queue, &pkt);
    if (status != HSA_STATUS_SUCCESS) {
        return hipErrorLaunchFailure;
    }

    return hipSuccess;
}
