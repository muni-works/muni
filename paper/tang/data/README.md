# tang paper: data behind the post

Snapshots of the tang files the numbers in `../tang.typ` come from, taken from
[muni-works/tang](https://github.com/muni-works/tang) at tag `paper-2026-11-10`
(commit `e0cd9141`, 2026-11-10):

| file | what |
|---|---|
| `BENCHMARKS.md` | every measurement, with the command, date, machine and its load at the time. The idle-GPU re-measurements are in the section "Blind-review measurements". |
| `tensor-ir.md` | the IR's design notes: views, comprehensions, rewrites, backward, precision, lowerings |
| `duality.md` | the IO floor and tile as one linear program, the floor table and its corrections, the per-tile race |
| `figure1-cuda.json` | Figure 1 on the RTX 3090, from `crates/tang-bench/examples/figure1_cuda.rs` |
| `memory-axis.json` | the memory-axis sweep behind the dial on the web page |
| `derive-gallery.csv` | the derived-kernel gallery table |

Raw outputs for the re-measurements are in the tang repository under
`crates/tang-llm/docs/bench/review/`.

Machines: an M4 Max Mac, `mew` (one RTX 3090), a rented H200, and the Booster K1's QCS8550
(Adreno 740, Cortex-X3). BENCHMARKS.md says which runs shared the GPU with other jobs.
