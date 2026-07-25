#!/usr/bin/env python3
"""
RV64I Directed Test Suite Generator
Generates machine-code hex files for verification test suites in verif/tests/
"""
import os

def create_dir(path):
    os.makedirs(path, exist_ok=True)

# Helper functions for encoding RISC-V instructions into 32-bit hex strings
def addi(rd, rs1, imm):
    imm &= 0xFFF
    return f"{((imm << 20) | (rs1 << 15) | (0b000 << 12) | (rd << 7) | 0b0010011):08x}"

def addiw(rd, rs1, imm):
    imm &= 0xFFF
    return f"{((imm << 20) | (rs1 << 15) | (0b000 << 12) | (rd << 7) | 0b0011011):08x}"

def add(rd, rs1, rs2):
    return f"{((0b0000000 << 25) | (rs2 << 20) | (rs1 << 15) | (0b000 << 12) | (rd << 7) | 0b0110011):08x}"

def sub(rd, rs1, rs2):
    return f"{((0b0100000 << 25) | (rs2 << 20) | (rs1 << 15) | (0b000 << 12) | (rd << 7) | 0b0110011):08x}"

def xor_op(rd, rs1, rs2):
    return f"{((0b0000000 << 25) | (rs2 << 20) | (rs1 << 15) | (0b100 << 12) | (rd << 7) | 0b0110011):08x}"

def or_op(rd, rs1, rs2):
    return f"{((0b0000000 << 25) | (rs2 << 20) | (rs1 << 15) | (0b110 << 12) | (rd << 7) | 0b0110011):08x}"

def and_op(rd, rs1, rs2):
    return f"{((0b0000000 << 25) | (rs2 << 20) | (rs1 << 15) | (0b111 << 12) | (rd << 7) | 0b0110011):08x}"

def sll(rd, rs1, rs2):
    return f"{((0b0000000 << 25) | (rs2 << 20) | (rs1 << 15) | (0b001 << 12) | (rd << 7) | 0b0110011):08x}"

def sllw(rd, rs1, rs2):
    return f"{((0b0000000 << 25) | (rs2 << 20) | (rs1 << 15) | (0b001 << 12) | (rd << 7) | 0b0111011):08x}"

def addw(rd, rs1, rs2):
    return f"{((0b0000000 << 25) | (rs2 << 20) | (rs1 << 15) | (0b000 << 12) | (rd << 7) | 0b0111011):08x}"

def subw(rd, rs1, rs2):
    return f"{((0b0100000 << 25) | (rs2 << 20) | (rs1 << 15) | (0b000 << 12) | (rd << 7) | 0b0111011):08x}"

def lui(rd, imm20):
    return f"{(((imm20 & 0xFFFFF) << 12) | (rd << 7) | 0b0110111):08x}"

def sd(rs2, rs1, imm12):
    imm12 &= 0xFFF
    imm_11_5 = (imm12 >> 5) & 0x7F
    imm_4_0 = imm12 & 0x1F
    return f"{((imm_11_5 << 25) | (rs2 << 20) | (rs1 << 15) | (0b011 << 12) | (imm_4_0 << 7) | 0b0100011):08x}"

def ld(rd, rs1, imm12):
    imm12 &= 0xFFF
    return f"{((imm12 << 20) | (rs1 << 15) | (0b011 << 12) | (rd << 7) | 0b0000011):08x}"

def beq(rs1, rs2, imm13):
    # imm13 is byte offset, multiple of 2
    imm = imm13 & 0x1FFF
    imm_12 = (imm >> 12) & 1
    imm_10_5 = (imm >> 5) & 0x3F
    imm_4_1 = (imm >> 1) & 0xF
    imm_11 = (imm >> 11) & 1
    return f"{((imm_12 << 31) | (imm_10_5 << 25) | (rs2 << 20) | (rs1 << 15) | (0b000 << 12) | (imm_4_1 << 8) | (imm_11 << 7) | 0b1100011):08x}"

def bne(rs1, rs2, imm13):
    imm = imm13 & 0x1FFF
    imm_12 = (imm >> 12) & 1
    imm_10_5 = (imm >> 5) & 0x3F
    imm_4_1 = (imm >> 1) & 0xF
    imm_11 = (imm >> 11) & 1
    return f"{((imm_12 << 31) | (imm_10_5 << 25) | (rs2 << 20) | (rs1 << 15) | (0b001 << 12) | (imm_4_1 << 8) | (imm_11 << 7) | 0b1100011):08x}"

