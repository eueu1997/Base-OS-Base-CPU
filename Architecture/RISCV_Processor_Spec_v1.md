# Specifiche Architetturali - RISC-V Core (v1)

## 1. Scopo del documento
Definire le specifiche iniziali (semplici) per la prima versione di un processore RISC-V orientato a performance, da usare come baseline per implementazione RTL, verifica e sintesi.

## 2. Obiettivi della prima versione
- Core a 32 bit per bring-up rapido del flow ASIC.
- Focus principale: performance compatibilmente con complessita limitata.
- Design sintetizzabile e facilmente estendibile.
- Nessun supporto multicore nella v1.

## 3. Profilo ISA
- Architettura base: RV32I.
- Modalita privilegio: M-mode only.
- Estensioni nella v1:
  - M (moltiplicazione/divisione): non inclusa nella prima iterazione RTL.
  - C (compressed): non inclusa.
  - A/F/D: non incluse.
- Endianness: little-endian.
- Allineamento istruzioni: 32 bit.

## 4. Microarchitettura (v1 semplice)
- Pipeline in-order a 3 stadi:
  - IF: fetch istruzione
  - ID/EX: decode + execute
  - WB: write-back su register file
- Nessuna esecuzione out-of-order.
- Nessuna branch prediction nella v1.
- Gestione control-flow implementata nel RTL corrente:
  - branch/jump risolti in ID/EX con `pc_redirect`.
  - flush IF/ID su redirect preso per eliminare istruzione wrong-path.
- Gestione trap/exception non ancora implementata (oltre `illegal instruction`).
- Register file:
  - 32 registri x 32 bit (x0 hardwired a 0)
  - 2 porte di lettura, 1 porta di scrittura.

## 5. Unita funzionali
- ALU intera:
  - add/sub
  - operazioni logiche (and/or/xor)
  - shift (sll/srl/sra)
  - confronti signed/unsigned (slt/sltu)
- Branch/jump implementati nel RTL corrente:
  - beq, bne, blt, bge, bltu, bgeu
  - jal, jalr
  - auipc (PC-relative writeback)
- Load/store implementati nel RTL corrente:
  - lb, lh, lw, lbu, lhu
  - sb, sh, sw
- Ecalls/ebreak/CSR/trap: non implementati nel RTL corrente.

### 5.1 Istruzioni assembly e stato RTL corrente

Stato implementazione reale nel RTL attuale:
- Implementate: `add`, `sub`, `sll`, `slt`, `sltu`, `xor`, `srl`, `sra`, `or`, `and`, `addi`, `slti`, `sltiu`, `xori`, `ori`, `andi`, `slli`, `srli`, `srai`, `lui`, `auipc`, `jal`, `jalr`, `beq`, `bne`, `blt`, `bge`, `bltu`, `bgeu`, `lb`, `lh`, `lw`, `lbu`, `lhu`, `sb`, `sh`, `sw`.
- Non ancora implementate: `ecall`, `ebreak`, CSR (`csrrw/csrrs/csrrc/csrrwi/csrrsi/csrrci`), `fence`, `fence.i` e altre estensioni non-RV32I base del progetto.

#### Aritmetica e logica registro-registro (R-type)

