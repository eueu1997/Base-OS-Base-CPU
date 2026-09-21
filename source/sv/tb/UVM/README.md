# RISC-V UVM environment

This directory contains a small UVM environment for the standalone `riscv`
core. The testbench supplies instruction and data responses on the two
AHB-Lite master ports, monitors both buses, and checks a smoke program through
the register file and backing memory.

The intended top is `riscv_uvm_tb` and the default test is
`riscv_smoke_test`.

Example Cadence Xcelium invocation from the unit directory:

```text
xrun -64bit -uvm -sv -access +rwc \
  source/sv/rtl/*.sv \
  source/sv/tb/UVM/riscv_uvm_if.sv \
  source/sv/tb/UVM/riscv_uvm_pkg.sv \
  source/sv/tb/UVM/riscv_uvm_tb.sv \
  -top riscv_uvm_tb
```

The smoke program checks ALU forwarding, a store, a load, and absence of an
illegal-instruction response. Override the test with `+UVM_TESTNAME=...` when
adding further tests to the package.