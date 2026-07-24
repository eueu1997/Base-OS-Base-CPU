`timescale 1ns/1ps

module cache_set_tb;

  localparam time CLK_PERIOD = 10ns;

  logic        clk;
  logic        rst_n;
  logic [31:0] data_i;
  logic        en;
  logic        we;
  logic [31:0] data_o;

  int error_count;

  cache_set u_dut (
    .clk_i     (clk),
    .rst_n_i   (rst_n),
    .data_i    (data_i),
    .en_i      (en),
    .we_i      (we),
    .data_o    (data_o)
  );

  initial begin
    clk = 1'b0;
    forever #(CLK_PERIOD/2) clk = ~clk;
  end

  initial begin
    rst_n = 1'b0;
    en    = 1'b0;
    we    = 1'b0;
    data_i  = 32'h0;
    repeat (3) @(posedge clk);
    rst_n = 1'b1;
  end

  task automatic write_word(input logic [31:0] wdata);
    begin
      en     = 1'b1;
      we     = 1'b1;
      data_i = wdata;
      @(posedge clk);
      #1;
      $display("[TB][WRITE] data_i=0x%08h", wdata);
    end
  endtask

  task automatic idle_cycles(input int ncycles);
    int k;
    begin
      en = 1'b0;
      we = 1'b0;
      data_i = 32'h0;
      for (k = 0; k < ncycles; k++) begin
        @(posedge clk);
      end
      #1;
      $display("[TB][IDLE] %0d cycles", ncycles);
    end
  endtask

  task automatic read_hit(input logic [31:0] key);
    begin
      en = 1'b1;
      we = 1'b0;
      data_i = key;
      @(posedge clk);
      #1;
      if (data_o !== key) begin
        $display("[TB][ERROR] HIT read failed for 0x%08h, got 0x%08h", key, data_o);
        error_count++;
      end else begin
        $display("[TB][OK] HIT read 0x%08h", data_o);
      end
    end
  endtask

  task automatic read_miss(input logic [31:0] key);
    begin
      en = 1'b1;
      we = 1'b0;
      data_i = key;
      @(posedge clk);
      #1;
      if (data_o !== 32'h0000_0000) begin
        $display("[TB][ERROR] MISS read expected 0, key=0x%08h got 0x%08h", key, data_o);
        error_count++;
      end else begin
        $display("[TB][OK] MISS read key=0x%08h -> 0", key);
      end
    end
  endtask

  initial begin
    logic [31:0] d0;
    logic [31:0] d1;
    logic [31:0] d2;
    logic [31:0] d3;
    logic [31:0] n0;
    logic [31:0] n1;

    error_count = 0;

    d0 = 32'h1111_1111;
    d1 = 32'h2222_2222;
    d2 = 32'h3333_3333;
    d3 = 32'h4444_4444;
    n0 = 32'hAAAA_0001;
    n1 = 32'hBBBB_0002;

    @(posedge rst_n);

    // 1) write 4 different data for 4 consecutive c.c.
    write_word(d0);
    write_word(d1);
    write_word(d2);
    write_word(d3);

    // 2) wait some c.c. doing nothing
    idle_cycles(3);

    // 3) read the 4 different data
    read_hit(d2);
    read_hit(d1);
    read_hit(d0);
    read_hit(d3);

    // 4) try to read a data not present in memory
    read_miss(32'hDEAD_BEEF);

    // 5) write 2 new data
    write_word(n0);
    write_word(n1);

    // 6) read 2 old data and 2 new data
    // After two new writes, the oldest two entries are expected to be evicted.
    read_miss(d0);
    read_miss(d1);
    read_hit(n0);
    read_hit(n1);

    if (error_count == 0) begin
      $display("\n[TB][PASS] cache_set_tb passed");
    end else begin
      $display("\n[TB][FAIL] cache_set_tb errors=%0d", error_count);
    end

    $finish;
  end

endmodule