| Istruzione | Descrizione | opcode | funct3 | funct7 | Posizioni bitfield |
| --- | --- | --- | --- | --- | --- |
| `add rd, rs1, rs2` | Somma `rs1 + rs2` e scrive il risultato in `rd`. | `0110011` | `000` | `0000000` | `funct7[31:25], rs2[24:20], rs1[19:15], funct3[14:12], rd[11:7], opcode[6:0]` |
| `sub rd, rs1, rs2` | Sottrae `rs2` da `rs1` e scrive il risultato in `rd`. | `0110011` | `000` | `0100000` | `funct7[31:25], rs2[24:20], rs1[19:15], funct3[14:12], rd[11:7], opcode[6:0]` |
| `sll rd, rs1, rs2` | Shift logico a sinistra di `rs1` di `rs2[4:0]` bit. | `0110011` | `001` | `0000000` | `funct7[31:25], rs2[24:20], rs1[19:15], funct3[14:12], rd[11:7], opcode[6:0]` |
| `slt rd, rs1, rs2` | Scrive `1` in `rd` se `rs1 < rs2` signed, altrimenti `0`. | `0110011` | `010` | `0000000` | `funct7[31:25], rs2[24:20], rs1[19:15], funct3[14:12], rd[11:7], opcode[6:0]` |
| `sltu rd, rs1, rs2` | Scrive `1` in `rd` se `rs1 < rs2` unsigned, altrimenti `0`. | `0110011` | `011` | `0000000` | `funct7[31:25], rs2[24:20], rs1[19:15], funct3[14:12], rd[11:7], opcode[6:0]` |
| `xor rd, rs1, rs2` | XOR bit-a-bit tra `rs1` e `rs2`. | `0110011` | `100` | `0000000` | `funct7[31:25], rs2[24:20], rs1[19:15], funct3[14:12], rd[11:7], opcode[6:0]` |
| `srl rd, rs1, rs2` | Shift logico a destra di `rs1` di `rs2[4:0]` bit. | `0110011` | `101` | `0000000` | `funct7[31:25], rs2[24:20], rs1[19:15], funct3[14:12], rd[11:7], opcode[6:0]` |
| `sra rd, rs1, rs2` | Shift aritmetico a destra di `rs1` di `rs2[4:0]` bit. | `0110011` | `101` | `0100000` | `funct7[31:25], rs2[24:20], rs1[19:15], funct3[14:12], rd[11:7], opcode[6:0]` |
| `or rd, rs1, rs2` | OR bit-a-bit tra `rs1` e `rs2`. | `0110011` | `110` | `0000000` | `funct7[31:25], rs2[24:20], rs1[19:15], funct3[14:12], rd[11:7], opcode[6:0]` |
| `and rd, rs1, rs2` | AND bit-a-bit tra `rs1` e `rs2`. | `0110011` | `111` | `0000000` | `funct7[31:25], rs2[24:20], rs1[19:15], funct3[14:12], rd[11:7], opcode[6:0]` |

#### Aritmetica e logica con immediato (I-type)

| Istruzione | Descrizione | opcode | funct3 | funct7 / funct12 | Posizioni bitfield |
| --- | --- | --- | --- | --- | --- |
| `addi rd, rs1, imm` | Somma `rs1 + imm` sign-extended. | `0010011` | `000` | n/a | `imm[31:20], rs1[19:15], funct3[14:12], rd[11:7], opcode[6:0]` |
| `slti rd, rs1, imm` | Scrive `1` in `rd` se `rs1 < imm` signed, altrimenti `0`. | `0010011` | `010` | n/a | `imm[31:20], rs1[19:15], funct3[14:12], rd[11:7], opcode[6:0]` |
| `sltiu rd, rs1, imm` | Scrive `1` in `rd` se `rs1 < imm` unsigned, altrimenti `0`. | `0010011` | `011` | n/a | `imm[31:20], rs1[19:15], funct3[14:12], rd[11:7], opcode[6:0]` |
| `xori rd, rs1, imm` | XOR bit-a-bit tra `rs1` e `imm`. | `0010011` | `100` | n/a | `imm[31:20], rs1[19:15], funct3[14:12], rd[11:7], opcode[6:0]` |
| `ori rd, rs1, imm` | OR bit-a-bit tra `rs1` e `imm`. | `0010011` | `110` | n/a | `imm[31:20], rs1[19:15], funct3[14:12], rd[11:7], opcode[6:0]` |
| `andi rd, rs1, imm` | AND bit-a-bit tra `rs1` e `imm`. | `0010011` | `111` | n/a | `imm[31:20], rs1[19:15], funct3[14:12], rd[11:7], opcode[6:0]` |
| `slli rd, rs1, shamt` | Shift logico a sinistra di `rs1` di `shamt` bit. | `0010011` | `001` | `funct7=0000000` | `funct7[31:25], shamt[24:20], rs1[19:15], funct3[14:12], rd[11:7], opcode[6:0]` |
| `srli rd, rs1, shamt` | Shift logico a destra di `rs1` di `shamt` bit. | `0010011` | `101` | `funct7=0000000` | `funct7[31:25], shamt[24:20], rs1[19:15], funct3[14:12], rd[11:7], opcode[6:0]` |
| `srai rd, rs1, shamt` | Shift aritmetico a destra di `rs1` di `shamt` bit. | `0010011` | `101` | `funct7=0100000` | `funct7[31:25], shamt[24:20], rs1[19:15], funct3[14:12], rd[11:7], opcode[6:0]` |

