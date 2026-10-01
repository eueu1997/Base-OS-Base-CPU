`timescale 1ns/1ps

module riscv_ooo_id_ex_stage_tb;
  localparam time CLK_PERIOD = 10ns;
  localparam int INSTRUCTION_COUNT = 50;
  localparam int OBSERVATION_CYCLES = 100;

  logic clk = 1'b0;
  logic rst_n = 1'b0;
  logic valid = 1'b0;
  logic [31:0] instr = '0;
  logic [31:0] pc = 32'h00001000;
  int instruction_index;

  logic [31:0] instruction_stream [0:INSTRUCTION_COUNT-1] = '{
    32'hfff08193, // addi  x3, x1, -1
    32'h0020c1b3, // xor   x3, x1, x2
    32'hffc0a183, // lw    x3, -4(x1)
    32'h402081b3, // sub   x3, x1, x2
    32'h00208463, // beq   x1, x2, .+8
    32'h01f09193, // slli  x3, x1, 31
    32'hfffff1b7, // lui   x3, 0xfffff
    32'hfe208e23, // sb    x2, -4(x1)
    32'h0020b1b3, // sltu  x3, x1, x2
    32'h008001ef, // jal   x3, .+8
    32'h002081b3, // add   x3, x1, x2
    32'hfff0e193, // ori   x3, x1, -1
    32'h0020d1b3, // srl   x3, x1, x2
    32'hffc09183, // lh    x3, -4(x1)
    32'h00209463, // bne   x1, x2, .+8
    32'hfff0a193, // slti  x3, x1, -1
    32'hffc081e7, // jalr  x3, -4(x1)
    32'h0020f1b3, // and   x3, x1, x2
    32'hfe20ae23, // sw    x2, -4(x1)
    32'hfffff197, // auipc x3, 0xfffff
    32'h4020d1b3, // sra   x3, x1, x2
    32'hffc0c183, // lbu   x3, -4(x1)
    32'h0020c463, // blt   x1, x2, .+8
    32'hfff0c193, // xori  x3, x1, -1
    32'h002091b3, // sll   x3, x1, x2
    32'hfff0b193, // sltiu x3, x1, -1
    32'hfe209e23, // sh    x2, -4(x1)
    32'h0020e1b3, // or    x3, x1, x2
    32'hffc0d183, // lhu   x3, -4(x1)
    32'h0020d463, // bge   x1, x2, .+8
    32'h01f0d193, // srli  x3, x1, 31
    32'hfff0f193, // andi  x3, x1, -1
    32'h0020a1b3, // slt   x3, x1, x2
    32'hffc08183, // lb    x3, -4(x1)
    32'h0020e463, // bltu  x1, x2, .+8
    32'h41f0d193, // srai  x3, x1, 31
    32'h0020f463, // bgeu  x1, x2, .+8
    32'h00500093, // addi  x1, x0, 5
    32'h00300113, // addi  x2, x0, 3
    32'h001101b3, // add   x3, x2, x1
    32'h40110233, // sub   x4, x2, x1
    32'h00111293, // sll   x5, x2, x1
    32'h00116333, // or    x6, x2, x1
    32'h001123b3, // slt   x7, x2, x1
    32'h00408463, // beq   x1, x4, .+8
    32'h010002ef, // jal   x5, .+16
    32'h00012303, // lw    x6, 0(x2)
    32'h00312223, // sw    x3, 4(x2)
    32'h000023b7, // lui   x7, 0x2
    32'h00002417  // auipc x8, 0x2
  };

  riscv_id_ex_stage u_dut (
    .clk_i(clk),
    .rst_ni(rst_n),
    .valid_i(valid),
    .hold_i(1'b0),
    .pc_i(pc),
    .instr_i(instr),
    .wb_valid_o(),
    .wb_rd_o(),
    .wb_data_o(),
    .wb_we_o(),
    .pc_redirect_valid_o(),
    .pc_redirect_addr_o(),
    .illegal_instr_o(),
    .wb_rf_we_i(1'b0),
    .wb_rf_waddr_i(1'b0),
    .wb_rf_wdata_i(1'b0),
    .mem_req_o(),
    .mem_addr_o(),
    .mem_we_o(),
    .mem_width_o(),
    .mem_sign_ext_o(),
    .mem_wdata_o(),
    .load_valid_o(),
    .load_rd_o()
  );

  always #(CLK_PERIOD / 2) clk = ~clk;

  initial begin
    $dumpfile("riscv_ooo_id_ex_stage_tb.vcd");
    $dumpvars(0, riscv_ooo_id_ex_stage_tb);
  end

  initial begin
    repeat (5) @(negedge clk);
    rst_n = 1'b1;
    valid = 1'b1;
    for (instruction_index = 0; instruction_index < INSTRUCTION_COUNT; instruction_index++) begin
      instr = instruction_stream[instruction_index];
      pc = 32'h00001000 + 32'(instruction_index * 4);
      @(negedge clk);
    end
    valid = 1'b0;
    instr = '0;
    repeat (OBSERVATION_CYCLES) @(negedge clk);
    $finish;
  end
endmodule