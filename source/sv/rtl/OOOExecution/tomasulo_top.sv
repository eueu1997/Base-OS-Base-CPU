// Module      : tomasulo_top
// File        : tomasulo_top.sv
// Author      : GitHub Copilot
// Date        : 2026-09-24
// Version     : v1.0
// Functionality: Connects ROB/RF/RS and dispatches RV32I instructions by FU class.
// RS mapping  : 0=ADD/ADDI/LUI/AUIPC, 1=SUB, 2=shifts, 3=bitwise,
//               4=SLT/SLTU/SLTI/SLTIU, 5=branches, 6=JAL/JALR, 7=loads/stores.
//               Unsupported encodings assert illegal_instr_o with no RS load.
module tomasulo_top # (
  parameter int FUNC_UNIT_N = 8,
  parameter int ROB_SIZE = 8,
  parameter int RS_SIZE = 4
)
(
  input logic clk_i,
  input logic rst_i,
  input logic [31:0] intr_i,
  // Output to functional units
  output logic [FUNC_UNIT_N - 1:0] [31:0] source_value1_o,
  output logic [FUNC_UNIT_N - 1:0] [31:0] source_value2_o,
  output logic [FUNC_UNIT_N - 1:0] [$clog2(ROB_SIZE)-1:0] destination_o,
  output logic [FUNC_UNIT_N - 1:0]        fu_en_o,
  output logic illegal_instr_o,
  // Input results from functional units
  input logic [FUNC_UNIT_N - 1:0] [31:0] result_value_i,
  input logic [FUNC_UNIT_N - 1:0] [$clog2(ROB_SIZE)-1:0] result_dest_i,
  input logic [FUNC_UNIT_N - 1:0]  result_en_i

);

  logic [$clog2(ROB_SIZE)-1 : 0]  rob_pos_issued_inst_s;
  logic [4:0]                     rdest_commit_s;
  logic [31:0]                    rvalue_commit_s;
  logic [$clog2(ROB_SIZE)-1 : 0]  robpos_commit_s;
  logic                           ren_commit_s;
  logic [31:0]                    rsource1_value_s;
  logic [31:0]                    rsource2_value_s;
  logic [4:0]                     rsource1_rob_s;
  logic [4:0]                     rsource2_rob_s;
  logic                           rsource1_en_s;
  logic                           rsource2_en_s;
  // Signal for decode
  localparam int RS_ADD = 0;
  localparam int RS_SUB = 1;
  localparam int RS_SHIFT = 2;
  localparam int RS_BITWISE = 3;
  localparam int RS_COMPARE = 4;
  localparam int RS_BRANCH = 5;
  localparam int RS_JUMP = 6;
  localparam int RS_MEMORY = 7;

  logic [FUNC_UNIT_N-1:0] instr_load_s;
  logic [6:0] opcode;
  logic [2:0] funct3;
  logic [6:0] funct7;
  logic [31:0] imm_i, imm_b, imm_j, imm_u, imm_s;
  logic [4:0] rd_s;
  logic [4:0] rs1_s;
  logic [4:0] rs2_s;

  // Signal decodification
  assign rd_s = intr_i[11:7];
  assign rs1_s = intr_i[19:15];
  assign rs2_s = intr_i[24:20];

  assign opcode   = intr_i[6:0];
  assign funct3   = intr_i[14:12];
  assign funct7   = intr_i[31:25];
  // Immediate values
  assign imm_i    = {{20{intr_i[31]}}, intr_i[31:20]};
  assign imm_b    = {{20{intr_i[31]}}, intr_i[7], intr_i[30:25], intr_i[11:8], 1'b0};
  assign imm_j    = {{11{intr_i[31]}}, intr_i[31], intr_i[19:12], intr_i[20], intr_i[30:21], 1'b0};
  assign imm_u    = {intr_i[31:12], 12'h000};
   // S-type immediate: split between bits [31:25] and [11:7] for store instructions.
  assign imm_s  = {{20{intr_i[31]}}, intr_i[31:25], intr_i[11:7]};


  tomasulo_ROB #
  (
    .ROB_SIZE(ROB_SIZE),
    .FUNC_UNIT_N(FUNC_UNIT_N)
  )
  rob_i
  (
    .clk_i(clk_i),
    .rst_i(rst_i),
    .reg_dest_i(rd_s),
    .rob_pos_o(rob_pos_issued_inst_s),
    .rdest_commit_o(rdest_commit_s),
    .rvalue_commit_o(rvalue_commit_s),
    .robpos_commit_o(robpos_commit_s),
    .ren_commit_o(ren_commit_s),
    .rdest_i(result_dest_i),
    .rvalue_i(result_value_i),
    .ren_i(result_en_i)

  );



  tomasulo_RF #
(
  .ROB_SIZE(ROB_SIZE)
) rf_i (
  .clk_i(clk_i),
  .rst_ni(rst_i),
  .rsource1_issue_i(rs1_s),
  .rsource2_issue_i(rs2_s),
  .rdest_issue_i(rd_s),
  .rob_inst_issue_i(rob_pos_issued_inst_s),
  .rdest_commit_i(rdest_commit_s),
  .value_commit_i(rvalue_commit_s),
  .rob_inst_commit_i(robpos_commit_s),
  .we_commit_i(ren_commit_s),
  .rsource1_value_o(rsource1_value_s),
  .rsource2_value_o(rsource2_value_s),
  .rsource1_rob_o(rsource1_rob_s),
  .rsource2_rob_o(rsource2_rob_s),
  .rsource1_en_o(rsource1_en_s),
  .rsource2_en_o(rsource2_en_s)
);

generate
  for(genvar rs_index = 0; rs_index < FUNC_UNIT_N; rs_index++)begin : gen_rs
    tomasulo_RS #(
      .ROB_SIZE(ROB_SIZE),
      .FUNC_UNIT_N(FUNC_UNIT_N)
    ) rs_i (
     .clk_i(clk_i),
     .rst_ni(rst_i),
     .register_value1_i(rsource1_value_s),
     .register_value2_i(rsource2_value_s),
     .register1_avail_i(rsource1_en_s),
     .register2_avail_i(rsource2_en_s),
     .rob_value1_s(rsource1_rob_s),
     .rob_value2_s(rsource2_rob_s),
    .instr_load_i(instr_load_s[rs_index]),
     .rob_dest_i(rob_pos_issued_inst_s),
     .instr_i(intr_i),

     .fu_dest_i(result_dest_i), // TODO : qui la situazione è complessa . ogni riga di rs dovrebbe campionare ogni bus di uscita delle FU per vedere le destinazioni
     .fu_value_i(result_value_i),

     .rs_ready_o(fu_en_o[rs_index]),
     .rs1_o(source_value1_o[rs_index]),
     .rs2_o(source_value2_o[rs_index]),
     .rd_o(destination_o[rs_index])
    );
  end
endgenerate

  always_comb begin
    instr_load_s = '0;
    illegal_instr_o = 1'b0;

    unique case (opcode)
      7'b0110011: begin
        unique case ({funct7, funct3})
          10'b0000000_000: instr_load_s[RS_ADD] = 1'b1;
          10'b0100000_000: instr_load_s[RS_SUB] = 1'b1;
          10'b0000000_001,
          10'b0000000_101,
          10'b0100000_101: instr_load_s[RS_SHIFT] = 1'b1;
          10'b0000000_100,
          10'b0000000_110,
          10'b0000000_111: instr_load_s[RS_BITWISE] = 1'b1;
          10'b0000000_010,
          10'b0000000_011: instr_load_s[RS_COMPARE] = 1'b1;
          default: illegal_instr_o = 1'b1;
        endcase
      end

      7'b0010011: begin
        unique case (funct3)
          3'b000: instr_load_s[RS_ADD] = 1'b1;
          3'b010,
          3'b011: instr_load_s[RS_COMPARE] = 1'b1;
          3'b100,
          3'b110,
          3'b111: instr_load_s[RS_BITWISE] = 1'b1;
          3'b001: begin
            if (funct7 == 7'b0000000)
              instr_load_s[RS_SHIFT] = 1'b1;
            else
              illegal_instr_o = 1'b1;
          end
          3'b101: begin
            if ((funct7 == 7'b0000000) || (funct7 == 7'b0100000))
              instr_load_s[RS_SHIFT] = 1'b1;
            else
              illegal_instr_o = 1'b1;
          end
          default: illegal_instr_o = 1'b1;
        endcase
      end

      7'b0110111,
      7'b0010111: instr_load_s[RS_ADD] = 1'b1;

      7'b1100011: begin
        unique case (funct3)
          3'b000, 3'b001, 3'b100, 3'b101, 3'b110, 3'b111:
            instr_load_s[RS_BRANCH] = 1'b1;
          default: illegal_instr_o = 1'b1;
        endcase
      end

      7'b1101111: instr_load_s[RS_JUMP] = 1'b1;
      7'b1100111: begin
        if (funct3 == 3'b000)
          instr_load_s[RS_JUMP] = 1'b1;
        else
          illegal_instr_o = 1'b1;
      end

      7'b0000011: begin
        unique case (funct3)
          3'b000, 3'b001, 3'b010, 3'b100, 3'b101:
            instr_load_s[RS_MEMORY] = 1'b1;
          default: illegal_instr_o = 1'b1;
        endcase
      end
      7'b0100011: begin
        unique case (funct3)
          3'b000, 3'b001, 3'b010: instr_load_s[RS_MEMORY] = 1'b1;
          default: illegal_instr_o = 1'b1;
        endcase
      end
      default: illegal_instr_o = 1'b1;
    endcase
  end

endmodule