#### Upper immediate e PC-relative

| Istruzione | Descrizione | opcode | funct3 | funct7 / note | Posizioni bitfield |
| --- | --- | --- | --- | --- | --- |
| `lui rd, imm20` | Carica `imm20` nei bit alti di `rd` (bit bassi a zero). | `0110111` | n/a | U-type | `imm20[31:12], rd[11:7], opcode[6:0]` |
| `auipc rd, imm20` | Scrive in `rd` il valore `PC + (imm20 << 12)`. | `0010111` | n/a | U-type | `imm20[31:12], rd[11:7], opcode[6:0]` |

#### Salti e branch

| Istruzione | Descrizione | opcode | funct3 | funct7 / note | Posizioni bitfield |
| --- | --- | --- | --- | --- | --- |
| `jal rd, offset` | Salto PC-relative e salvataggio return address in `rd`. | `1101111` | n/a | J-type | `imm[20]=[31], imm[10:1]=[30:21], imm[11]=[20], imm[19:12]=[19:12], rd[11:7], opcode[6:0]` |
| `jalr rd, rs1, imm` | Salto indiretto a `rs1 + imm` con return address in `rd`. | `1100111` | `000` | I-type | `imm[31:20], rs1[19:15], funct3[14:12], rd[11:7], opcode[6:0]` |
| `beq rs1, rs2, offset` | Branch se `rs1 == rs2`. | `1100011` | `000` | B-type | `imm[12]=[31], imm[10:5]=[30:25], rs2[24:20], rs1[19:15], funct3[14:12], imm[4:1]=[11:8], imm[11]=[7], opcode[6:0]` |
| `bne rs1, rs2, offset` | Branch se `rs1 != rs2`. | `1100011` | `001` | B-type | `imm[12]=[31], imm[10:5]=[30:25], rs2[24:20], rs1[19:15], funct3[14:12], imm[4:1]=[11:8], imm[11]=[7], opcode[6:0]` |
| `blt rs1, rs2, offset` | Branch se `rs1 < rs2` signed. | `1100011` | `100` | B-type | `imm[12]=[31], imm[10:5]=[30:25], rs2[24:20], rs1[19:15], funct3[14:12], imm[4:1]=[11:8], imm[11]=[7], opcode[6:0]` |
| `bge rs1, rs2, offset` | Branch se `rs1 >= rs2` signed. | `1100011` | `101` | B-type | `imm[12]=[31], imm[10:5]=[30:25], rs2[24:20], rs1[19:15], funct3[14:12], imm[4:1]=[11:8], imm[11]=[7], opcode[6:0]` |
| `bltu rs1, rs2, offset` | Branch se `rs1 < rs2` unsigned. | `1100011` | `110` | B-type | `imm[12]=[31], imm[10:5]=[30:25], rs2[24:20], rs1[19:15], funct3[14:12], imm[4:1]=[11:8], imm[11]=[7], opcode[6:0]` |
| `bgeu rs1, rs2, offset` | Branch se `rs1 >= rs2` unsigned. | `1100011` | `111` | B-type | `imm[12]=[31], imm[10:5]=[30:25], rs2[24:20], rs1[19:15], funct3[14:12], imm[4:1]=[11:8], imm[11]=[7], opcode[6:0]` |

