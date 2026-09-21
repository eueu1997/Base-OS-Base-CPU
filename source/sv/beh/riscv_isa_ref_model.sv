// -----------------------------------------------------------------------------
// Module      : riscv_isa_ref_model
// File        : riscv_isa_ref_model.sv
// Author      : spt9pad
// Date        : 2026-09-21
// Version     : v1.0
//
// Functionality
// - Purely architectural (ISA-level) golden reference model of the RV32I
//   subset implemented by the riscv core, for use as a scoreboard/checker
//   in verification environments (e.g. compared against riscv_wb_stage
//   retirement and the D-side memory bus).
// - Given one instruction word per cycle (instr_i, qualified by
//   instr_valid_i) the model decodes and executes it functionally: it reads
//   its own register file copy, computes the architectural result, and
//   updates its own register file and PC accordingly.
// - Deliberately independent from the DUT's execution units (no reuse of
//   riscv_alu_* / riscv_id_ex_stage logic) so it does not share common-mode
//   bugs with the design under test.
// - This is a functional model only: it does not model pipelining,
//   instruction fetch, or caching. Memory is not owned by the model; loads
//   and stores are exposed on a simple, single-cycle, combinational
//   request/response port that the testbench backs with its own memory
//   array (see riscv_uvm_tb.sv `memory`).
//
// Memory port contract (mirrors riscv_id_ex_stage's mem_* bundle so it can
// be diffed directly against the DUT's ID/EX outputs)
// - mem_req_o/mem_we_o/mem_addr_o/mem_width_o/mem_sign_ext_o/mem_wdata_o are
//   combinational, valid while instr_valid_i is asserted for a load/store.
// - mem_rdata_i must return, combinationally, the full 32-bit word
//   containing the addressed byte/half at that same cycle (word-aligned,
//   like the shared RAM model in riscv_uvm_tb.sv). Sub-word selection for
//   loads is done inside this model using mem_addr_o[1:0].
//
// Program counter
// - pc_o is the registered address of the instruction currently presented
//   on instr_i (the address the testbench should have used to fetch it).
// - pc_next_o is the combinational, architecturally-correct address of the
//   next instruction (pc+4, or the jump/branch target when taken).
// -----------------------------------------------------------------------------
module riscv_isa_ref_model (
  input  logic        clk_i,
  input  logic        rst_ni,

  input  logic         instr_valid_i,
  input  logic [31:0]  instr_i,

  output logic [31:0] pc_o,
  output logic [31:0] pc_next_o,
  output logic        illegal_instr_o,

  // Register file writeback (retire) interface for this cycle's instruction.
  output logic        rf_we_o,
  output logic [4:0]  rf_waddr_o,
  output logic [31:0] rf_wdata_o,

  // Functional memory access port (no cache/pipeline timing modeled).
  output logic        mem_req_o,
  output logic        mem_we_o,
  output logic [31:0] mem_addr_o,
  output logic [1:0]  mem_width_o,     // 00=byte, 01=halfword, 10=word
  output logic        mem_sign_ext_o,
  output logic [31:0] mem_wdata_o,
  input  logic [31:0] mem_rdata_i
);

  // Architectural state owned by the model.
  logic [31:0] rf_q [32];
  logic [31:0] pc_q;

  // Decoded instruction fields.
  logic [6:0] opcode;
  logic [2:0] funct3;
  logic [6:0] funct7;
  logic [4:0] rs1_addr;
  logic [4:0] rs2_addr;
  logic [4:0] rd_addr;
  logic [31:0] rs1_data;
  logic [31:0] rs2_data;
  logic [31:0] imm_i;
  logic [31:0] imm_s;
  logic [31:0] imm_b;
  logic [31:0] imm_u;
  logic [31:0] imm_j;

  // Combinational decode/execute results (this cycle's instruction).
  logic        illegal_d;
  logic        rf_we_d;
  logic [4:0]  rf_waddr_d;
  logic [31:0] rf_wdata_d;
  logic [31:0] pc_next_d;
  logic        mem_req_d;
  logic        mem_we_d;
  logic [31:0] mem_addr_d;
  logic [1:0]  mem_width_d;
  logic        mem_sign_ext_d;
  logic [31:0] mem_wdata_d;

  logic [31:0] load_byte;
  logic [31:0] load_half;
  logic        branch_taken;

  always_comb begin
    opcode   = instr_i[6:0];
    funct3   = instr_i[14:12];
    funct7   = instr_i[31:25];
    rs1_addr = instr_i[19:15];
    rs2_addr = instr_i[24:20];
    rd_addr  = instr_i[11:7];

    rs1_data = (rs1_addr == 5'd0) ? 32'h0000_0000 : rf_q[rs1_addr];
    rs2_data = (rs2_addr == 5'd0) ? 32'h0000_0000 : rf_q[rs2_addr];

    imm_i = {{20{instr_i[31]}}, instr_i[31:20]};
    imm_s = {{20{instr_i[31]}}, instr_i[31:25], instr_i[11:7]};
    imm_b = {{20{instr_i[31]}}, instr_i[7], instr_i[30:25], instr_i[11:8], 1'b0};
    imm_u = {instr_i[31:12], 12'h000};
    imm_j = {{11{instr_i[31]}}, instr_i[31], instr_i[19:12], instr_i[20], instr_i[30:21], 1'b0};

    // Safe defaults: no writeback, no memory access, sequential PC, legal.
    illegal_d      = 1'b0;
    rf_we_d        = 1'b0;
    rf_waddr_d     = rd_addr;
    rf_wdata_d     = 32'h0000_0000;
    pc_next_d      = pc_q + 32'd4;
    mem_req_d      = 1'b0;
    mem_we_d       = 1'b0;
    mem_addr_d     = 32'h0000_0000;
    mem_width_d    = 2'b00;
    mem_sign_ext_d = 1'b0;
    mem_wdata_d    = 32'h0000_0000;
    branch_taken   = 1'b0;
    load_byte      = 32'h0000_0000;
    load_half      = 32'h0000_0000;

    unique case (opcode)
      7'b0110011: begin // OP (R-type ALU)
        rf_we_d = 1'b1;
        unique case ({funct7, funct3})
          10'b0000000_000: rf_wdata_d = rs1_data + rs2_data;                          // ADD
          10'b0100000_000: rf_wdata_d = rs1_data - rs2_data;                          // SUB
          10'b0000000_001: rf_wdata_d = rs1_data << rs2_data[4:0];                    // SLL
          10'b0000000_010: rf_wdata_d = {31'h0, $signed(rs1_data) < $signed(rs2_data)}; // SLT
          10'b0000000_011: rf_wdata_d = {31'h0, rs1_data < rs2_data};                  // SLTU
          10'b0000000_100: rf_wdata_d = rs1_data ^ rs2_data;                           // XOR
          10'b0000000_101: rf_wdata_d = rs1_data >> rs2_data[4:0];                     // SRL
          10'b0100000_101: rf_wdata_d = $signed(rs1_data) >>> rs2_data[4:0];           // SRA
          10'b0000000_110: rf_wdata_d = rs1_data | rs2_data;                          // OR
          10'b0000000_111: rf_wdata_d = rs1_data & rs2_data;                          // AND
          default: begin
            rf_we_d   = 1'b0;
            illegal_d = 1'b1;
          end
        endcase
      end

      7'b0010011: begin // OP-IMM (I-type ALU)
        rf_we_d = 1'b1;
        unique case (funct3)
          3'b000: rf_wdata_d = rs1_data + imm_i;                                      // ADDI
          3'b010: rf_wdata_d = {31'h0, $signed(rs1_data) < $signed(imm_i)};           // SLTI
          3'b011: rf_wdata_d = {31'h0, rs1_data < imm_i};                             // SLTIU
          3'b100: rf_wdata_d = rs1_data ^ imm_i;                                      // XORI
          3'b110: rf_wdata_d = rs1_data | imm_i;                                      // ORI
          3'b111: rf_wdata_d = rs1_data & imm_i;                                      // ANDI
          3'b001: begin
            if (funct7 == 7'b0000000) rf_wdata_d = rs1_data << instr_i[24:20];        // SLLI
            else begin rf_we_d = 1'b0; illegal_d = 1'b1; end
          end
          3'b101: begin
            if (funct7 == 7'b0000000) rf_wdata_d = rs1_data >> instr_i[24:20];        // SRLI
            else if (funct7 == 7'b0100000) rf_wdata_d = $signed(rs1_data) >>> instr_i[24:20]; // SRAI
            else begin rf_we_d = 1'b0; illegal_d = 1'b1; end
          end
          default: begin
            rf_we_d   = 1'b0;
            illegal_d = 1'b1;
          end
        endcase
      end

      7'b0110111: begin // LUI
        rf_we_d    = 1'b1;
        rf_wdata_d = imm_u;
      end

      7'b0010111: begin // AUIPC
        rf_we_d    = 1'b1;
        rf_wdata_d = pc_q + imm_u;
      end

      7'b1101111: begin // JAL
        rf_we_d    = 1'b1;
        rf_wdata_d = pc_q + 32'd4;
        pc_next_d  = pc_q + imm_j;
      end

      7'b1100111: begin // JALR
        if (funct3 == 3'b000) begin
          rf_we_d    = 1'b1;
          rf_wdata_d = pc_q + 32'd4;
          pc_next_d  = (rs1_data + imm_i) & 32'hFFFF_FFFE;
        end else begin
          illegal_d = 1'b1;
        end
      end

      7'b1100011: begin // BRANCH
        unique case (funct3)
          3'b000: branch_taken = (rs1_data == rs2_data);                             // BEQ
          3'b001: branch_taken = (rs1_data != rs2_data);                              // BNE
          3'b100: branch_taken = ($signed(rs1_data) < $signed(rs2_data));             // BLT
          3'b101: branch_taken = ($signed(rs1_data) >= $signed(rs2_data));            // BGE
          3'b110: branch_taken = (rs1_data < rs2_data);                               // BLTU
          3'b111: branch_taken = (rs1_data >= rs2_data);                              // BGEU
          default: illegal_d = 1'b1;
        endcase
        if (!illegal_d)
          pc_next_d = branch_taken ? (pc_q + imm_b) : (pc_q + 32'd4);
      end

      7'b0000011: begin // LOAD
        mem_req_d   = 1'b1;
        mem_we_d    = 1'b0;
        mem_addr_d  = rs1_data + imm_i;
        rf_we_d     = 1'b1;
        unique case (funct3)
          3'b000: begin // LB
            mem_width_d    = 2'b00;
            mem_sign_ext_d = 1'b1;
            load_byte      = mem_rdata_i[8*mem_addr_d[1:0] +: 8];
            rf_wdata_d     = {{24{load_byte[7]}}, load_byte[7:0]};
          end
          3'b001: begin // LH
            mem_width_d    = 2'b01;
            mem_sign_ext_d = 1'b1;
            load_half      = mem_rdata_i[16*mem_addr_d[1] +: 16];
            rf_wdata_d     = {{16{load_half[15]}}, load_half[15:0]};
          end
          3'b010: begin // LW
            mem_width_d = 2'b10;
            rf_wdata_d  = mem_rdata_i;
          end
          3'b100: begin // LBU
            mem_width_d = 2'b00;
            load_byte   = mem_rdata_i[8*mem_addr_d[1:0] +: 8];
            rf_wdata_d  = {24'h0, load_byte[7:0]};
          end
          3'b101: begin // LHU
            mem_width_d = 2'b01;
            load_half   = mem_rdata_i[16*mem_addr_d[1] +: 16];
            rf_wdata_d  = {16'h0, load_half[15:0]};
          end
          default: begin
            mem_req_d = 1'b0;
            rf_we_d   = 1'b0;
            illegal_d = 1'b1;
          end
        endcase
      end

      7'b0100011: begin // STORE
        mem_req_d  = 1'b1;
        mem_we_d   = 1'b1;
        mem_addr_d = rs1_data + imm_s;
        mem_wdata_d = rs2_data;
        unique case (funct3)
          3'b000: mem_width_d = 2'b00; // SB
          3'b001: mem_width_d = 2'b01; // SH
          3'b010: mem_width_d = 2'b10; // SW
          default: begin
            mem_req_d = 1'b0;
            illegal_d = 1'b1;
          end
        endcase
      end

      default: illegal_d = 1'b1; // FENCE/SYSTEM/CSR: not modeled, flagged illegal.
    endcase

    // x0 is never written, even if an instruction targets it.
    if (rd_addr == 5'd0)
      rf_we_d = 1'b0;
  end

  // Combinational, same-cycle view of this instruction's effects.
  assign illegal_instr_o = instr_valid_i & illegal_d;
  assign rf_we_o         = instr_valid_i & rf_we_d;
  assign rf_waddr_o      = rf_waddr_d;
  assign rf_wdata_o      = rf_wdata_d;
  assign mem_req_o       = instr_valid_i & mem_req_d;
  assign mem_we_o        = mem_we_d;
  assign mem_addr_o      = mem_addr_d;
  assign mem_width_o     = mem_width_d;
  assign mem_sign_ext_o  = mem_sign_ext_d;
  assign mem_wdata_o     = mem_wdata_d;
  assign pc_next_o       = pc_next_d;
  assign pc_o            = pc_q;

  // Architectural state update: PC and register file advance together only
  // when an instruction is actually presented, keeping the model stalled
  // otherwise (e.g. while the testbench is still assembling the next fetch).
  always_ff @(posedge clk_i or negedge rst_ni) begin
    if (!rst_ni) begin
      pc_q <= 32'h0000_0000;
      for (int i = 0; i < 32; i++)
        rf_q[i] <= 32'h0000_0000;
    end else if (instr_valid_i) begin
      pc_q <= pc_next_d;
      if (rf_we_d)
        rf_q[rf_waddr_d] <= rf_wdata_d;
      rf_q[0] <= 32'h0000_0000;
    end
  end

endmodule
