Working personal projects, aiming to build from scratch a CPU with RICV Architecture and an optimized OS for it.
Actually the RISCV usa a Set Associative Cache. Test will be done in order to find best policy for Instruction cache and Data cache.
Out Of Order execution will be implemented in future. So far, Stall has been managed creating bypass and buble instatiation in case of a sequence LOAD-STORE.
So Far, 3 pipeline stage are implemented. Future synthesis will give timing in order to have data to support possible variation.
A major point will be the insertion of a convolutional accelerator, trying to integrate a ML acceleration. This will bring to some modification to Architecture.
After having a working CPU, the next step is to build above an optimized OS.