#### Accessi memoria

| Istruzione | Descrizione | opcode | funct3 | funct7 / note | Posizioni bitfield |
| --- | --- | --- | --- | --- | --- |
| `lb rd, imm(rs1)` | Carica 8 bit da memoria con sign-extension. | `0000011` | `000` | I-type | `imm[31:20], rs1[19:15], funct3[14:12], rd[11:7], opcode[6:0]` |
| `lh rd, imm(rs1)` | Carica 16 bit da memoria con sign-extension. | `0000011` | `001` | I-type | `imm[31:20], rs1[19:15], funct3[14:12], rd[11:7], opcode[6:0]` |
| `lw rd, imm(rs1)` | Carica 32 bit da memoria. | `0000011` | `010` | I-type | `imm[31:20], rs1[19:15], funct3[14:12], rd[11:7], opcode[6:0]` |
| `lbu rd, imm(rs1)` | Carica 8 bit da memoria con zero-extension. | `0000011` | `100` | I-type | `imm[31:20], rs1[19:15], funct3[14:12], rd[11:7], opcode[6:0]` |
| `lhu rd, imm(rs1)` | Carica 16 bit da memoria con zero-extension. | `0000011` | `101` | I-type | `imm[31:20], rs1[19:15], funct3[14:12], rd[11:7], opcode[6:0]` |
| `sb rs2, imm(rs1)` | Salva 8 bit (`rs2[7:0]`) in memoria. | `0100011` | `000` | S-type | `imm[11:5]=[31:25], rs2[24:20], rs1[19:15], funct3[14:12], imm[4:0]=[11:7], opcode[6:0]` |
| `sh rs2, imm(rs1)` | Salva 16 bit (`rs2[15:0]`) in memoria. | `0100011` | `001` | S-type | `imm[11:5]=[31:25], rs2[24:20], rs1[19:15], funct3[14:12], imm[4:0]=[11:7], opcode[6:0]` |
| `sw rs2, imm(rs1)` | Salva 32 bit di `rs2` in memoria. | `0100011` | `010` | S-type | `imm[11:5]=[31:25], rs2[24:20], rs1[19:15], funct3[14:12], imm[4:0]=[11:7], opcode[6:0]` |

#### Sistema, CSR e fence

| Istruzione | Descrizione | opcode | funct3 | funct12 / funct7 | Posizioni bitfield |
| --- | --- | --- | --- | --- | --- |
| `ecall` | Genera trap di environment call in M-mode. | `1110011` | `000` | `000000000000` | `funct12[31:20], rs1[19:15]=00000, funct3[14:12], rd[11:7]=00000, opcode[6:0]` |
| `ebreak` | Genera trap di breakpoint in M-mode. | `1110011` | `000` | `000000000001` | `funct12[31:20], rs1[19:15]=00000, funct3[14:12], rd[11:7]=00000, opcode[6:0]` |
| `csrrw rd, csr, rs1` | Scrive `rs1` in CSR e ritorna vecchio valore in `rd`. | `1110011` | `001` | CSR-type | `csr[31:20], rs1[19:15], funct3[14:12], rd[11:7], opcode[6:0]` |
| `csrrs rd, csr, rs1` | Set bit CSR con `rs1`, ritorna vecchio valore in `rd`. | `1110011` | `010` | CSR-type | `csr[31:20], rs1[19:15], funct3[14:12], rd[11:7], opcode[6:0]` |
| `csrrc rd, csr, rs1` | Clear bit CSR con `rs1`, ritorna vecchio valore in `rd`. | `1110011` | `011` | CSR-type | `csr[31:20], rs1[19:15], funct3[14:12], rd[11:7], opcode[6:0]` |
| `csrrwi rd, csr, zimm` | Scrive `zimm` in CSR e ritorna vecchio valore in `rd`. | `1110011` | `101` | CSR-type | `csr[31:20], zimm[19:15], funct3[14:12], rd[11:7], opcode[6:0]` |
| `csrrsi rd, csr, zimm` | Set bit CSR con `zimm`, ritorna vecchio valore in `rd`. | `1110011` | `110` | CSR-type | `csr[31:20], zimm[19:15], funct3[14:12], rd[11:7], opcode[6:0]` |
| `csrrci rd, csr, zimm` | Clear bit CSR con `zimm`, ritorna vecchio valore in `rd`. | `1110011` | `111` | CSR-type | `csr[31:20], zimm[19:15], funct3[14:12], rd[11:7], opcode[6:0]` |
| `fence` | Barriera memoria/ordering (in v1 puo essere trattata come no-op funzionale). | `0001111` | `000` | pred/succ nei campi immediate | `fm[31:28], pred[27:24], succ[23:20], rs1[19:15]=00000, funct3[14:12], rd[11:7]=00000, opcode[6:0]` |
| `fence.i` | Barriera instruction fetch (in v1 prevista come non implementata). | `0001111` | `001` | immediate=0 | `imm[31:20]=000000000000, rs1[19:15]=00000, funct3[14:12], rd[11:7]=00000, opcode[6:0]` |

