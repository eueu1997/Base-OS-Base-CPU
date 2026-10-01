`timescale 1ns/1ps

module tomasulo_rs_test_case #(
  parameter int DEPTH = 4
)(
  output logic done_o
);
  logic clk = 1'b0;
  logic rst_n = 1'b0;
  logic load = 1'b0;
  logic avail1 = 1'b0;
  logic avail2 = 1'b0;
  logic [31:0] value1 = '0, value2 = '0;
  logic [3:0] tag1 = 4'd1, tag2 = 4'd2, destination = '0;
  logic [31:0] instruction = '0, pc = '0;
  logic [3:0][3:0] fu_dest = '0;
  logic [3:0][31:0] fu_value = '0;
  logic [3:0] fu_valid = '0;
  logic issue_ready, dispatch_valid;
  logic full_rs, empty_rs;
  logic fu_enable = 1'b0;
  logic [31:0] source1, source2, dispatched_instruction, dispatched_pc;
  logic [3:0] dispatched_destination;

  assign issue_ready = !full_rs;

  tomasulo_RS_top #(.ROB_SIZE(16), .FUNC_UNIT_N(4), .RS_SIZE(DEPTH)) dut (
    .clk_i(clk), .rst_ni(rst_n),
    .register_value1_i(value1), .register_value2_i(value2),
    .register1_avail_i(avail1), .register2_avail_i(avail2),
    .rob_value1_s(tag1), .rob_value2_s(tag2),
    .instr_load_i(load), .instr_i(instruction), .pc_i(pc), .rob_dest_i(destination),
    .fu_dest_i(fu_dest), .fu_value_i(fu_value), .fu_valid_i(fu_valid),
    .full_rs_o(full_rs), .empty_rs_o(empty_rs), .fu_en_i(fu_enable),
    .fu_exe_en_o(dispatch_valid), .rs1_o(source1), .rs2_o(source2),
    .instr_o(dispatched_instruction), .pc_o(dispatched_pc), .rd_o(dispatched_destination)
  );

  always #5 clk = ~clk;

  task automatic tick;
    @(posedge clk);
    #1;
  endtask

  task automatic drive_instruction(input int identity, input logic operands_ready);
    load = 1'b1;
    avail1 = operands_ready;
    avail2 = operands_ready;
    value1 = 32'h100 + identity;
    value2 = 32'h200 + identity;
    destination = 4'(identity);
    instruction = 32'h12340000 + identity;
    pc = 32'h1000 + 32'(identity * 4);
  endtask

  task automatic expect_idle;
    if ({dispatch_valid, source1, source2, dispatched_instruction,
         dispatched_pc, dispatched_destination} !== '0)
      $fatal(1, "DEPTH=%0d unexpected dispatch or stale idle outputs", DEPTH);
  endtask

  task automatic expect_dispatch(input int identity, input logic [31:0] expected1,
                                 input logic [31:0] expected2);
    if ((dispatch_valid !== 1'b1) || (source1 !== expected1) || (source2 !== expected2) ||
        (dispatched_destination !== 4'(identity)) ||
        (dispatched_instruction !== (32'h12340000 + identity)) ||
        (dispatched_pc !== (32'h1000 + 32'(identity * 4))))
      $fatal(1, "DEPTH=%0d dispatch mismatch for identity %0d", DEPTH, identity);
  endtask

  task automatic fill_blocked;
    for (int slot_index = 0; slot_index < DEPTH; slot_index++) begin
      @(negedge clk);
      drive_instruction(slot_index + 1, 1'b0);
      if (issue_ready !== 1'b1)
        $fatal(1, "DEPTH=%0d capacity unavailable before filling", DEPTH);
      tick();
      expect_idle();
    end
    if (issue_ready !== 1'b0)
      $fatal(1, "DEPTH=%0d full station accepted another instruction", DEPTH);
  endtask

  initial begin
    done_o = 1'b0;
    tick();
    if ({dispatch_valid, issue_ready} !== '0)
      $fatal(1, "DEPTH=%0d reset flags mismatch", DEPTH);
    @(negedge clk);
    rst_n = 1'b1;
    #1;
    if (!empty_rs || !issue_ready)
      $fatal(1, "DEPTH=%0d reset did not restore capacity", DEPTH);

    fu_enable = 1'b1;
    fill_blocked();
    @(negedge clk);
    drive_instruction(15, 1'b1);
    fu_dest[0] = 4'd1;
    fu_value[0] = 32'hbad;
    tick();
    expect_idle();

    @(negedge clk);
    load = 1'b0;
    fu_valid = 4'b0001;
    fu_value[0] = 32'h11;
    tick();
    expect_idle();
    @(negedge clk);
    fu_valid = 4'b1000;
    fu_dest[3] = 4'd2;
    fu_value[3] = 32'h22;
    tick();
    for (int slot_index = 0; slot_index < DEPTH; slot_index++) begin
      expect_dispatch(slot_index + 1, 32'h11, 32'h22);
      @(negedge clk);
      fu_valid = '0;
      tick();
    end
    expect_idle();
    if (!empty_rs)
      $fatal(1, "DEPTH=%0d drain did not free every slot", DEPTH);

    fill_blocked();
    @(negedge clk);
    load = 1'b0;
    fu_enable = 1'b0;
    fu_valid = 4'b1001;
    tick();
    expect_idle();
    repeat (3) begin
      @(negedge clk);
      fu_valid = '0;
      tick();
      expect_idle();
      if (!full_rs || empty_rs)
        $fatal(1, "DEPTH=%0d stalled entries were released", DEPTH);
    end
    @(negedge clk);
    fu_enable = 1'b1;
    #1;
    expect_dispatch(1, 32'h11, 32'h22);
    tick();
    if (!issue_ready)
      $fatal(1, "DEPTH=%0d dispatch did not release the slot", DEPTH);
    @(negedge clk);
    drive_instruction(12, 1'b1);
    #1;
    if (DEPTH > 1)
      expect_dispatch(2, 32'h11, 32'h22);
    else
      expect_idle();
    tick();
    expect_dispatch(12, 32'h10c, 32'h20c);
    @(negedge clk);
    load = 1'b0;
    tick();
    for (int slot_index = 2; slot_index < DEPTH; slot_index++) begin
      expect_dispatch(slot_index + 1, 32'h11, 32'h22);
      @(negedge clk);
      tick();
    end
    expect_idle();

    @(negedge clk);
    drive_instruction(9, 1'b0);
    tag1 = 4'd3;
    tag2 = 4'd3;
    fu_valid = 4'b0110;
    fu_dest[1] = 4'd3;
    fu_dest[2] = 4'd3;
    fu_value[1] = 32'h33;
    fu_value[2] = 32'hbad;
    tick();
    expect_dispatch(9, 32'h33, 32'h33);
    @(negedge clk);
    load = 1'b0;
    fu_valid = '0;
    tick();
    expect_idle();

    if (DEPTH > 1) begin
      @(negedge clk);
      tag1 = 4'd1;
      tag2 = 4'd2;
      drive_instruction(1, 1'b0);
      tick();
      expect_idle();
      @(negedge clk);
      drive_instruction(2, 1'b1);
      tick();
      expect_dispatch(2, 32'h102, 32'h202);
      @(negedge clk);
      load = 1'b0;
      tick();
      expect_idle();
      @(negedge clk);
      fu_valid = 4'b1001;
      tick();
      expect_dispatch(1, 32'h11, 32'h22);
      @(negedge clk);
      fu_valid = '0;
      tick();
      expect_idle();
    end

    @(negedge clk);
    drive_instruction(10, 1'b0);
    tick();
    @(negedge clk);
    rst_n = 1'b0;
    load = 1'b0;
    #1;
    if ({dispatch_valid, issue_ready, source1, source2,
         dispatched_instruction, dispatched_pc, dispatched_destination} !== '0)
      $fatal(1, "DEPTH=%0d asynchronous reset did not clear state/outputs", DEPTH);
    @(negedge clk);
    rst_n = 1'b1;
    repeat (3) begin
      tick();
      expect_idle();
    end
    if (issue_ready !== 1'b1)
      $fatal(1, "DEPTH=%0d reset did not restore capacity", DEPTH);
    $display("PASS: reservation station depth %0d", DEPTH);
    done_o = 1'b1;
  end
endmodule

module tomasulo_rs_tb;
  logic [2:0] done;
  tomasulo_rs_test_case #(.DEPTH(1)) u_depth1 (.done_o(done[0]));
  tomasulo_rs_test_case #(.DEPTH(3)) u_depth3 (.done_o(done[1]));
  tomasulo_rs_test_case #(.DEPTH(4)) u_depth4 (.done_o(done[2]));

  initial begin
    wait (&done);
    $finish;
  end

  initial begin
    #10000;
    $fatal(1, "Reservation station test timed out");
  end
endmodule