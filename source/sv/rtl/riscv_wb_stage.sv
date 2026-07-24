// -----------------------------------------------------------------------------
// Module      : riscv_wb_stage
// File        : riscv_wb_stage.sv
// Author      : spt9pad
// Date        : 2026-06-12
// Version     : v1.0
//
// Functionality
// - Implements the Write-Back (WB) stage for the RISC-V core.
// - Converts pipeline WB control/data into register-file write interface signals.
// - Blocks writes to x0 to preserve architectural zero-register behavior.
// - Contains data memory (DMEM) instance for load/store operations.
// - Handles load result writeback by muxing between ALU and load data.
//
// Integration Notes
// - WB outputs are sampled in stage-local registers before driving regfile.
// - DMEM read data is used as source for load writeback.
// -----
// -----------------------------------------------------------------------------
module riscv_wb_stage (
  input  logic        clk_i,
  input  logic        rst_ni,

  // ALU writeback from ID/EX stage.
  input  logic [4:0]  wb_rd_i,
  input  logic [31:0] wb_data_i,
  input  logic        wb_we_i,

  // Memory access signals from ID/EX stage.
  input  logic        mem_req_i,
  input  logic [31:0] mem_addr_i,
  input  logic        mem_we_i,
  input  logic [1:0]  mem_width_i,
  input  logic        mem_sign_ext_i,
  input  logic [31:0] mem_wdata_i,
  input  logic        load_valid_i,
  input  logic [4:0]  load_rd_i,

  output logic        rf_we_o,
  output logic [4:0]  rf_waddr_o,
  output logic [31:0] rf_wdata_o
);

  // DMEM read interface.
  logic [31:0] dmem_rdata;
  logic        dmem_rvalid;

  // Combinational WB mux results before output registers.
  logic        rf_we_d;
  logic [4:0]  rf_waddr_d;
  logic [31:0] rf_wdata_d;

  // Data memory instance (contains load/store operations).
  // Receives already-latched signals from EX/WB stage (no register stage here).
  riscv_dmem #(
    .DMEM_WORDS (1024)
  ) u_dmem (
    .clk_i      (clk_i),
    .req_i      (mem_req_i),
    .addr_i     (mem_addr_i),
    .we_i       (mem_we_i),
    .width_i    (mem_width_i),
    .sign_ext_i (mem_sign_ext_i),
    .wdata_i    (mem_wdata_i),
    .rdata_o    (dmem_rdata),
    .rvalid_o   (dmem_rvalid)
  );

  // Convert pipeline writeback info into register-file write controls.
  // Mux between ALU result (wb_data_i) and load result (dmem_rdata).
  always_comb begin
    // Select writeback data: load data if load_valid_i, else ALU data.
    logic [31:0] wb_data_mux;
    logic [4:0]  wb_rd_mux;
    logic        wb_we_mux;

    if (load_valid_i & dmem_rvalid) begin
      // Load result: write load_rd_i with dmem_rdata.
      wb_data_mux = dmem_rdata;
      wb_rd_mux   = load_rd_i;
      wb_we_mux   = 1'b1;  // Load always writes to rd (unless rd=x0).
    end else begin
      // ALU result: use wb_data_i, wb_rd_i, wb_we_i as-is.
      wb_data_mux = wb_data_i;
      wb_rd_mux   = wb_rd_i;
      wb_we_mux   = wb_we_i;
    end

    // x0 is hardwired to zero and must never be written.
    rf_we_d    = wb_we_mux & (wb_rd_mux != 5'd0);
    rf_waddr_d = wb_rd_mux;
    rf_wdata_d = wb_data_mux;
  end

  // Stage output registers.
  always_ff @(posedge clk_i or negedge rst_ni) begin
    if (!rst_ni) begin
      rf_we_o    <= 1'b0;
      rf_waddr_o <= 5'd0;
      rf_wdata_o <= 32'h0000_0000;
    end else begin
      rf_we_o    <= rf_we_d;
      rf_waddr_o <= rf_waddr_d;
      rf_wdata_o <= rf_wdata_d;
    end
  end

endmodule