Note implementative v1:
- Ogni istruzione non implementata nel RTL corrente genera `illegal instruction`.
- Le pseudo-istruzioni assembler (es. li, mv, nop, j, ret) sono accettate dal toolchain ma espanse in istruzioni base RV32I supportate.

### 5.2 Catalogo istruzioni RISC-V (riferimento per estensioni ISA)

Questo capitolo elenca le istruzioni standard piu comuni da usare come riferimento architetturale.
Per il progetto v1 implementiamo solo il subset dichiarato in 5.1.

#### RV32I (Base Integer ISA)
- lui, auipc
- jal, jalr
- beq, bne, blt, bge, bltu, bgeu
- lb, lh, lw, lbu, lhu
- sb, sh, sw
- addi, slti, sltiu, xori, ori, andi, slli, srli, srai
- add, sub, sll, slt, sltu, xor, srl, sra, or, and
- fence, fence.i
- ecall, ebreak
- csrrw, csrrs, csrrc, csrrwi, csrrsi, csrrci

#### RV64I/RV128I (non target v1, riferimento)
- addiw, slliw, srliw, sraiw
- addw, subw, sllw, srlw, sraw
- ld, lwu, sd

#### Estensione M (Integer Multiply/Divide)
- mul, mulh, mulhsu, mulhu
- div, divu, rem, remu
- RV64 aggiuntive: mulw, divw, divuw, remw, remuw

#### Estensione A (Atomic)
- lr.w, sc.w
- amoswap.w, amoadd.w, amoxor.w, amoand.w, amoor.w
- amomin.w, amomax.w, amominu.w, amomaxu.w
- RV64 aggiuntive: lr.d, sc.d, amoswap.d, amoadd.d, amoxor.d, amoand.d, amoor.d, amomin.d, amomax.d, amominu.d, amomaxu.d

#### Estensione F (Single-Precision Floating Point)
- flw, fsw
- fmadd.s, fmsub.s, fnmsub.s, fnmadd.s
- fadd.s, fsub.s, fmul.s, fdiv.s, fsqrt.s
- fsgnj.s, fsgnjn.s, fsgnjx.s
- fmin.s, fmax.s
- fcvt.w.s, fcvt.wu.s
- fmv.x.w
- feq.s, flt.s, fle.s
- fclass.s
- fcvt.s.w, fcvt.s.wu
- fmv.w.x
- RV64 aggiuntive: fcvt.l.s, fcvt.lu.s, fcvt.s.l, fcvt.s.lu

