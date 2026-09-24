module tomasulo_top # (
  parameter int FUNC_UNIT_N = 4,
  parameter int ROB_SIZE = 8,
  parameter int RS_SIZE = 4
)
(
  input logic clk_i,
  input logic rst_i,
  input logic [$clog2(FUNC_UNIT_N) - 1:0] fu_i,
  input logic [4:0] rd_i,
  input logic [4:0] rs1_i,
  input logic [4:0] rs2_i,
  // Output to functional units
  output logic [$clog2(FUNC_UNIT_N) - 1:0] [31:0] source_value1_o,
  output logic [$clog2(FUNC_UNIT_N) - 1:0] [31:0] source_value2_o,
  output logic [$clog2(FUNC_UNIT_N) - 1:0] [$clog2(ROB_SIZE)-1:0] destination_o,
  output logic [$clog2(FUNC_UNIT_N) - 1:0]        fu_en_o,
  // Input results from functional units
  input logic [$clog2(FUNC_UNIT_N) - 1:0] [31:0] result_value_i,
  input logic [$clog2(FUNC_UNIT_N) - 1:0] [$clog2(ROB_SIZE)-1:0] result_dest_i,
  input logic [$clog2(FUNC_UNIT_N) - 1:0]  result_en_i

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

  tomasulo_ROB #
  (
    .ROB_SIZE(ROB_SIZE),
    .FUNC_UNIT_N(FUNC_UNIT_N)
  )
  rob_i
  (
    .clk_i(clk_i),
    .rst_i(rst_i),
    .reg_dest_i(rd_i),
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
  .rsource1_issue_i(rs1_i),
  .rsource2_issue_i(rs2_i),
  .rdest_issue_i(rd_i),
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
     .instr_load_i(), // TODO : the load is one when the the instruction coming is for this FU
     .rob_dest_i(rob_pos_issued_inst_s),

     .fu_dest_i(result_dest_i), // TODO : qui la situazione è complessa . ogni riga di rs dovrebbe campionare ogni bus di uscita delle FU per vedere le destinazioni
     .fu_value_i(result_value_i),

     .rs_ready_o(fu_en_o[rs_index]),
     .rs1_o(source_value1_o[rs_index]),
     .rs2_o(source_value2_o[rs_index]),
     .rd_o(destination_o[rs_index])
    );
  end
endgenerate

endmodule