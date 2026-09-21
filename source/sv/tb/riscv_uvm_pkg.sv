package riscv_uvm_pkg;
  import uvm_pkg::*;
  `include "uvm_macros.svh"

  typedef enum bit {RISCV_IMEM, RISCV_DMEM} riscv_bus_e;

  // RV32I instruction encoders used by tests to build the program loaded
  // into riscv_mem_if (see riscv_uvm_if.sv). Kept independent from the DUT
  // decode logic and from riscv_isa_ref_model, which only consumes the
  // resulting instruction words.
  class riscv_asm;
    static function automatic bit [31:0] i_type(input int imm, input int rs1, input int funct3, input int rd, input int opcode);
      i_type = {imm[11:0], rs1[4:0], funct3[2:0], rd[4:0], opcode[6:0]};
    endfunction
    static function automatic bit [31:0] r_type(input int funct7, input int rs2, input int rs1, input int funct3, input int rd, input int opcode);
      r_type = {funct7[6:0], rs2[4:0], rs1[4:0], funct3[2:0], rd[4:0], opcode[6:0]};
    endfunction
    static function automatic bit [31:0] s_type(input int imm, input int rs2, input int rs1, input int funct3, input int opcode);
      s_type = {imm[11:5], rs2[4:0], rs1[4:0], funct3[2:0], imm[4:0], opcode[6:0]};
    endfunction
    static function automatic bit [31:0] b_type(input int imm, input int rs2, input int rs1, input int funct3, input int opcode);
      b_type = {imm[12], imm[10:5], rs2[4:0], rs1[4:0], funct3[2:0], imm[4:1], imm[11], opcode[6:0]};
    endfunction
    static function automatic bit [31:0] u_type(input int imm20, input int rd, input int opcode);
      u_type = {imm20[19:0], rd[4:0], opcode[6:0]};
    endfunction
    static function automatic bit [31:0] j_type(input int imm, input int rd, input int opcode);
      j_type = {imm[20], imm[10:1], imm[11], imm[19:12], rd[4:0], opcode[6:0]};
    endfunction
  endclass

  class riscv_bus_item extends uvm_sequence_item;
    rand bit [31:0] address;
    rand bit [1:0]  trans;
    rand bit        write;
    rand bit [2:0]  size;
    rand bit [255:0] write_data;
    bit [255:0] read_data;
    bit response_error;
    riscv_bus_e bus;

    `uvm_object_utils_begin(riscv_bus_item)
      `uvm_field_int(address, UVM_ALL_ON)
      `uvm_field_int(trans, UVM_ALL_ON)
      `uvm_field_int(write, UVM_ALL_ON)
      `uvm_field_int(size, UVM_ALL_ON)
      `uvm_field_int(write_data, UVM_ALL_ON)
      `uvm_field_int(read_data, UVM_ALL_ON)
      `uvm_field_int(response_error, UVM_ALL_ON)
      `uvm_field_enum(riscv_bus_e, bus, UVM_ALL_ON)
    `uvm_object_utils_end

    function new(string name = "riscv_bus_item");
      super.new(name);
    endfunction
  endclass

  class riscv_bus_monitor extends uvm_monitor;
    `uvm_component_utils(riscv_bus_monitor)
    virtual riscv_uvm_if vif;
    riscv_bus_e bus;
    uvm_analysis_port #(riscv_bus_item) item_collected_port;

    function new(string name, uvm_component parent);
      super.new(name, parent);
      item_collected_port = new("item_collected_port", this);
    endfunction

    function void build_phase(uvm_phase phase);
      super.build_phase(phase);
      if (!uvm_config_db#(virtual riscv_uvm_if)::get(this, "", "vif", vif))
        `uvm_fatal("NOVIF", "RISC-V bus monitor virtual interface is missing")
      if (!uvm_config_db#(riscv_bus_e)::get(this, "", "bus", bus))
        `uvm_fatal("NOBUS", "RISC-V bus monitor kind is missing")
    endfunction

    task run_phase(uvm_phase phase);
      riscv_bus_item item;
      forever begin
        @(vif.monitor_cb);
        if (vif.monitor_cb.hready && vif.monitor_cb.htrans[1]) begin
          item = riscv_bus_item::type_id::create("item");
          item.bus            = bus;
          item.address       = vif.monitor_cb.haddr;
          item.trans         = vif.monitor_cb.htrans;
          item.write         = vif.monitor_cb.hwrite;
          item.size          = vif.monitor_cb.hsize;
          item.write_data    = vif.monitor_cb.hwdata;
          item.read_data     = vif.monitor_cb.hrdata;
          item.response_error = vif.monitor_cb.hresp;
          item_collected_port.write(item);
        end
      end
    endtask
  endclass

  class riscv_scoreboard extends uvm_subscriber #(riscv_bus_item);
    `uvm_component_utils(riscv_scoreboard)
    int instruction_transfers;
    int data_reads;
    int data_writes;
    int errors;

    function new(string name, uvm_component parent);
      super.new(name, parent);
    endfunction

    function void write(riscv_bus_item t);
      if (t.response_error) begin
        errors++;
        `uvm_error("AHB_RESP", $sformatf("AHB error at 0x%08h", t.address))
      end
      if (t.bus == RISCV_IMEM)
        instruction_transfers++;
      else if (t.write)
        data_writes++;
      else
        data_reads++;
    endfunction

    function void report_phase(uvm_phase phase);
      `uvm_info("BUS_STATS", $sformatf("instruction=%0d data_reads=%0d data_writes=%0d errors=%0d",
                instruction_transfers, data_reads, data_writes, errors), UVM_LOW)
      if (errors != 0)
        `uvm_error("BUS_STATS", "Observed an AHB response error")
    endfunction
  endclass

  // Prediction produced by riscv_isa_ref_model for one fetched instruction.
  class riscv_ref_predict_item extends uvm_sequence_item;
    bit [31:0] pc;
    bit [31:0] instr;
    bit        illegal;
    bit        rf_we;
    bit [4:0]  rf_waddr;
    bit [31:0] rf_wdata;
    bit        mem_req;
    bit        mem_we;
    bit [31:0] mem_addr;
    bit [1:0]  mem_width;
    bit [31:0] mem_wdata;

    `uvm_object_utils_begin(riscv_ref_predict_item)
      `uvm_field_int(pc, UVM_ALL_ON)
      `uvm_field_int(instr, UVM_ALL_ON)
      `uvm_field_int(illegal, UVM_ALL_ON)
      `uvm_field_int(rf_we, UVM_ALL_ON)
      `uvm_field_int(rf_waddr, UVM_ALL_ON)
      `uvm_field_int(rf_wdata, UVM_ALL_ON)
      `uvm_field_int(mem_req, UVM_ALL_ON)
      `uvm_field_int(mem_we, UVM_ALL_ON)
      `uvm_field_int(mem_addr, UVM_ALL_ON)
      `uvm_field_int(mem_width, UVM_ALL_ON)
      `uvm_field_int(mem_wdata, UVM_ALL_ON)
    `uvm_object_utils_end

    function new(string name = "riscv_ref_predict_item");
      super.new(name);
    endfunction
  endclass

  // Feeds instructions fetched on the imem bus into riscv_isa_ref_model and
  // publishes the model's predicted architectural effect for each one, one
  // cycle later, once its combinational outputs have settled.
  //
  // NOTE: riscv_icache only drives an AHB transaction on imem_vif for a
  // line-refill *miss*; hits are served internally and never touch this
  // bus. So each observed transaction here yields a whole 8-word line,
  // which is queued and drained one instruction per cycle (in fetch
  // order), reconstructing the sequential fetch stream. This is only
  // correct for straight-line code that stays within already-queued
  // lines; a branch/jump that hits in the icache (no new refill) cannot be
  // observed on imem_vif and will desync the model from the DUT.
  class riscv_ref_model_monitor extends uvm_component;
    `uvm_component_utils(riscv_ref_model_monitor)
    virtual riscv_uvm_if imem_vif;
    virtual riscv_ref_model_if ref_vif;
    uvm_analysis_port #(riscv_ref_predict_item) predict_port;

    function new(string name, uvm_component parent);
      super.new(name, parent);
      predict_port = new("predict_port", this);
    endfunction

    function void build_phase(uvm_phase phase);
      super.build_phase(phase);
      if (!uvm_config_db#(virtual riscv_uvm_if)::get(this, "", "imem_vif", imem_vif))
        `uvm_fatal("NOVIF", "Ref-model monitor is missing the imem virtual interface")
      if (!uvm_config_db#(virtual riscv_ref_model_if)::get(this, "", "ref_vif", ref_vif))
        `uvm_fatal("NOVIF", "Ref-model monitor is missing the ref-model virtual interface")
    endfunction

    task run_phase(uvm_phase phase);
      bit [31:0] fetch_pc_q[$];
      bit [31:0] fetch_word_q[$];
      bit        pending_valid = 1'b0;
      bit [31:0] pending_pc;
      bit [31:0] pending_instr;
      bit [31:0] line_base;
      riscv_ref_predict_item item;

      forever begin
        @(imem_vif.monitor_cb);

        // The instruction fed last cycle has now propagated through the
        // model's combinational decode/execute logic: publish it.
        if (pending_valid) begin
          item           = riscv_ref_predict_item::type_id::create("item");
          item.pc        = pending_pc;
          item.instr     = pending_instr;
          item.illegal   = ref_vif.mon_cb.illegal_instr;
          item.rf_we     = ref_vif.mon_cb.rf_we;
          item.rf_waddr  = ref_vif.mon_cb.rf_waddr;
          item.rf_wdata  = ref_vif.mon_cb.rf_wdata;
          item.mem_req   = ref_vif.mon_cb.mem_req;
          item.mem_we    = ref_vif.mon_cb.mem_we;
          item.mem_addr  = ref_vif.mon_cb.mem_addr;
          item.mem_width = ref_vif.mon_cb.mem_width;
          item.mem_wdata = ref_vif.mon_cb.mem_wdata;
          predict_port.write(item);
        end

        // A line refill completed this cycle: queue its 8 instructions.
        if (imem_vif.monitor_cb.hready && imem_vif.monitor_cb.htrans[1]) begin
          line_base = {imem_vif.monitor_cb.haddr[31:5], 5'b00000};
          for (int w = 0; w < 8; w++) begin
            fetch_pc_q.push_back(line_base + w * 4);
            fetch_word_q.push_back(imem_vif.monitor_cb.hrdata[w*32 +: 32]);
          end
        end

        // Drain one queued instruction per cycle into the model, in order.
        if (fetch_pc_q.size() > 0) begin
          pending_valid = 1'b1;
          pending_pc    = fetch_pc_q.pop_front();
          pending_instr = fetch_word_q.pop_front();
          ref_vif.mon_cb.instr       <= pending_instr;
          ref_vif.mon_cb.instr_valid <= 1'b1;
        end else begin
          pending_valid              = 1'b0;
          ref_vif.mon_cb.instr_valid <= 1'b0;
        end
      end
    endtask
  endclass

  // Lightweight visibility/checker for the reference model's predictions.
  class riscv_ref_predict_logger extends uvm_subscriber #(riscv_ref_predict_item);
    `uvm_component_utils(riscv_ref_predict_logger)

    function new(string name, uvm_component parent);
      super.new(name, parent);
    endfunction

    function void write(riscv_ref_predict_item t);
      if (t.illegal)
        `uvm_error("REF_ILLEGAL", $sformatf("Ref model flagged illegal instruction 0x%08h at pc=0x%08h", t.instr, t.pc))
      else
        `uvm_info("REF_PREDICT", $sformatf("pc=0x%08h instr=0x%08h rf_we=%0b rd=%0d wdata=0x%08h mem_req=%0b",
                  t.pc, t.instr, t.rf_we, t.rf_waddr, t.rf_wdata, t.mem_req), UVM_HIGH)
    endfunction
  endclass

  class riscv_env extends uvm_env;
    `uvm_component_utils(riscv_env)
    riscv_bus_monitor imem_monitor;
    riscv_bus_monitor dmem_monitor;
    riscv_scoreboard scoreboard;
    riscv_ref_model_monitor ref_monitor;
    riscv_ref_predict_logger ref_logger;

    function new(string name, uvm_component parent);
      super.new(name, parent);
    endfunction

    function void build_phase(uvm_phase phase);
      super.build_phase(phase);
      imem_monitor = riscv_bus_monitor::type_id::create("imem_monitor", this);
      dmem_monitor = riscv_bus_monitor::type_id::create("dmem_monitor", this);
      scoreboard   = riscv_scoreboard::type_id::create("scoreboard", this);
      ref_monitor  = riscv_ref_model_monitor::type_id::create("ref_monitor", this);
      ref_logger   = riscv_ref_predict_logger::type_id::create("ref_logger", this);
      uvm_config_db#(riscv_bus_e)::set(this, "imem_monitor", "bus", RISCV_IMEM);
      uvm_config_db#(riscv_bus_e)::set(this, "dmem_monitor", "bus", RISCV_DMEM);
    endfunction

    function void connect_phase(uvm_phase phase);
      imem_monitor.item_collected_port.connect(scoreboard.analysis_export);
      dmem_monitor.item_collected_port.connect(scoreboard.analysis_export);
      ref_monitor.predict_port.connect(ref_logger.analysis_export);
    endfunction
  endclass

  class riscv_smoke_test extends uvm_test;
    `uvm_component_utils(riscv_smoke_test)
    riscv_env env;
    virtual riscv_status_if status_vif;
    virtual riscv_mem_if mem_vif;
    virtual riscv_mem_if model_mem_vif;

    function new(string name, uvm_component parent);
      super.new(name, parent);
    endfunction

    function void build_phase(uvm_phase phase);
      super.build_phase(phase);
      env = riscv_env::type_id::create("env", this);
      if (!uvm_config_db#(virtual riscv_status_if)::get(this, "", "status_vif", status_vif))
        `uvm_fatal("NOSTATUS", "RISC-V status virtual interface is missing")
      if (!uvm_config_db#(virtual riscv_mem_if)::get(this, "", "mem_vif", mem_vif))
        `uvm_fatal("NOMEM", "RISC-V shared memory virtual interface is missing")
      if (!uvm_config_db#(virtual riscv_mem_if)::get(this, "", "model_mem_vif", model_mem_vif))
        `uvm_fatal("NOMEM", "RISC-V reference-model memory virtual interface is missing")
    endfunction

    // This test case's chosen program: addi x1,x0,80 / addi x2,x0,4 /
    // addi x3,x0,12 / add x4,x1,x3 / sw x4,0(x0) / lw x5,0(x0).
    task load_program();
      bit [31:0] prog[] = '{
        riscv_asm::i_type(80, 0, 0, 1, 7'b0010011),
        riscv_asm::i_type(4,  0, 0, 2, 7'b0010011),
        riscv_asm::i_type(12, 0, 0, 3, 7'b0010011),
        riscv_asm::r_type(0,  3, 1, 0, 4, 7'b0110011),
        riscv_asm::s_type(0,  4, 0, 2, 7'b0100011),
        riscv_asm::i_type(0,  0, 2, 5, 7'b0000011)
      };
      mem_vif.preload(prog);
      model_mem_vif.preload(prog);
    endtask

    // Compares the full architectural state (register file + data memory)
    // between the DUT and riscv_isa_ref_model and reports any divergence.
    task check_model_match();
      int rf_mismatches;
      int mem_mismatches;

      rf_mismatches = 0;
      for (int i = 1; i < 32; i++) begin // x0 is hardwired to zero on both sides
        if (status_vif.dut_rf[i] !== status_vif.model_rf[i]) begin
          rf_mismatches++;
          `uvm_error("RF_MISMATCH", $sformatf("x%0d: dut=0x%08h model=0x%08h", i, status_vif.dut_rf[i], status_vif.model_rf[i]))
        end
      end

      mem_mismatches = 0;
      for (int i = 0; i < 1024; i++) begin
        if (mem_vif.mem[i] !== model_mem_vif.mem[i]) begin
          mem_mismatches++;
          if (mem_mismatches <= 10)
            `uvm_error("MEM_MISMATCH", $sformatf("mem[%0d]: dut=0x%08h model=0x%08h", i, mem_vif.mem[i], model_mem_vif.mem[i]))
        end
      end
      if (mem_mismatches > 10)
        `uvm_error("MEM_MISMATCH", $sformatf("%0d additional data memory mismatches not printed", mem_mismatches - 10))

      if (rf_mismatches == 0 && mem_mismatches == 0)
        `uvm_info("REF_MODEL_CHECK", "DUT and reference model register file and data memory match", UVM_LOW)
    endtask

    task run_phase(uvm_phase phase);
      phase.raise_objection(this);
      load_program();
      wait (status_vif.illegal_instr === 1'b0);
      repeat (220) @(posedge status_vif.clk_i);
      if (status_vif.illegal_instr !== 1'b0)
        `uvm_error("ILLEGAL", "The core reported an illegal instruction")
      if (status_vif.x3 !== 32'd12)
        `uvm_error("REG_CHECK", $sformatf("x3 expected 12, got 0x%08h", status_vif.x3))
      if (status_vif.x4 !== 32'd92)
        `uvm_error("REG_CHECK", $sformatf("x4 expected 92, got 0x%08h", status_vif.x4))
      if (status_vif.mem0 !== 32'd92)
        `uvm_error("MEM_CHECK", $sformatf("mem[0] expected 92, got 0x%08h", status_vif.mem0))
      check_model_match();
      phase.drop_objection(this);
    endtask
  endclass
endpackage