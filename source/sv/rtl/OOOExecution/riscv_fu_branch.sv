// Module      : riscv_fu_branch
// File        : riscv_fu_branch.sv
// Author      : GitHub Copilot
// Date        : 2026-09-25
// Version     : v1.1
// Functionality: Combinational branch model; result is the taken flag, not RF data.
module riscv_fu_branch #(
  parameter int ROB_TAG_WIDTH = 3
)(
  input logic enable_i,
  input logic [31:0] instr_i,
  input logic [31:0] pc_i,
  input logic [31:0] op_a_i,
  input logic [31:0] op_b_i,
  input logic [ROB_TAG_WIDTH-1:0] dest_i,
  output logic [31:0] result_o,
  output logic [ROB_TAG_WIDTH-1:0] dest_o,
  output logic valid_o,
  output logic taken_o,
  output logic [31:0] target_o,
  output logic illegal_instr_o
);
  assign dest_o = dest_i;
  logic condition_s;
  logic encoding_valid_s;

  always_comb begin
    condition_s = 1'b0;
    encoding_valid_s = 1'b0;
    if (instr_i[6:0] == 7'b1100011) begin
      encoding_valid_s = 1'b1;
      case (instr_i[14:12])
        3'b000: condition_s = (op_a_i == op_b_i);
        3'b001: condition_s = (op_a_i != op_b_i);
        3'b100: condition_s = ($signed(op_a_i) < $signed(op_b_i));
        3'b101: condition_s = ($signed(op_a_i) >= $signed(op_b_i));
        3'b110: condition_s = (op_a_i < op_b_i);
        3'b111: condition_s = (op_a_i >= op_b_i);
        default: encoding_valid_s = 1'b0;
      endcase
    end
    valid_o = enable_i && encoding_valid_s;
    illegal_instr_o = enable_i && !encoding_valid_s;
    taken_o = valid_o && condition_s;
    target_o = valid_o ? pc_i + {{19{instr_i[31]}}, instr_i[31], instr_i[7],
                                instr_i[30:25], instr_i[11:8], 1'b0} : 32'b0;
    result_o = {31'b0, taken_o};
  end
endmodule