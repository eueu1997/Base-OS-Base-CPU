# OOO ID/EX Waveform Model

`riscv_ooo_id_ex_stage_tb` drives 50 distinct instructions, one per cycle,
then allows 100 observation cycles. It generates a hierarchical VCD and has
no scoreboard, assertions, output collection, or result analysis.
The instruction order is fixed: branch/jump targets do not alter stimulus.

## FU Models

- BRANCH: evaluates all six RV32I conditions, computes the PC-relative target,
  and completes with a 0/1 taken result. This result is completion metadata,
  not an architectural register write.
- JUMP: implements JAL/JALR target calculation, including clearing JALR bit 0,
  and returns PC+4 to the ROB.
- MEMORY: every aligned word reads the parameter `MOCK_READ_DATA`, default
  `32'h80ff7f01`. Loads select little-endian byte/halfword lanes and apply
  sign/zero extension. Stores return zero with completion valid, but do not
  change memory. Misalignment, access faults, and cross-word reads are not modeled.
- All models are combinational, retain the dispatched ROB tag, and complete
  only when enabled with a supported encoding. Their enables are reset-gated
  in ID/EX. Their completion interfaces assume single-cycle FU consumption.

Inspect `u_dut.fu_*`, `u_dut.branch_taken`, `u_dut.branch_target`,
`u_dut.jump_target`, `u_dut.mem_*`, and `u_dut.u_tomasulo` in the waveform.
Redirect outputs remain inactive because the OOO implementation has no flush
or speculative recovery. Memory outputs are transaction observations; model
load data returns through the FU result bus, not the external WB inputs.

## Existing Integration Limitations

This test is an observation stimulus, not evidence that all 50 instructions
are accepted or committed. The multi-entry RS is implemented, but the
surrounding issue and retirement path still has limitations:

- The ROB allocates without issue-valid and stops accepting FU results when
  full; the full flag is not released through a working retirement path.
- The RS rejects allocation while full. `tomasulo_top.rs_accept_o` exposes
  per-FU capacity, but ROB/RF allocation and the upstream sender do not yet
  stall/retry together. An unaccepted instruction must be retried upstream.
- The top still decodes rd/rs1/rs2 unconditionally. Branch/store must not
  rename an architectural destination; immediate-only operands must not
  introduce register dependencies. These issues remain in the existing core.
- ID/EX valid/hold do not gate Tomasulo allocation. After the 50 instructions,
  the test drives valid=0 and instruction=0, but the core can still allocate
  and report illegal instructions during the observation interval.

## Reservation Station

`RS_SIZE` sets the number of entries per FU (default 4) and is forwarded by
`tomasulo_top`. Positive sizes including 1 and non-powers-of-two are supported.

- Allocation occurs on a rising edge when `instr_load_i && issue_ready_o`.
  The lowest-index free entry is used. A full station with no dispatch does
  not overwrite an existing entry.
- Every occupied entry checks every valid FU lane for both missing tags on
  each edge. The values are captured independently; one broadcast can wake
  multiple entries and both operands. Already-ready operands are not changed.
  If duplicate valid tags appear, the lowest-index FU lane wins.
- Newly allocated entries also capture matching broadcasts on the allocation
  edge, avoiding a missed result during insertion.
- `slot_ready_o` marks occupied entries with both operands present. Arbitration
  selects the lowest-index ready entry from registered state. A result captured
  on edge N can therefore cause dispatch on edge N+1, not edge N.
- `rs_ready_o` is registered dispatch-valid, with aligned operands, instruction,
  PC and ROB tag. At most one entry dispatches per cycle. Consecutive dispatches
  may keep valid high across cycles; each cycle is a distinct instruction.
- Dispatch frees its entry on the same edge and that entry is eligible for
  simultaneous replacement. `issue_ready_o` includes this capacity lookahead.
- FU acceptance is assumed whenever dispatch-valid is high; there is no FU
  ready/stall handshake. Lowest-index priority is not an age-based policy.
- Reset clears all occupied/ready flags and output registers.

The independent self-checking `tomasulo_rs_tb` covers depths 1, 3 and 4,
parallel wakeup, invalid lanes, arbitration, overflow rejection, same-edge
replacement, allocation-time forwarding, metadata alignment and reset.
The existing waveform-only testbenches are unchanged.

```sh
xrun -64bit -sv -top tomasulo_rs_tb \
  source/sv/rtl/OOOExecution/tomasulo_RS.sv \
  source/sv/tb/tomasulo_rs_tb.sv
```

## Xcelium

From the repository root, in an environment with Xcelium configured:

```sh
xrun -64bit -sv -access +rwc -top riscv_ooo_id_ex_stage_tb \
  source/sv/rtl/OOOExecution/tomasulo_RF.sv \
  source/sv/rtl/OOOExecution/tomasulo_ROB.sv \
  source/sv/rtl/OOOExecution/tomasulo_RS.sv \
  source/sv/rtl/OOOExecution/tomasulo_top.sv \
  source/sv/rtl/InOrderExecution/riscv_alu_*.sv \
  source/sv/rtl/OOOExecution/riscv_fu_*.sv \
  source/sv/rtl/OOOExecution/riscv_id_ex_stage.sv \
  source/sv/tb/riscv_ooo_id_ex_stage_tb.sv
```

Compile only the OOO ID/EX definition, not the same-named in-order module.
The VCD is written to the simulator working directory as
`riscv_ooo_id_ex_stage_tb.vcd`.