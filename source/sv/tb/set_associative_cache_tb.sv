`timescale 1ns/1ps

module set_associative_cache_tb;

  localparam time CLK_PERIOD = 10ns;
  localparam int  NUM_SETS_TB = 8;
  localparam int  NUM_WAYS_TB = 4;
  localparam int  TAG_SIZE_TB = 27;
  localparam int  LINE_W_TB   = 32 + TAG_SIZE_TB;

  logic        clk;
  logic        rst_n;
  logic        en;
  logic        we;
  logic [31:0] addr;
  logic [31:0] wdata;
  logic [31:0] rdata;
  logic        hit;

  int error_count;

  // Flat top-level mirrors for easier visibility in SimVision.
  logic [LINE_W_TB-1:0] cache_way_mirror [NUM_SETS_TB-1:0][NUM_WAYS_TB-1:0];
  logic [LINE_W_TB-1:0] cache_set_data_mirror [NUM_SETS_TB-1:0];
  logic [NUM_SETS_TB-1:0] cache_set_en_mirror;

  set_associative_cache u_dut (
    .clk_i   (clk),
    .rst_ni  (rst_n),
    .en_i    (en),
    .addr_i  (addr),
    .wdata_i (wdata),
    .we_i    (we),
    .rdata_o (rdata),
    .hit_o   (hit)
  );

  genvar s;
  generate
    for (s = 0; s < NUM_SETS_TB; s++) begin : g_tb_mirror
      assign cache_way_mirror[s][0] = u_dut.g_cache_set[s].u_cache_set.data_to_comp[0];
      assign cache_way_mirror[s][1] = u_dut.g_cache_set[s].u_cache_set.data_to_comp[1];
      assign cache_way_mirror[s][2] = u_dut.g_cache_set[s].u_cache_set.data_to_comp[2];
      assign cache_way_mirror[s][3] = u_dut.g_cache_set[s].u_cache_set.data_to_comp[3];
      assign cache_set_data_mirror[s] = u_dut.g_cache_set[s].u_cache_set.data_o;
      assign cache_set_en_mirror[s] = u_dut.set_en_s[s];
    end
  endgenerate

  function automatic logic [31:0] make_addr(
    input logic [26:0] tag,
    input logic [2:0]  set_idx
  );
    make_addr = {tag, set_idx, 2'b00};
  endfunction

  initial begin
    clk = 1'b0;
    forever #(CLK_PERIOD/2) clk = ~clk;
  end

  initial begin
    rst_n = 1'b0;
    en    = 1'b0;
    we    = 1'b0;
    addr  = 32'h0;
    wdata = 32'h0;
    repeat (3) @(posedge clk);
    rst_n = 1'b1;
  end

  task automatic do_write(input logic [31:0] wr_addr, input logic [31:0] wr_data);
    begin
      en    = 1'b1;
      we    = 1'b1;
      addr  = wr_addr;
      wdata = wr_data;
      @(posedge clk);
      #1;
      $display("[TB][WRITE] addr=0x%08h data=0x%08h", wr_addr, wr_data);
    end
  endtask

  task automatic do_read_expect_hit(input logic [31:0] rd_addr, input logic [31:0] exp_data);
    begin
      en    = 1'b1;
      we    = 1'b0;
      addr  = rd_addr;
      wdata = 32'h0;
      @(posedge clk);
      #1;

      if (hit !== 1'b1) begin
        $display("[TB][ERROR] expected HIT at addr=0x%08h", rd_addr);
        error_count++;
      end

      if (rdata !== exp_data) begin
        $display("[TB][ERROR] addr=0x%08h expected data=0x%08h got=0x%08h", rd_addr, exp_data, rdata);
        error_count++;
      end else begin
        $display("[TB][OK] HIT addr=0x%08h data=0x%08h", rd_addr, rdata);
      end
    end
  endtask

  task automatic do_read_expect_miss(input logic [31:0] rd_addr);
    begin
      en    = 1'b1;
      we    = 1'b0;
      addr  = rd_addr;
      wdata = 32'h0;
      @(posedge clk);
      #1;

      if (hit !== 1'b0) begin
        $display("[TB][ERROR] expected MISS at addr=0x%08h", rd_addr);
        error_count++;
      end else begin
        $display("[TB][OK] MISS addr=0x%08h", rd_addr);
      end
    end
  endtask

  initial begin
    logic [31:0] a0;
    logic [31:0] a1;
    logic [31:0] a2;
    logic [31:0] a3;
    logic [31:0] b0;
    logic [31:0] b1;
    logic [31:0] m0;
    logic [31:0] m1;

    logic [31:0] d0;
    logic [31:0] d1;
    logic [31:0] d2;
    logic [31:0] d3;
    logic [31:0] n0;
    logic [31:0] n1;
    logic [31:0] u1;
    logic [31:0] u3;

    error_count = 0;

    // Initial 4 addresses in set 2, different tags.
    a0 = make_addr(27'h000001, 3'd2);
    a1 = make_addr(27'h000002, 3'd2);
    a2 = make_addr(27'h000003, 3'd2);
    a3 = make_addr(27'h000004, 3'd2);

    // Two new addresses in set 6.
    b0 = make_addr(27'h000011, 3'd6);
    b1 = make_addr(27'h000012, 3'd6);

    // Two addresses guaranteed absent (different set/tag).
    m0 = make_addr(27'h000021, 3'd1);
    m1 = make_addr(27'h000022, 3'd1);

    d0 = 32'h1111_0001;
    d1 = 32'h2222_0002;
    d2 = 32'h3333_0003;
    d3 = 32'h4444_0004;

    n0 = 32'hAAAA_1001;
    n1 = 32'hBBBB_1002;

    u1 = 32'hDEAD_0002;
    u3 = 32'hBEEF_0004;

    @(posedge rst_n);

    $display("\n[TB] Step 1: Write 4 values");
    do_write(a0, d0);
    do_write(a1, d1);
    do_write(a2, d2);
    do_write(a3, d3);

    $display("\n[TB] Step 2: Read the 4 values in different order");
    do_read_expect_hit(a2, d2);
    do_read_expect_hit(a0, d0);
    do_read_expect_hit(a3, d3);
    do_read_expect_hit(a1, d1);

    $display("\n[TB] Step 3: Read 2 values not present");
    do_read_expect_miss(m0);
    do_read_expect_miss(m1);

    $display("\n[TB] Step 4: Read 4 values present");
    do_read_expect_hit(a0, d0);
    do_read_expect_hit(a1, d1);
    do_read_expect_hit(a2, d2);
    do_read_expect_hit(a3, d3);

    $display("\n[TB] Step 5: Write 2 new values to 2 new addresses");
    do_write(b0, n0);
    do_write(b1, n1);

    $display("\n[TB] Step 6: Write 2 new values to 2 addresses already present");
    do_write(a1, u1);
    do_write(a3, u3);

    $display("\n[TB] Step 7: Read these last 4 values");
    do_read_expect_hit(b0, n0);
    do_read_expect_hit(b1, n1);
    do_read_expect_hit(a1, u1);
    do_read_expect_hit(a3, u3);

    if (error_count == 0) begin
      $display("\n[TB][PASS] set_associative_cache_tb passed");
    end else begin
      $display("\n[TB][FAIL] set_associative_cache_tb errors=%0d", error_count);
    end

    $finish;
  end

endmodule
