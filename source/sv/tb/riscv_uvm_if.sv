interface riscv_uvm_if #(
  parameter int LINE_BITS = 256
) (
  input logic clk_i,
  input logic rst_ni
);
  logic [31:0] haddr;
  logic [1:0]  htrans;
  logic        hwrite;
  logic [2:0]  hsize;
  logic [LINE_BITS-1:0] hwdata;
  logic [LINE_BITS-1:0] hrdata;
  logic        hready;
  logic        hresp;

  clocking monitor_cb @(posedge clk_i);
    default input #1step;
    input haddr, htrans, hwrite, hsize, hwdata, hrdata, hready, hresp;
  endclocking
endinterface

interface riscv_status_if (input logic clk_i);
  logic illegal_instr;
  logic [31:0] x1;
  logic [31:0] x2;
  logic [31:0] x3;
  logic [31:0] x4;
  logic [31:0] x5;
  logic [31:0] mem0;
  // Full register files, for end-of-test DUT vs. reference-model comparison.
  logic [31:0] dut_rf   [32];
  logic [31:0] model_rf [32];
endinterface

// Shared unified instruction/data memory storage, preloadable by UVM tests
// (see riscv_asm in riscv_uvm_pkg.sv for building instruction words).
interface riscv_mem_if #(
  parameter int MEM_WORDS = 1024
);
  logic [31:0] mem [0:MEM_WORDS-1];

  // Fills the whole array with a fixed word (default: ADDI x0,x0,0 == NOP).
  task automatic clear(input logic [31:0] fill_word = 32'h0000_0013);
    for (int i = 0; i < MEM_WORDS; i++)
      mem[i] = fill_word;
  endtask

  // Writes a test-supplied instruction/data stream starting at base_word.
  task automatic preload(input logic [31:0] words[], input int unsigned base_word = 0);
    foreach (words[i])
      mem[base_word + i] = words[i];
  endtask
endinterface

// Drive/monitor port for riscv_isa_ref_model (see source/sv/beh), used by the
// UVM reference-model monitor to feed fetched instructions and sample the
// model's predicted architectural effects.
interface riscv_ref_model_if (
  input logic clk_i,
  input logic rst_ni
);
  logic        instr_valid;
  logic [31:0] instr;
  logic [31:0] pc;
  logic [31:0] pc_next;
  logic        illegal_instr;
  logic        rf_we;
  logic [4:0]  rf_waddr;
  logic [31:0] rf_wdata;
  logic        mem_req;
  logic        mem_we;
  logic [31:0] mem_addr;
  logic [1:0]  mem_width;
  logic        mem_sign_ext;
  logic [31:0] mem_wdata;
  logic [31:0] mem_rdata;

  clocking mon_cb @(posedge clk_i);
    default input #1step;
    output instr, instr_valid;
    input  pc, pc_next, illegal_instr, rf_we, rf_waddr, rf_wdata,
           mem_req, mem_we, mem_addr, mem_width, mem_sign_ext, mem_wdata;
  endclocking
endinterface