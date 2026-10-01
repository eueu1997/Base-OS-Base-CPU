// -----------------------------------------------------------------------------
// Module      : riscv_id_ex_stage
// File        : riscv_id_ex_stage.sv
// Author      : spt9pad
// Date        : 2026-09-25
// Version     : v1.1
//
// Functionality
// - Connects Tomasulo dispatch/result buses to eight functional-unit slots.
// - Slots 0..4 implement ADD, SUB, SHIFT, BITWISE and COMPARE respectively.
// - Slots 5..7 are combinational BRANCH, JUMP and stateless MEMORY models.
// - ALU control uses the instruction and PC dispatched with each RS operand pair.
// - Existing Tomasulo issue/retirement limitations are not repaired here.
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
// Legacy In-Order Execution Decode Reference (not OOO implementation status)
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
// - ALUs are combinational; result valid and ROB tag follow RS dispatch.
// - WB outputs observe the ROB commit bus; Tomasulo writes its internal RF.
// - All FUs complete combinationally; memory outputs expose model transactions.
// - Branch taken/target and jump target are internal waveform signals only.
// - Redirect outputs remain inactive: this model has no speculative recovery.
// - Loads return synthetic data; stores never modify RAM. No memory faults modeled.
// - valid_i/hold_i and wb_rf_* inputs are reserved, not connected to Tomasulo.
// - Tomasulo still lacks issue-valid/backpressure and flush support.
// -----------------------------------------------------------------------------
module riscv_id_ex_stage (
  input  logic        clk_i,
  input  logic        rst_ni,
  input  logic        valid_i,
  input  logic        hold_i,
  input  logic [31:0] pc_i,
  input  logic [31:0] instr_i,

  output logic        wb_valid_o,
  output logic [4:0]  wb_rd_o,
  output logic [31:0] wb_data_o,
  output logic        wb_we_o,
  output logic        pc_redirect_valid_o,
  output logic [31:0] pc_redirect_addr_o,
  output logic        illegal_instr_o,
  // WB signals from memory, LOAD instruction
  input  logic        wb_rf_we_i ,
  input  logic        wb_rf_waddr_i ,
  input  logic        wb_rf_wdata_i ,
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

  localparam int FUNC_UNIT_N = 8;
  localparam int ROB_SIZE = 8;
  localparam int ROB_TAG_WIDTH = $clog2(ROB_SIZE);
  localparam int FU_ADD = 0;
  localparam int FU_SUB = 1;
  localparam int FU_SHIFT = 2;
  localparam int FU_BITWISE = 3;
  localparam int FU_COMPARE = 4;
  localparam int FU_BRANCH = 5;
  localparam int FU_JUMP = 6;
  localparam int FU_MEMORY = 7;

  logic [FUNC_UNIT_N-1:0][31:0] fu_source1;
  logic [FUNC_UNIT_N-1:0][31:0] fu_source2;
  logic [FUNC_UNIT_N-1:0][31:0] fu_instr;
  logic [FUNC_UNIT_N-1:0][31:0] fu_pc;
  logic [FUNC_UNIT_N-1:0][ROB_TAG_WIDTH-1:0] fu_dest;
  logic [FUNC_UNIT_N-1:0] fu_enable;
  logic [FUNC_UNIT_N-1:0][31:0] fu_result;
  logic [FUNC_UNIT_N-1:0][ROB_TAG_WIDTH-1:0] fu_result_dest;
  logic [FUNC_UNIT_N-1:0] fu_result_valid;
  logic [FU_COMPARE:FU_ADD][31:0] alu_op_b;
  logic [31:0] add_op_a;
  logic [31:0] add_op_b;
  logic [1:0] logic_op_sel;
  logic decode_illegal;
  logic [FU_MEMORY:FU_BRANCH] model_illegal;
  logic branch_taken;
  logic [31:0] branch_target;
  logic [31:0] jump_target;

  tomasulo_top #(
    .FUNC_UNIT_N(FUNC_UNIT_N),
    .ROB_SIZE(ROB_SIZE)
  ) u_tomasulo (
    .clk_i(clk_i),
    .rst_i(rst_ni),
    .intr_i(instr_i),
    .pc_i(pc_i),
    .source_value1_o(fu_source1),
    .source_value2_o(fu_source2),
    .destination_o(fu_dest),
    .fu_en_o(fu_enable),
    .instr_o(fu_instr),
    .pc_o(fu_pc),
    .commit_valid_o(wb_valid_o),
    .commit_rd_o(wb_rd_o),
    .commit_value_o(wb_data_o),
    .illegal_instr_o(decode_illegal),
    .result_value_i(fu_result),
    .result_dest_i(fu_result_dest),
    .result_en_i(fu_result_valid)
  );

  for (genvar fu_index = FU_ADD; fu_index <= FU_COMPARE; fu_index++) begin : gen_alu_feedback
    assign alu_op_b[fu_index] = (fu_instr[fu_index][6:0] == 7'b0010011)
      ? {{20{fu_instr[fu_index][31]}}, fu_instr[fu_index][31:20]}
      : fu_source2[fu_index];
    assign fu_result_dest[fu_index] = fu_dest[fu_index];
    assign fu_result_valid[fu_index] = rst_ni && fu_enable[fu_index];
  end

  always_comb begin
    add_op_a = fu_source1[FU_ADD];
    add_op_b = alu_op_b[FU_ADD];
    case (fu_instr[FU_ADD][6:0])
      7'b0110111: begin
        add_op_a = '0;
        add_op_b = {fu_instr[FU_ADD][31:12], 12'b0};
      end
      7'b0010111: begin
        add_op_a = fu_pc[FU_ADD];
        add_op_b = {fu_instr[FU_ADD][31:12], 12'b0};
      end
      default: begin
        add_op_a = fu_source1[FU_ADD];
        add_op_b = alu_op_b[FU_ADD];
      end
    endcase

    logic_op_sel = 2'b00;
    case (fu_instr[FU_BITWISE][14:12])
      3'b100: logic_op_sel = 2'b00;
      3'b110: logic_op_sel = 2'b01;
      3'b111: logic_op_sel = 2'b10;
      default: logic_op_sel = 2'b00;
    endcase
  end

  riscv_alu_addsub u_alu_add (
    .enable_i(fu_result_valid[FU_ADD]),
    .sub_i(1'b0),
    .op_a_i(add_op_a),
    .op_b_i(add_op_b),
    .result_o(fu_result[FU_ADD])
  );

  riscv_alu_addsub u_alu_sub (
    .enable_i(fu_result_valid[FU_SUB]),
    .sub_i(1'b1),
    .op_a_i(fu_source1[FU_SUB]),
    .op_b_i(fu_source2[FU_SUB]),
    .result_o(fu_result[FU_SUB])
  );

  riscv_alu_shift u_alu_shift (
    .enable_i(fu_result_valid[FU_SHIFT]),
    .left_i(fu_instr[FU_SHIFT][14:12] == 3'b001),
    .arithmetic_i(fu_instr[FU_SHIFT][30]),
    .op_a_i(fu_source1[FU_SHIFT]),
    .shamt_i(alu_op_b[FU_SHIFT][4:0]),
    .result_o(fu_result[FU_SHIFT])
  );

  riscv_alu_logic u_alu_logic (
    .enable_i(fu_result_valid[FU_BITWISE]),
    .op_sel_i(logic_op_sel),
    .op_a_i(fu_source1[FU_BITWISE]),
    .op_b_i(alu_op_b[FU_BITWISE]),
    .result_o(fu_result[FU_BITWISE])
  );

  riscv_alu_compare u_alu_compare (
    .enable_i(fu_result_valid[FU_COMPARE]),
    .unsigned_i(fu_instr[FU_COMPARE][14:12] == 3'b011),
    .op_a_i(fu_source1[FU_COMPARE]),
    .op_b_i(alu_op_b[FU_COMPARE]),
    .result_o(fu_result[FU_COMPARE])
  );

  riscv_fu_branch #(.ROB_TAG_WIDTH(ROB_TAG_WIDTH)) u_fu_branch (
    .enable_i(rst_ni && fu_enable[FU_BRANCH]),
    .instr_i(fu_instr[FU_BRANCH]),
    .pc_i(fu_pc[FU_BRANCH]),
    .op_a_i(fu_source1[FU_BRANCH]),
    .op_b_i(fu_source2[FU_BRANCH]),
    .dest_i(fu_dest[FU_BRANCH]),
    .result_o(fu_result[FU_BRANCH]),
    .dest_o(fu_result_dest[FU_BRANCH]),
    .valid_o(fu_result_valid[FU_BRANCH]),
    .taken_o(branch_taken),
    .target_o(branch_target),
    .illegal_instr_o(model_illegal[FU_BRANCH])
  );

  riscv_fu_jump #(.ROB_TAG_WIDTH(ROB_TAG_WIDTH)) u_fu_jump (
    .enable_i(rst_ni && fu_enable[FU_JUMP]),
    .instr_i(fu_instr[FU_JUMP]),
    .pc_i(fu_pc[FU_JUMP]),
    .op_a_i(fu_source1[FU_JUMP]),
    .op_b_i(fu_source2[FU_JUMP]),
    .dest_i(fu_dest[FU_JUMP]),
    .result_o(fu_result[FU_JUMP]),
    .dest_o(fu_result_dest[FU_JUMP]),
    .valid_o(fu_result_valid[FU_JUMP]),
    .target_o(jump_target),
    .illegal_instr_o(model_illegal[FU_JUMP])
  );

  riscv_fu_memory #(.ROB_TAG_WIDTH(ROB_TAG_WIDTH)) u_fu_memory (
    .enable_i(rst_ni && fu_enable[FU_MEMORY]),
    .instr_i(fu_instr[FU_MEMORY]),
    .pc_i(fu_pc[FU_MEMORY]),
    .op_a_i(fu_source1[FU_MEMORY]),
    .op_b_i(fu_source2[FU_MEMORY]),
    .dest_i(fu_dest[FU_MEMORY]),
    .result_o(fu_result[FU_MEMORY]),
    .dest_o(fu_result_dest[FU_MEMORY]),
    .valid_o(fu_result_valid[FU_MEMORY]),
    .addr_o(mem_addr_o),
    .store_o(mem_we_o),
    .width_o(mem_width_o),
    .sign_ext_o(mem_sign_ext_o),
    .wdata_o(mem_wdata_o),
    .illegal_instr_o(model_illegal[FU_MEMORY])
  );

  assign illegal_instr_o = decode_illegal || (|model_illegal);
  assign wb_we_o = wb_valid_o && (wb_rd_o != 5'd0);
  assign pc_redirect_valid_o = 1'b0;
  assign pc_redirect_addr_o = '0;
  assign mem_req_o = fu_result_valid[FU_MEMORY];
  assign load_valid_o = mem_req_o && !mem_we_o;
  assign load_rd_o = load_valid_o ? fu_instr[FU_MEMORY][11:7] : 5'b0;

endmodule
