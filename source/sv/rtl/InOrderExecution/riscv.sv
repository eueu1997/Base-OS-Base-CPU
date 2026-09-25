module riscv # (
    parameter int LINE_WORDS = 8,
  parameter int LINE_LENGHT = 2**LINE_WORDS
) (
  input  logic        clk_i,
  input  logic        rst_ni,

  output logic        illegal_instr_o,

  // Read-only AHB-Lite master port toward the system bus (instruction fetch).
  output logic [31:0] ahb_haddr_o,
  output logic [1:0]  ahb_htrans_o,
  output logic        ahb_hwrite_o,
  output logic [2:0]  ahb_hsize_o,
  input  logic [LINE_LENGHT-1:0] ahb_hrdata_i,
  input  logic        ahb_hready_i,
  input  logic        ahb_hresp_i,

  // Read/write AHB-Lite master port toward the system bus (data access).
  output logic [31:0] dahb_haddr_o,
  output logic [1:0]  dahb_htrans_o,
  output logic        dahb_hwrite_o,
  output logic [2:0]  dahb_hsize_o,
  output logic [LINE_LENGHT-1:0] dahb_hwdata_o,
  input  logic [LINE_LENGHT-1:0] dahb_hrdata_i,
  input  logic        dahb_hready_i,
  input  logic        dahb_hresp_i
);

  // IF stage outputs.
  logic        if_valid_q;
  logic [31:0] if_pc_q;
  logic [31:0] if_instr_q;

  // Register-file read addresses/data derived from IF/ID instruction.
  logic [4:0] rs1_addr;
  logic [4:0] rs2_addr;
  logic [31:0] rs1_data;
  logic [31:0] rs2_data;
  logic [31:0] rs1_data_fwd;
  logic [31:0] rs2_data_fwd;
  logic        rs1_wbfwd_en;
  logic        rs2_wbfwd_en;
  logic        rs1_exfwd_en;
  logic        rs2_exfwd_en;
  logic        load_use_stall;

  // Asserted by the WB stage's data cache controller while a multi-cycle
  // load/store access is in flight. Freezes both IF (via stall_i, alongside
  // the existing load-use interlock) and ID/EX's own output registers (via
  // hold_i) so the in-flight memory instruction stays parked at the ID/EX->WB
  // boundary until the access completes.
  logic        mem_stall;

  // Registered outputs from ID/EX stage.
  logic        id_wb_valid_q;
  logic [4:0]  id_wb_rd_q;
  logic [31:0] id_wb_data_q;
  logic        id_wb_we_q;
  logic        id_pc_redirect_valid_q;
  logic [31:0] id_pc_redirect_addr_q;

  // Registered memory access signals from ID/EX stage.
  logic        mem_req_q;
  logic [31:0] mem_addr_q;
  logic        mem_we_q;
  logic [1:0]  mem_width_q;
  logic        mem_sign_ext_q;
  logic [31:0] mem_wdata_q;
  logic        load_valid_q;
  logic [4:0]  load_rd_q;

  // WB stage outputs driving the register file.
  logic        wb_rf_we;
  logic [4:0]  wb_rf_waddr;
  logic [31:0] wb_rf_wdata;

  // IF stage: compute instruction address and sequential next PC.
  riscv_if_stage #(
    .LINE_WORDS    (LINE_WORDS),
    .LINE_LENGHT   (LINE_LENGHT)
  ) u_if_stage (
    .clk_i               (clk_i),               // Core clock domain for IF/ID stage registers.
    .rst_ni              (rst_ni),               // Active-low reset for IF stage state.
    .pc_redirect_valid_i (id_pc_redirect_valid_q), // Registered branch/jump redirect request from ID/EX stage.
    .pc_redirect_addr_i  (id_pc_redirect_addr_q),  // Registered branch/jump redirect target from ID/EX stage.
    .stall_i             (load_use_stall | mem_stall), // Hold PC and IF/ID register on load-use interlock or D-cache stall.
    .flush_i             (id_pc_redirect_valid_q & if_valid_q), // Flush IF/ID register on taken branch/jump from ID/EX.
    .if_valid_o          (if_valid_q),           // Registered IF/ID valid consumed by ID/EX stage.
    .if_pc_o             (if_pc_q),              // Registered IF/ID PC consumed by ID/EX stage.
    .if_instr_o          (if_instr_q),           // Registered IF/ID instruction consumed by ID/EX stage.
    .ahb_haddr_o         (ahb_haddr_o),          // Instruction fetch AHB-Lite address phase, passed through to top.
    .ahb_htrans_o        (ahb_htrans_o),         // Instruction fetch AHB-Lite transfer type, passed through to top.
    .ahb_hwrite_o        (ahb_hwrite_o),         // Tied low: instruction fetch is read-only.
    .ahb_hsize_o         (ahb_hsize_o),          // Instruction fetch AHB-Lite transfer size (word).
    .ahb_hrdata_i        (ahb_hrdata_i),         // Instruction fetch AHB-Lite read data from the system bus.
    .ahb_hready_i        (ahb_hready_i),         // Instruction fetch AHB-Lite transfer-done/wait-state input.
    .ahb_hresp_i         (ahb_hresp_i)           // Instruction fetch AHB-Lite response (not evaluated in v1).
  );

  assign rs1_addr = if_instr_q[19:15];
  assign rs2_addr = if_instr_q[24:20];

  // Load-use interlock: stall one cycle when a load destination is consumed
  // by the instruction currently held in IF/ID.
  assign load_use_stall = load_valid_q & (load_rd_q != 5'd0) &
                          ((load_rd_q == rs1_addr) | (load_rd_q == rs2_addr));

  // WB-to-EX forwarding: resolves RAW with one instruction gap (N-2 -> N).
  assign rs1_wbfwd_en = wb_rf_we & (wb_rf_waddr != 5'd0) & (wb_rf_waddr == rs1_addr);
  assign rs2_wbfwd_en = wb_rf_we & (wb_rf_waddr != 5'd0) & (wb_rf_waddr == rs2_addr);

  // EX-to-EX forwarding: resolves back-to-back ALU RAW hazard (N-1 -> N).
  // Forwards ALU/PC result from ID/EX registered output when destination matches.
  // Does not cover load-use hazards (DMEM data not yet available at this stage).
  assign rs1_exfwd_en = id_wb_we_q & (id_wb_rd_q != 5'd0) & (id_wb_rd_q == rs1_addr);
  assign rs2_exfwd_en = id_wb_we_q & (id_wb_rd_q != 5'd0) & (id_wb_rd_q == rs2_addr);

  // EX forwarding takes priority over WB forwarding (more recent value).
  assign rs1_data_fwd = rs1_exfwd_en ? id_wb_data_q :
                        rs1_wbfwd_en ? wb_rf_wdata  : rs1_data;
  assign rs2_data_fwd = rs2_exfwd_en ? id_wb_data_q :
                        rs2_wbfwd_en ? wb_rf_wdata  : rs2_data;

  // Dedicated register file instance.
  riscv_regfile u_regfile (
    .clk_i      (clk_i),       // Core clock for synchronous write port.
    .rst_ni     (rst_ni),      // Active-low reset for x1..x31 initialization.
    .rs1_addr_i (rs1_addr),    // Source register 1 index decoded from IF/ID instruction.
    .rs2_addr_i (rs2_addr),    // Source register 2 index decoded from IF/ID instruction.
    .rs1_data_o (rs1_data),    // Source register 1 data forwarded to ID/EX operand mux.
    .rs2_data_o (rs2_data),    // Source register 2 data forwarded to ID/EX operand mux.
    .we_i       (wb_rf_we),    // Write enable generated by WB stage after final mux.
    .waddr_i    (wb_rf_waddr), // Destination register index from WB stage.
    .wdata_i    (wb_rf_wdata)  // Final writeback data from WB stage (ALU or load).
  );

  // ID/EX stage: decode and execute minimal RV32I operations.
  riscv_id_ex_stage u_id_ex_stage (
    .clk_i              (clk_i),                  // Core clock for stage output registers.
    .rst_ni             (rst_ni),                 // Active-low reset for ID/EX outputs.
    .hold_i             (mem_stall),              // Freeze stage outputs while WB's D-cache access is in flight.
    .valid_i            (if_valid_q & ~load_use_stall & ~id_pc_redirect_valid_q), // Kill wrong-path instruction on redirect and inject bubble on load-use interlock.
    .pc_i               (if_pc_q),                // IF/ID PC used by AUIPC/JAL/JALR/BRANCH address generation.
    .instr_i            (if_instr_q),             // IF/ID instruction word to decode.
    .rs1_data_i         (rs1_data_fwd),           // Operand A after WB-to-ID forwarding.
    .rs2_data_i         (rs2_data_fwd),           // Operand B after WB-to-ID forwarding.
    .wb_valid_o         (id_wb_valid_q),          // Registered WB-valid propagated to WB stage.
    .wb_rd_o            (id_wb_rd_q),             // Registered WB destination register propagated to WB stage.
    .wb_data_o          (id_wb_data_q),           // Registered ALU/PC result propagated to WB stage.
    .wb_we_o            (id_wb_we_q),             // Registered WB write enable propagated to WB stage.
    .pc_redirect_valid_o(id_pc_redirect_valid_q), // Registered branch/jump redirect request to top-level PC logic.
    .pc_redirect_addr_o (id_pc_redirect_addr_q),  // Registered redirect target address to top-level PC logic.
    .illegal_instr_o    (illegal_instr_o),        // Registered illegal-instruction flag exported at top level.
    // Memory access signals for load/store
    .mem_req_o          (mem_req_q),              // Registered data-memory request to WB stage/DMEM.
    .mem_addr_o         (mem_addr_q),             // Registered data-memory address to WB stage/DMEM.
    .mem_we_o           (mem_we_q),               // Registered data-memory write enable to WB stage/DMEM.
    .mem_width_o        (mem_width_q),            // Registered access size (byte/half/word) to WB stage/DMEM.
    .mem_sign_ext_o     (mem_sign_ext_q),         // Registered load sign-extension control to WB stage/DMEM.
    .mem_wdata_o        (mem_wdata_q),            // Registered store write data to WB stage/DMEM.
    // Load result writeback interface
    .load_valid_o       (load_valid_q),           // Registered load transaction marker for WB mux selection.
    .load_rd_o          (load_rd_q)               // Registered load destination register for WB mux selection.
  );

  riscv_wb_stage #(
    .LINE_WORDS  (LINE_WORDS),
    .LINE_LENGHT (LINE_LENGHT)
  ) u_wb_stage (
    .clk_i      (clk_i),      // Core clock for WB output registers and DMEM writes.
    .rst_ni     (rst_ni),     // Active-low reset for WB output registers.
    // ALU writeback from ID/EX stage outputs.
    .wb_rd_i    (id_wb_rd_q),    // Destination register index for ALU/PC writeback path.
    .wb_data_i  (id_wb_data_q),  // ALU/PC writeback payload from ID/EX.
    .wb_we_i    (id_wb_we_q),    // ALU/PC write enable from ID/EX.
    // Memory access signals from ID/EX stage outputs.
    .mem_req_i      (mem_req_q),      // Data-memory request for load/store.
    .mem_addr_i     (mem_addr_q),     // Data-memory byte address.
    .mem_we_i       (mem_we_q),       // Data-memory write enable (store when high).
    .mem_width_i    (mem_width_q),    // Data-memory transfer size (byte/half/word).
    .mem_sign_ext_i (mem_sign_ext_q), // Load sign/zero extension selector.
    .mem_wdata_i    (mem_wdata_q),    // Store payload to DMEM write port.
    .load_valid_i   (load_valid_q),   // Load completion qualifier for WB data mux.
    .load_rd_i      (load_rd_q),      // Load destination register for WB data mux.
    // Register file interface
    .rf_we_o    (wb_rf_we),    // Final regfile write enable after WB arbitration.
    .rf_waddr_o (wb_rf_waddr), // Final regfile destination register.
    .rf_wdata_o (wb_rf_wdata), // Final regfile write data (ALU path or load path).
    // Pipeline stall while the D-cache controller services a multi-cycle access.
    .mem_stall_o (mem_stall),
    // D-side AHB-Lite master port, passed straight through to top.
    .ahb_haddr_o  (dahb_haddr_o),
    .ahb_htrans_o (dahb_htrans_o),
    .ahb_hwrite_o (dahb_hwrite_o),
    .ahb_hsize_o  (dahb_hsize_o),
    .ahb_hwdata_o (dahb_hwdata_o),
    .ahb_hrdata_i (dahb_hrdata_i),
    .ahb_hready_i (dahb_hready_i),
    .ahb_hresp_i  (dahb_hresp_i)
  );

endmodule