#### Estensione D (Double-Precision Floating Point)
- fld, fsd
- fmadd.d, fmsub.d, fnmsub.d, fnmadd.d
- fadd.d, fsub.d, fmul.d, fdiv.d, fsqrt.d
- fsgnj.d, fsgnjn.d, fsgnjx.d
- fmin.d, fmax.d
- fcvt.s.d, fcvt.d.s
- feq.d, flt.d, fle.d
- fclass.d
- fcvt.w.d, fcvt.wu.d, fcvt.d.w, fcvt.d.wu
- RV64 aggiuntive: fcvt.l.d, fcvt.lu.d, fcvt.d.l, fcvt.d.lu
- fmv.x.d, fmv.d.x (RV64)

#### Estensione C (Compressed)
- c.addi4spn
- c.lw, c.sw
- c.nop, c.addi
- c.jal (RV32), c.addiw (RV64/128)
- c.li, c.addi16sp, c.lui
- c.srli, c.srai, c.andi
- c.sub, c.xor, c.or, c.and
- c.subw, c.addw (RV64/128)
- c.j, c.beqz, c.bnez
- c.slli
- c.lwsp
- c.jr, c.mv, c.ebreak, c.jalr, c.add
- c.swsp
- RV64/128 aggiuntive: c.ld, c.sd, c.ldsp, c.sdsp

#### Zicsr (CSR Instructions)
- csrrw, csrrs, csrrc, csrrwi, csrrsi, csrrci

#### Zifencei (Instruction-Fetch Fence)
- fence.i

#### Istruzioni privilegiate (Privileged ISA, dipendono dal mode supportato)
- mret
- sret
- wfi
- sfence.vma
- hfence.vvma, hfence.gvma (hypervisor)

Note:
- L'insieme effettivamente implementato dal core e quello dichiarato in sezione 5.1.
- Questo catalogo serve come reference per evoluzioni future (RV32IM, RV32IMC, RV32IMAFD, ecc.).
- In caso di dubbi su varianti/edge-case, fare riferimento alla specifica ufficiale RISC-V ISA.

## 6. Memoria e mappa indirizzi (stato RTL attuale)
Nel RTL corrente sono presenti due memorie dedicate di bring-up:
- Modulo: `riscv_imem`
- Organizzazione: array di parole a 32 bit (`IMEM_WORDS`, default 1024)
- Init: preload opzionale da file HEX (`$readmemh`)
- Comportamento corrente:
  - response combinatoria zero-wait-state
  - fetch fuori range o misallineato ritorna NOP (`32'h0000_0013`)

- Modulo: `riscv_dmem`
- Organizzazione: array di parole a 32 bit (`DMEM_WORDS`, default 1024)
- Supporto accessi: byte/halfword/word per load/store
- Comportamento corrente:
  - write sincrona
  - read combinatoria zero-wait-state
  - accessi load signed/unsigned con sign/zero extension
  - read misallineata o fuori range ritorna `32'h0000_0000`

Collocazione nel datapath RTL:
- IMEM istanziata in `riscv_if_stage`.
- DMEM istanziata in `riscv_wb_stage`.

Nota:
- La mappa memoria SoC completa (ROM/SRAM/periferiche) e rimandata a una fase successiva.

## 7. Interfaccia bus (stato RTL attuale)
Per la versione corrente non e esposta una interfaccia bus esterna standard (es. APB/AHB/AXI).
Le interfacce memoria sono interne al core:
- fetch istruzioni interno in IF (`riscv_if_stage` <-> `riscv_imem`)
- accesso dati interno in WB (`riscv_wb_stage` <-> `riscv_dmem`)

Nota:
- Al top-level `riscv_top` sono esposti solo `clk_i`, `rst_ni`, `illegal_instr_o`.
- Protocollo bus completo con wait-state/stall resta pianificato per step successivi.

## 8. Reset, clock, interrupt
- Clock singolo di sistema.
- Reset attivo basso asincrono usato direttamente nei registri pipeline (`always_ff @(posedge clk_i or negedge rst_ni)`).
- Interrupt non implementati nel RTL corrente.