def pass_test_seq():
    # lui x31, 1 -> x31 = 0x1000
    # addi x30, x0, 1 -> x30 = 1 (pass code)
    # sd x30, 0(x31) -> write pass code to 0x1000
    return [
        lui(31, 1),
        addi(30, 0, 1),
        sd(30, 31, 0)
    ]

def fail_test_seq(err_code):
    # lui x31, 1 -> x31 = 0x1000
    # addi x30, x0, err_code -> x30 = err_code (fail code > 1)
    # sd x30, 0(x31)
    return [
        lui(31, 1),
        addi(30, 0, err_code),
        sd(30, 31, 0)
    ]

def write_hex_file(filepath, instructions):
    with open(filepath, 'w') as f:
        for instr in instructions:
            f.write(f"{instr}\n")

def generate_all_tests():
    out_dir = "verif/tests"
    create_dir(out_dir)

    # 1. test_alu_ops.hex
    # Test ADD, SUB, XOR, OR, AND
    alu_instrs = [
        addi(1, 0, 10),      # x1 = 10
        addi(2, 0, 20),      # x2 = 20
        add(3, 1, 2),        # x3 = 10 + 20 = 30
        sub(4, 2, 1),        # x4 = 20 - 10 = 10
        xor_op(5, 1, 2),     # x5 = 10 ^ 20 = 30 (0x0a ^ 0x14 = 0x1e = 30)
        or_op(6, 1, 2),      # x6 = 10 | 20 = 30 (0x0a | 0x14 = 0x1e = 30)
        and_op(7, 1, 2),     # x7 = 10 & 20 = 0
        # Check x3 == 30: if x3 != 30 branch to fail (offset +16 bytes = 4 instrs)
        addi(8, 0, 30),      # x8 = 30
        bne(3, 8, 16),       # if x3 != x8, jump over pass to fail
    ] + pass_test_seq() + fail_test_seq(2)
    write_hex_file(f"{out_dir}/test_alu_ops.hex", alu_instrs)

    # 2. test_word_ops.hex
    # Test ADDIW, ADDW, SUBW
    word_instrs = [
        addiw(1, 0, 100),    # x1 = 100
        addiw(2, 0, 50),     # x2 = 50
        addw(3, 1, 2),       # x3 = 150
        subw(4, 1, 2),       # x4 = 50
        addi(5, 0, 150),     # x5 = 150
        bne(3, 5, 16),       # if x3 != 150, jump to fail
    ] + pass_test_seq() + fail_test_seq(3)
    write_hex_file(f"{out_dir}/test_word_ops.hex", word_instrs)

    # 3. test_branches.hex
    # Test BEQ, BNE
    br_instrs = [
        addi(1, 0, 10),      # x1 = 10
        addi(2, 0, 10),      # x2 = 10
        addi(3, 0, 20),      # x3 = 20
        beq(1, 2, 8),        # should take branch (+8 bytes = skip next instr)
        addi(4, 0, 99),      # should be skipped
        bne(1, 3, 8),        # should take branch (+8 bytes = skip next instr)
        addi(4, 0, 99),      # should be skipped
    ] + pass_test_seq() + fail_test_seq(4)
    write_hex_file(f"{out_dir}/test_branches.hex", br_instrs)

    # 4. test_memory.hex
    # Test SD and LD
    mem_instrs = [
        lui(1, 0),           # x1 = 0x0 (memory address 0)
        addi(1, 1, 128),     # x1 = 128 (0x80)
        addi(2, 0, 77),      # x2 = 77
        sd(2, 1, 0),         # store 77 to address 128
        ld(3, 1, 0),         # load from address 128 into x3
        bne(2, 3, 16),       # if x2 != x3, jump to fail
    ] + pass_test_seq() + fail_test_seq(5)
    write_hex_file(f"{out_dir}/test_memory.hex", mem_instrs)

    # 5. test_forwarding_hazards.hex
    # Test RAW forwarding from EX and MEM stages
    fwd_instrs = [
        addi(1, 0, 5),       # x1 = 5
        add(2, 1, 1),        # x2 = x1 + x1 = 10 (needs forwarding from EX stage)
        add(3, 2, 2),        # x3 = x2 + x2 = 20 (needs forwarding from EX stage)
        add(4, 3, 1),        # x4 = 20 + 5 = 25
        addi(5, 0, 25),      # x5 = 25
        bne(4, 5, 16),       # if x4 != 25, jump to fail
    ] + pass_test_seq() + fail_test_seq(6)
    write_hex_file(f"{out_dir}/test_forwarding_hazards.hex", fwd_instrs)

    print(f"Generated 5 test hex suites in {out_dir}/")

if __name__ == "__main__":
    generate_all_tests()
