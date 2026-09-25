// -----------------------------------------------------------------------------
// Module      : riscv_id_ex_stage
// File        : riscv_id_ex_stage.sv
// Author      : spt9pad
// Date        : 2026-06-12
// Version     : v1.0
//
// Functionality
// - Implements the combined Instruction Decode / Execute stage for the v1 core.
// - Decodes a minimal RV32I subset and generates write-back control/data.
// - Flags illegal instructions for trap handling in later pipeline logic.
//
// RV32I Instruction Structure (32-bit)
// - opcode : instr[6:0]   -> major instruction class
// - rd     : instr[11:7]  -> destination register
// - funct3 : instr[14:12] -> sub-operation selector
// - rs1    : instr[19:15] -> source register 1
// - rs2    : instr[24:20] -> source register 2 (R-type)
// - funct7 : instr[31:25] -> extended sub-operation selector (R-type)
// - imm    : immediate field encoding depends on instruction type
//
// Instruction Types Used in This Module
// - I-type: ALU-immediate operations (example: ADDI)
// - R-type: ALU register-register operations (examples: ADD, SUB)
// - U-type: upper-immediate operations (example: LUI)
//
// Execution Decode Table (imported from architecture spec)
// Format:
// INSTR   | Description                             | opcode | funct3 | funct7/funct12 | Status
//
// R-type integer ALU
// - ADD   | rd = rs1 + rs2                          | 0110011 | 000 | 0000000 | implemented
// - SUB   | rd = rs1 - rs2                          | 0110011 | 000 | 0100000 | implemented
// - SLL   | rd = rs1 << rs2[4:0]                    | 0110011 | 001 | 0000000 | implemented
// - SLT   | rd = (rs1 < rs2) signed                 | 0110011 | 010 | 0000000 | implemented
// - SLTU  | rd = (rs1 < rs2) unsigned               | 0110011 | 011 | 0000000 | implemented
// - XOR   | rd = rs1 ^ rs2                          | 0110011 | 100 | 0000000 | implemented
// - SRL   | rd = rs1 >> rs2[4:0] logical            | 0110011 | 101 | 0000000 | implemented
// - SRA   | rd = rs1 >>> rs2[4:0] arithmetic        | 0110011 | 101 | 0100000 | implemented
// - OR    | rd = rs1 | rs2                          | 0110011 | 110 | 0000000 | implemented
// - AND   | rd = rs1 & rs2                          | 0110011 | 111 | 0000000 | implemented
//
// I-type integer ALU
// - ADDI  | rd = rs1 + imm                          | 0010011 | 000 | n/a     | implemented
// - SLTI  | rd = (rs1 < imm) signed                 | 0010011 | 010 | n/a     | implemented
// - SLTIU | rd = (rs1 < imm) unsigned               | 0010011 | 011 | n/a     | implemented
// - XORI  | rd = rs1 ^ imm                          | 0010011 | 100 | n/a     | implemented
// - ORI   | rd = rs1 | imm                          | 0010011 | 110 | n/a     | implemented
// - ANDI  | rd = rs1 & imm                          | 0010011 | 111 | n/a     | implemented
// - SLLI  | rd = rs1 << shamt                       | 0010011 | 001 | 0000000 | implemented
// - SRLI  | rd = rs1 >> shamt logical               | 0010011 | 101 | 0000000 | implemented
// - SRAI  | rd = rs1 >>> shamt arithmetic           | 0010011 | 101 | 0100000 | implemented
//
// U/J/B-type control and PC-relative
// - LUI   | rd = imm20 << 12                        | 0110111 | n/a | n/a     | implemented
// - AUIPC | rd = pc + (imm20 << 12)                 | 0010111 | n/a | n/a     | implemented
// - JAL   | rd = pc+4; pc = pc + offset             | 1101111 | n/a | n/a     | implemented
// - JALR  | rd = pc+4; pc = (rs1 + imm) & ~1        | 1100111 | 000 | n/a     | implemented
// - BEQ   | if (rs1 == rs2) branch                  | 1100011 | 000 | n/a     | implemented
// - BNE   | if (rs1 != rs2) branch                  | 1100011 | 001 | n/a     | implemented
// - BLT   | if (rs1 < rs2) signed branch            | 1100011 | 100 | n/a     | implemented
// - BGE   | if (rs1 >= rs2) signed branch           | 1100011 | 101 | n/a     | implemented
// - BLTU  | if (rs1 < rs2) unsigned branch          | 1100011 | 110 | n/a     | implemented
// - BGEU  | if (rs1 >= rs2) unsigned branch         | 1100011 | 111 | n/a     | implemented
//
// Load/store
// - LB    | load byte, sign-extend                  | 0000011 | 000 | n/a     | planned
// - LH    | load halfword, sign-extend              | 0000011 | 001 | n/a     | planned
// - LW    | load word                               | 0000011 | 010 | n/a     | planned
// - LBU   | load byte, zero-extend                  | 0000011 | 100 | n/a     | planned
// - LHU   | load halfword, zero-extend              | 0000011 | 101 | n/a     | planned
// - SB    | store byte                              | 0100011 | 000 | n/a     | planned
// - SH    | store halfword                          | 0100011 | 001 | n/a     | planned
// - SW    | store word                              | 0100011 | 010 | n/a     | planned
//
// System/CSR/fence
// - ECALL | environment call trap                   | 1110011 | 000 | 000000000000 | planned
// - EBREAK| breakpoint trap                         | 1110011 | 000 | 000000000001 | planned
// - CSRRW | CSR read/write                          | 1110011 | 001 | CSR      | planned
// - CSRRS | CSR read/set                            | 1110011 | 010 | CSR      | planned
// - CSRRC | CSR read/clear                          | 1110011 | 011 | CSR      | planned
// - CSRRWI| CSR immediate write                     | 1110011 | 101 | CSR      | planned
// - CSRRSI| CSR immediate set                       | 1110011 | 110 | CSR      | planned
// - CSRRCI| CSR immediate clear                     | 1110011 | 111 | CSR      | planned
// - FENCE | memory ordering barrier                 | 0001111 | 000 | pred/succ| planned
// - FENCE.I| instruction fetch barrier              | 0001111 | 001 | immediate| planned
//
// Decode Rule for Unsupported Encodings
// - Any opcode/funct combination outside this LUT is flagged as illegal.
//
// Integration Notes
// - Output registers are implemented inside this stage.
// - Input pc_i is kept for forward compatibility with PC-relative instructions.
// - Current supported instructions include R/I ALU subset plus AUIPC/JAL/JALR/BRANCH and LUI.
// -----------------------------------------------------------------------------
module riscv_id_ex_stage (
  input  logic        clk_i,
  input  logic        rst_ni,
  input  logic        valid_i,
  // Freezes all stage output registers (no advance, no bubble) while the WB
  // stage's data cache controller is servicing a multi-cycle memory access.
  // This keeps wb_rd_o/wb_we_o/load_valid_o/load_rd_o/mem_*_o correctly
  // paired with the in-flight memory instruction until WB has consumed
  // them; see riscv_dcache_ctrl.sv for why the hold cannot simply track
  // valid_i (a bubble would advance past the still-pending instruction).
  input  logic        hold_i,
  input  logic [31:0] pc_i,
  input  logic [31:0] instr_i,
  input  logic [31:0] rs1_data_i,
  input  logic [31:0] rs2_data_i,

  output logic        wb_valid_o,
  output logic [4:0]  wb_rd_o,
  output logic [31:0] wb_data_o,
  output logic        wb_we_o,
  output logic        pc_redirect_valid_o,
  output logic [31:0] pc_redirect_addr_o,
  output logic        illegal_instr_o,

  // Memory access signals for load/store
  output logic        mem_req_o,           // Memory request valid
  output logic [31:0] mem_addr_o,          // Memory address (rs1 + imm)
  output logic        mem_we_o,            // Write enable (1 for store, 0 for load)
  output logic [1:0]  mem_width_o,         // Width: 00=byte, 01=halfword, 10=word
  output logic        mem_sign_ext_o,      // Sign-extend load data (1 for signed, 0 for unsigned)
  output logic [31:0] mem_wdata_o,         // Data to write (for store)

  // Load result writeback interface (separate from ALU writeback)
  output logic        load_valid_o,        // Load operation valid (data pending from memory)
  output logic [4:0]  load_rd_o            // Destination register for load data
);

  // Decoded instruction fields used by the minimal v1 datapath.
  logic [6:0] opcode;
  logic [2:0] funct3;
  logic [6:0] funct7;
  logic [31:0] imm_i;
  logic [31:0] imm_b;
  logic [31:0] imm_j;
  logic [31:0] imm_u;
  logic [31:0] imm_s;  // S-type immediate for store instructions.

  // Control and datapath signals for dedicated execution submodules.
  logic        addsub_enable;
  logic        addsub_sub;
  logic [31:0] addsub_op_a;
  logic [31:0] addsub_op_b;
  logic [31:0] addsub_result;

  logic        pcadd_enable;
  logic [31:0] pcadd_op_a;
  logic [31:0] pcadd_op_b;
  logic [31:0] pcadd_result;

  logic        shift_enable;
  logic        shift_left;
  logic        shift_arithmetic;
  logic [4:0]  shift_shamt;
  logic [31:0] shift_result;

  logic        logic_enable;
  logic [1:0]  logic_op_sel;
  logic [31:0] logic_op_b;
  logic [31:0] logic_result;

  logic        compare_enable;
  logic        compare_unsigned;
  logic [31:0] compare_op_b;
  logic [31:0] compare_result;

  // Decoded outputs before stage output registers.
  logic        wb_valid_d;
  logic [4:0]  wb_rd_d;
  logic [31:0] wb_data_d;
  logic        wb_we_d;
  logic        pc_redirect_valid_d;
  logic [31:0] pc_redirect_addr_d;
  logic        illegal_instr_d;
  logic        mem_req_d;
  logic [31:0] mem_addr_d;
  logic        mem_we_d;
  logic [1:0]  mem_width_d;
  logic        mem_sign_ext_d;
  logic [31:0] mem_wdata_d;
  logic        load_valid_d;
  logic [4:0]  load_rd_d;

  // Dedicated add/sub block.
  riscv_alu_addsub u_alu_addsub (
    .enable_i (addsub_enable),
    .sub_i    (addsub_sub),
    .op_a_i   (addsub_op_a),
    .op_b_i   (addsub_op_b),
    .result_o (addsub_result)
  );

  // Dedicated PC-relative adder block for redirect target generation.
  riscv_alu_addsub u_alu_pcadd (
    .enable_i (pcadd_enable),
    .sub_i    (1'b0),
    .op_a_i   (pcadd_op_a),
    .op_b_i   (pcadd_op_b),
    .result_o (pcadd_result)
  );

  // Dedicated shift block.
  riscv_alu_shift u_alu_shift (
    .enable_i     (shift_enable),
    .left_i       (shift_left),
    .arithmetic_i (shift_arithmetic),
    .op_a_i       (rs1_data_i),
    .shamt_i      (shift_shamt),
    .result_o     (shift_result)
  );

  // Dedicated bitwise logic block.
  riscv_alu_logic u_alu_logic (
    .enable_i (logic_enable),
    .op_sel_i (logic_op_sel),
    .op_a_i   (rs1_data_i),
    .op_b_i   (logic_op_b),
    .result_o (logic_result)
  );

  // Dedicated comparison block.
  riscv_alu_compare u_alu_compare (
    .enable_i   (compare_enable),
    .unsigned_i (compare_unsigned),
    .op_a_i     (rs1_data_i),
    .op_b_i     (compare_op_b),
    .result_o   (compare_result)
  );

  always_comb begin
    // Extract common RISC-V fields.
    opcode = instr_i[6:0];
    funct3 = instr_i[14:12];
    funct7 = instr_i[31:25];
    imm_i  = {{20{instr_i[31]}}, instr_i[31:20]};
    imm_b  = {{20{instr_i[31]}}, instr_i[7], instr_i[30:25], instr_i[11:8], 1'b0};
    imm_j  = {{11{instr_i[31]}}, instr_i[31], instr_i[19:12], instr_i[20], instr_i[30:21], 1'b0};
    imm_u  = {instr_i[31:12], 12'h000};
    // S-type immediate: split between bits [31:25] and [11:7] for store instructions.
    imm_s  = {{20{instr_i[31]}}, instr_i[31:25], instr_i[11:7]};

    // Safe defaults: no writeback and no exception.
    wb_valid_d      = 1'b1;
    wb_rd_d         = instr_i[11:7];
    wb_data_d       = 32'h0000_0000;
    wb_we_d         = 1'b0;
    pc_redirect_valid_d = 1'b0;
    pc_redirect_addr_d  = 32'h0000_0000;
    illegal_instr_d = 1'b0;

    // Memory access defaults (no request by default).
    mem_req_d       = 1'b0;          // No memory request unless load/store instruction.
    mem_addr_d      = 32'h0000_0000; // Memory address (calculated by adder).
    mem_we_d        = 1'b0;          // Write disable by default (load=0, store=1).
    mem_width_d     = 2'b00;         // Width: 00=byte, 01=halfword, 10=word.
    mem_sign_ext_d  = 1'b0;          // No sign-extension by default (applies to loads only).
    mem_wdata_d     = 32'h0000_0000; // Write data (rs2 for store).

    // Load result writeback defaults (no load pending by default).
    load_valid_d    = 1'b0;          // No load operation by default.
    load_rd_d       = 5'b00000;      // Load destination register (will be rd for load instruction).

    // Default controls for execution submodules.
    addsub_enable    = 1'b0;          // Enables add/sub block when set.
    addsub_sub       = 1'b0;          // Selects subtraction when set, addition when clear.
    addsub_op_a      = rs1_data_i;    // First operand for add/sub (rs1 by default).
    addsub_op_b      = 32'h0000_0000; // Second operand for add/sub (rs2 or immediate).
    pcadd_enable     = 1'b0;          // Enables PC-relative adder for redirects.
    pcadd_op_a       = 32'h0000_0000; // First operand for PC-relative add.
    pcadd_op_b       = 32'h0000_0000; // Second operand for PC-relative add.
    shift_enable     = 1'b0;          // Enables shift block when set.
    shift_left       = 1'b0;          // Selects left shift when set.
    shift_arithmetic = 1'b0;          // Selects arithmetic right shift when set.
    shift_shamt      = rs2_data_i[4:0]; // Shift amount source (rs2 by default).
    logic_enable     = 1'b0;          // Enables bitwise logic block when set.
    logic_op_sel     = 2'b00;         // Logic op selector: 00=XOR, 01=OR, 10=AND.
    logic_op_b       = rs2_data_i;    // Logic second operand (rs2 by default).
    compare_enable   = 1'b0;          // Enables comparison block when set.
    compare_unsigned = 1'b0;          // Selects unsigned compare when set, signed when clear.
    compare_op_b     = rs2_data_i;    // Compare second operand (rs2 by default).

    // Minimal RV32I subset for the initial bring-up.
    unique case (opcode)
      7'b0010011: begin // OP-IMM (I-type ALU immediate)
        unique case (funct3)
          3'b000: begin // ADDI
            addsub_enable = 1'b1;
            addsub_sub    = 1'b0;
            addsub_op_a   = rs1_data_i;
            addsub_op_b   = imm_i;
            wb_we_d   = 1'b1;
            wb_data_d = addsub_result;
          end
          3'b010: begin // SLTI
            compare_enable   = 1'b1;
            compare_unsigned = 1'b0;
            compare_op_b     = imm_i;
            wb_we_d   = 1'b1;
            wb_data_d = compare_result;
          end
          3'b011: begin // SLTIU
            compare_enable   = 1'b1;
            compare_unsigned = 1'b1;
            compare_op_b     = imm_i;
            wb_we_d   = 1'b1;
            wb_data_d = compare_result;
          end
          3'b100: begin // XORI
            logic_enable = 1'b1;
            logic_op_sel = 2'b00;
            logic_op_b   = imm_i;
            wb_we_d   = 1'b1;
            wb_data_d = logic_result;
          end
          3'b110: begin // ORI
            logic_enable = 1'b1;
            logic_op_sel = 2'b01;
            logic_op_b   = imm_i;
            wb_we_d   = 1'b1;
            wb_data_d = logic_result;
          end
          3'b111: begin // ANDI
            logic_enable = 1'b1;
            logic_op_sel = 2'b10;
            logic_op_b   = imm_i;
            wb_we_d   = 1'b1;
            wb_data_d = logic_result;
          end
          3'b001: begin // SLLI
            if (funct7 == 7'b0000000) begin
              shift_enable = 1'b1;
              shift_left   = 1'b1;
              shift_shamt  = instr_i[24:20];
              wb_we_d   = 1'b1;
              wb_data_d = shift_result;
            end else begin
              illegal_instr_d = 1'b1;
            end
          end
          3'b101: begin
            if (funct7 == 7'b0000000) begin // SRLI
              shift_enable     = 1'b1;
              shift_left       = 1'b0;
              shift_arithmetic = 1'b0;
              shift_shamt      = instr_i[24:20];
              wb_we_d   = 1'b1;
              wb_data_d = shift_result;
            end else if (funct7 == 7'b0100000) begin // SRAI
              shift_enable     = 1'b1;
              shift_left       = 1'b0;
              shift_arithmetic = 1'b1;
              shift_shamt      = instr_i[24:20];
              wb_we_d   = 1'b1;
              wb_data_d = shift_result;
            end else begin
              illegal_instr_d = 1'b1;
            end
          end
          default: begin
            illegal_instr_d = 1'b1;
          end
        endcase
      end

      7'b0110011: begin // OP (R-type ALU register-register)
        unique case ({funct7, funct3})
          10'b0000000_000: begin // ADD
            addsub_enable = 1'b1;
            addsub_sub    = 1'b0;
            addsub_op_a   = rs1_data_i;
            addsub_op_b   = rs2_data_i;
            wb_we_d   = 1'b1;
            wb_data_d = addsub_result;
          end
          10'b0100000_000: begin // SUB
            addsub_enable = 1'b1;
            addsub_sub    = 1'b1;
            addsub_op_a   = rs1_data_i;
            addsub_op_b   = rs2_data_i;
            wb_we_d   = 1'b1;
            wb_data_d = addsub_result;
          end
          10'b0000000_001: begin // SLL
            shift_enable = 1'b1;
            shift_left   = 1'b1;
            wb_we_d   = 1'b1;
            wb_data_d = shift_result;
          end
          10'b0000000_010: begin // SLT
            compare_enable   = 1'b1;
            compare_unsigned = 1'b0;
            wb_we_d   = 1'b1;
            wb_data_d = compare_result;
          end
          10'b0000000_011: begin // SLTU
            compare_enable   = 1'b1;
            compare_unsigned = 1'b1;
            wb_we_d   = 1'b1;
            wb_data_d = compare_result;
          end
          10'b0000000_100: begin // XOR
            logic_enable = 1'b1;
            logic_op_sel = 2'b00;
            wb_we_d   = 1'b1;
            wb_data_d = logic_result;
          end
          10'b0000000_101: begin // SRL
            shift_enable     = 1'b1;
            shift_left       = 1'b0;
            shift_arithmetic = 1'b0;
            wb_we_d   = 1'b1;
            wb_data_d = shift_result;
          end
          10'b0100000_101: begin // SRA
            shift_enable     = 1'b1;
            shift_left       = 1'b0;
            shift_arithmetic = 1'b1;
            wb_we_d   = 1'b1;
            wb_data_d = shift_result;
          end
          10'b0000000_110: begin // OR
            logic_enable = 1'b1;
            logic_op_sel = 2'b01;
            wb_we_d   = 1'b1;
            wb_data_d = logic_result;
          end
          10'b0000000_111: begin // AND
            logic_enable = 1'b1;
            logic_op_sel = 2'b10;
            wb_we_d   = 1'b1;
            wb_data_d = logic_result;
          end
          default: begin
            illegal_instr_d = 1'b1;
          end
        endcase
      end

      7'b0110111: begin // LUI (U-type, load upper immediate)
        wb_we_d   = 1'b1;
        wb_data_d = imm_u;
      end

      7'b0010111: begin // AUIPC (U-type, PC-relative)
        addsub_enable = 1'b1;
        addsub_sub    = 1'b0;
        addsub_op_a   = pc_i;
        addsub_op_b   = imm_u;
        wb_we_d   = 1'b1;
        wb_data_d = addsub_result;
      end

      7'b1101111: begin // JAL (J-type)
        addsub_enable = 1'b1;
        addsub_sub    = 1'b0;
        addsub_op_a   = pc_i;
        addsub_op_b   = 32'd4;

        pcadd_enable  = 1'b1;
        pcadd_op_a    = pc_i;
        pcadd_op_b    = imm_j;

        wb_we_d           = 1'b1;
        wb_data_d         = addsub_result;
        pc_redirect_valid_d = 1'b1;
        pc_redirect_addr_d  = pcadd_result;
      end

      7'b1100111: begin // JALR (I-type)
        if (funct3 == 3'b000) begin
          addsub_enable = 1'b1;
          addsub_sub    = 1'b0;
          addsub_op_a   = pc_i;
          addsub_op_b   = 32'd4;

          pcadd_enable  = 1'b1;
          pcadd_op_a    = rs1_data_i;
          pcadd_op_b    = imm_i;

          wb_we_d           = 1'b1;
          wb_data_d         = addsub_result;
          pc_redirect_valid_d = 1'b1;
          pc_redirect_addr_d  = pcadd_result & 32'hffff_fffe;
        end else begin
          illegal_instr_d = 1'b1;
        end
      end

      7'b1100011: begin // BRANCH (B-type)
        unique case (funct3)
          3'b000: begin // BEQ
            if (rs1_data_i == rs2_data_i) begin
              pcadd_enable  = 1'b1;
              pcadd_op_a    = pc_i;
              pcadd_op_b    = imm_b;
              pc_redirect_valid_d = 1'b1;
              pc_redirect_addr_d  = pcadd_result;
            end
          end
          3'b001: begin // BNE
            if (rs1_data_i != rs2_data_i) begin
              pcadd_enable  = 1'b1;
              pcadd_op_a    = pc_i;
              pcadd_op_b    = imm_b;
              pc_redirect_valid_d = 1'b1;
              pc_redirect_addr_d  = pcadd_result;
            end
          end
          3'b100: begin // BLT
            if ($signed(rs1_data_i) < $signed(rs2_data_i)) begin
              pcadd_enable  = 1'b1;
              pcadd_op_a    = pc_i;
              pcadd_op_b    = imm_b;
              pc_redirect_valid_d = 1'b1;
              pc_redirect_addr_d  = pcadd_result;
            end
          end
          3'b101: begin // BGE
            if ($signed(rs1_data_i) >= $signed(rs2_data_i)) begin
              pcadd_enable  = 1'b1;
              pcadd_op_a    = pc_i;
              pcadd_op_b    = imm_b;
              pc_redirect_valid_d = 1'b1;
              pc_redirect_addr_d  = pcadd_result;
            end
          end
          3'b110: begin // BLTU
            if (rs1_data_i < rs2_data_i) begin
              pcadd_enable  = 1'b1;
              pcadd_op_a    = pc_i;
              pcadd_op_b    = imm_b;
              pc_redirect_valid_d = 1'b1;
              pc_redirect_addr_d  = pcadd_result;
            end
          end
          3'b111: begin // BGEU
            if (rs1_data_i >= rs2_data_i) begin
              pcadd_enable  = 1'b1;
              pcadd_op_a    = pc_i;
              pcadd_op_b    = imm_b;
              pc_redirect_valid_d = 1'b1;
              pc_redirect_addr_d  = pcadd_result;
            end
          end
          default: begin
            illegal_instr_d = 1'b1;
          end
        endcase
      end

      7'b0000011: begin // LOAD (I-type)
        // All load instructions use rs1 + imm for address generation.
        addsub_enable = 1'b1;
        addsub_sub    = 1'b0;
        addsub_op_a   = rs1_data_i;
        addsub_op_b   = imm_i;

        mem_req_d     = 1'b1;         // Signal memory request.
        mem_addr_d    = addsub_result; // Address = rs1 + imm.
        mem_we_d      = 1'b0;         // Load: no write.
        mem_wdata_d   = 32'h0000_0000;

        // Load result will be written by WB stage when data returns from memory.
        load_valid_d  = 1'b1;         // Indicate load operation is valid.
        load_rd_d     = instr_i[11:7]; // Destination register for load data.
        wb_we_d       = 1'b0;         // Do not write directly (data not available yet).

        unique case (funct3)
          3'b000: begin // LB (load byte, sign-extend)
            mem_width_d   = 2'b00;
            mem_sign_ext_d = 1'b1;
          end
          3'b001: begin // LH (load halfword, sign-extend)
            mem_width_d   = 2'b01;
            mem_sign_ext_d = 1'b1;
          end
          3'b010: begin // LW (load word)
            mem_width_d   = 2'b10;
            mem_sign_ext_d = 1'b0;
          end
          3'b100: begin // LBU (load byte, zero-extend)
            mem_width_d   = 2'b00;
            mem_sign_ext_d = 1'b0;
          end
          3'b101: begin // LHU (load halfword, zero-extend)
            mem_width_d   = 2'b01;
            mem_sign_ext_d = 1'b0;
          end
          default: begin
            illegal_instr_d = 1'b1;
            mem_req_d     = 1'b0;
            load_valid_d  = 1'b0;
          end
        endcase
      end

      7'b0100011: begin // STORE (S-type)
        // All store instructions use rs1 + imm for address generation.
        addsub_enable = 1'b1;
        addsub_sub    = 1'b0;
        addsub_op_a   = rs1_data_i;
        addsub_op_b   = imm_s;

        mem_req_d     = 1'b1;         // Signal memory request.
        mem_addr_d    = addsub_result; // Address = rs1 + imm.
        mem_we_d      = 1'b1;         // Store: write enable.
        mem_wdata_d   = rs2_data_i;   // Write data = rs2.
        wb_we_d       = 1'b0;         // Store does not write to rd.

        unique case (funct3)
          3'b000: begin // SB (store byte)
            mem_width_d = 2'b00;
          end
          3'b001: begin // SH (store halfword)
            mem_width_d = 2'b01;
          end
          3'b010: begin // SW (store word)
            mem_width_d = 2'b10;
          end
          default: begin
            illegal_instr_d = 1'b1;
            mem_req_d     = 1'b0;
            mem_we_d      = 1'b0;
          end
        endcase
      end

      default: begin // Unsupported opcode
        illegal_instr_d = 1'b1;
      end
    endcase

    // Never commit architectural state on illegal opcodes.
    if (illegal_instr_d) begin
      wb_we_d = 1'b0;
    end

    // Bubble: no architectural side effects when input is not valid.
    if (!valid_i) begin
      wb_valid_d         = 1'b0;
      wb_we_d            = 1'b0;
      pc_redirect_valid_d = 1'b0;
      illegal_instr_d    = 1'b0;
      mem_req_d          = 1'b0;
      mem_we_d           = 1'b0;
      load_valid_d       = 1'b0;
    end
  end

  // Stage output registers.
  always_ff @(posedge clk_i or negedge rst_ni) begin
    if (!rst_ni) begin
      wb_valid_o         <= 1'b0;
      wb_rd_o            <= 5'd0;
      wb_data_o          <= 32'h0000_0000;
      wb_we_o            <= 1'b0;
      pc_redirect_valid_o <= 1'b0;
      pc_redirect_addr_o <= 32'h0000_0000;
      illegal_instr_o    <= 1'b0;
      mem_req_o          <= 1'b0;
      mem_addr_o         <= 32'h0000_0000;
      mem_we_o           <= 1'b0;
      mem_width_o        <= 2'b00;
      mem_sign_ext_o     <= 1'b0;
      mem_wdata_o        <= 32'h0000_0000;
      load_valid_o       <= 1'b0;
      load_rd_o          <= 5'd0;
    end else if (hold_i) begin
      // Frozen: keep presenting the same in-flight memory instruction to WB
      // (no assignments here -- all outputs implicitly retain their value).
    end else begin
      wb_valid_o         <= wb_valid_d;
      wb_rd_o            <= wb_rd_d;
      wb_data_o          <= wb_data_d;
      wb_we_o            <= wb_we_d;
      pc_redirect_valid_o <= pc_redirect_valid_d;
      pc_redirect_addr_o <= pc_redirect_addr_d;
      illegal_instr_o    <= illegal_instr_d;
      mem_req_o          <= mem_req_d;
      mem_addr_o         <= mem_addr_d;
      mem_we_o           <= mem_we_d;
      mem_width_o        <= mem_width_d;
      mem_sign_ext_o     <= mem_sign_ext_d;
      mem_wdata_o        <= mem_wdata_d;
      load_valid_o       <= load_valid_d;
      load_rd_o          <= load_rd_d;
    end
  end

endmodule