## 9. CSR (subset minimo)
CSR non implementate nel RTL corrente.

Stato attuale:
- le istruzioni CSR sono decode illegale
- non e presente file CSR dedicato
- non e presente trap handler architetturale completo

## 10. Gestione hazard e controllo pipeline
- Data hazard:
  - forwarding selettivo implementato su due livelli:
    - EX -> EX (back-to-back ALU RAW)
    - WB -> EX (RAW con un'istruzione di distanza)
  - bypass attivo per `rs1`/`rs2` quando il registro destinazione non e `x0` e matcha il registro sorgente.
  - interlock/stall non implementati.
- Control hazard:
  - branch/jump implementati con redirect PC da ID/EX.
  - flush IF/ID implementato su redirect preso.
  - trap/exception flow non implementato.
- Implicazione pratica: molte dipendenze RAW ALU sono risolte; restano casi che richiedono stall/interlock esplicito (es. alcune dipendenze load-use).

## 11. Performance target iniziale (da affinare)
- Target frequenza iniziale per primi run di sintesi: 200 MHz.
- CPI target su codice semplice (no cache, no branch prediction): ~1.2 - 1.8.
- Questi target sono preliminari e verranno calibrati con report Genus/Innovus.

## 12. Esclusioni esplicite dalla v1
- Cache istruzioni/dati.
- MMU/virtual memory.
- Privilege modes oltre M-mode.
- Estensioni ISA avanzate (A/F/D/C/M).
- Debug hardware completo.

## 13. Requisiti minimi di verifica (entry-level)
- Smoke test:
  - reset vector corretto
  - sequenza base ALU
  - check load/store (implementati)
  - check branch/jump/pc-redirection (implementati)
- Directed ISA tests (subset RV32I implementato).
- Test trap:
  - illegal instruction (parziale)
  - misaligned/invalid access (solo modello IMEM di bring-up)
- Coverage iniziale:
  - code coverage RTL
  - functional coverage su classi istruzioni principali.

Stato testbench disponibile:
- `source/sv/tb/riscv_top_tb.sv` creato con clock/reset e check registri finali.
- Programma di test in `source/sv/rtl/imem_hex_file.hex` (include anche load/store DMEM).
- Legenda e expected values in `source/sv/rtl/imem_test_sequence.md`.

## 14. Deliverable collegati a questa specifica
- Documento microarchitettura dettagliata (block diagram + timing semplificato).
- Skeleton RTL top + pipeline stages.
- Moduli ALU dedicati: add/sub, shift, logic, compare.
- Modulo register file dedicato.
- Moduli memory dedicati: `riscv_imem` (IF) e `riscv_dmem` (WB).
- Wrapper top (`riscv_top`).
- Testbench base per smoke test.
- Vincoli iniziali clock/reset/IO per sintesi.

## 15. Stato implementazione RTL (snapshot)
Moduli principali presenti nel repository RTL:
- `riscv.sv`
- `riscv_if_stage.sv`
- `riscv_id_ex_stage.sv`
- `riscv_wb_stage.sv`
- `riscv_regfile.sv`
- `riscv_alu_addsub.sv`
- `riscv_alu_shift.sv`
- `riscv_alu_logic.sv`
- `riscv_alu_compare.sv`
- `riscv_imem.sv`
- `riscv_dmem.sv`
- `riscv_top.sv`

Obiettivo del prossimo step RTL:
- Implementare interlock/stall minimo e gestione trap/CSR.

## 16. Decisioni aperte (da chiudere prima del freeze v1)
- Inclusione o meno dell'estensione M nella prima tape-in candidate.
- Definizione definitiva protocollo bus (custom vs APB/AHB-lite bridge).
- Dimensionamento ROM/SRAM in base al software di boot.
- Strategia interrupt (solo external o anche timer/software interrupt).
