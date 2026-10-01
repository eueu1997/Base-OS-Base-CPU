// Module      : riscv_fu_memory
// File        : riscv_fu_memory.sv
// Author      : GitHub Copilot
// Date        : 2026-09-25
// Version     : v1.1
// Functionality: Stateless memory model. Every aligned word reads MOCK_READ_DATA.
// Loads select little-endian lanes and extend data; stores complete without writes.
// Misaligned accesses are not trapped and accesses crossing a word are not modeled.
module riscv_fu_memory #(
  parameter int ROB_TAG_WIDTH = 3,
  parameter logic [31:0] MOCK_READ_DATA = 32'h80ff7f01
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
  output logic [31:0] addr_o,
  output logic store_o,
  output logic [1:0] width_o,
  output logic sign_ext_o,
  output logic [31:0] wdata_o,
  output logic illegal_instr_o
);
  assign dest_o = dest_i;
  logic [31:0] shifted_data_s;

  always_comb begin
    result_o = '0;
    valid_o = 1'b0;
    addr_o = '0;
    store_o = 1'b0;
    width_o = '0;
    sign_ext_o = 1'b0;
    wdata_o = '0;
    illegal_instr_o = 1'b0;
    shifted_data_s = '0;
    if (enable_i) begin
      case (instr_i[6:0])
        7'b0000011: begin
          addr_o = op_a_i + {{20{instr_i[31]}}, instr_i[31:20]};
          shifted_data_s = MOCK_READ_DATA >> {addr_o[1:0], 3'b000};
          valid_o = 1'b1;
          width_o = instr_i[13:12];
          sign_ext_o = !instr_i[14];
          case (instr_i[14:12])
            3'b000: result_o = {{24{shifted_data_s[7]}}, shifted_data_s[7:0]};
            3'b001: result_o = {{16{shifted_data_s[15]}}, shifted_data_s[15:0]};
            3'b010: result_o = shifted_data_s;
            3'b100: result_o = {24'b0, shifted_data_s[7:0]};
            3'b101: result_o = {16'b0, shifted_data_s[15:0]};
            default: begin
              valid_o = 1'b0;
              illegal_instr_o = 1'b1;
            end
          endcase
        end
        7'b0100011: begin
          addr_o = op_a_i + {{20{instr_i[31]}}, instr_i[31:25], instr_i[11:7]};
          width_o = instr_i[13:12];
          case (instr_i[14:12])
            3'b000, 3'b001, 3'b010: begin
              valid_o = 1'b1;
              store_o = 1'b1;
              wdata_o = op_b_i;
            end
            default: illegal_instr_o = 1'b1;
          endcase
        end
        default: illegal_instr_o = 1'b1;
      endcase
    end
  end
endmodule