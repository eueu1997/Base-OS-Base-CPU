// Module      : riscv_fu_jump
// File        : riscv_fu_jump.sv
// Author      : GitHub Copilot
// Date        : 2026-09-25
// Version     : v1.1
// Functionality: Combinational JAL/JALR model returning PC+4 and redirect target.
module riscv_fu_jump #(
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
  output logic [31:0] target_o,
  output logic illegal_instr_o
);
  assign dest_o = dest_i;

  always_comb begin
    result_o = '0;
    target_o = '0;
    valid_o = 1'b0;
    illegal_instr_o = 1'b0;
    if (enable_i) begin
      case (instr_i[6:0])
        7'b1101111: begin
          valid_o = 1'b1;
          target_o = pc_i + {{11{instr_i[31]}}, instr_i[31], instr_i[19:12],
                            instr_i[20], instr_i[30:21], 1'b0};
        end
        7'b1100111: begin
          if (instr_i[14:12] == 3'b000) begin
            valid_o = 1'b1;
            target_o = (op_a_i + {{20{instr_i[31]}}, instr_i[31:20]}) & 32'hfffffffe;
          end else
            illegal_instr_o = 1'b1;
        end
        default: illegal_instr_o = 1'b1;
      endcase
      if (valid_o)
        result_o = pc_i + 32'd4;
    end
  end
endmodule