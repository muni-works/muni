# tang paper: data behind the post

Snapshots of the two tang files every number in `../tang.typ` comes from, taken from
ecto/tang at `b1074e6f` (2026-11-06):

| file | what |
|---|---|
| `BENCHMARKS.md` | every measurement, with the command, date, machine and its load at the time |
| `tensor-ir.md` | the IR's design notes: views, comprehensions, rewrites, backward, precision, lowerings |

Machines: an M4 Max Mac, `mew` (one shared RTX 3090), and the Booster K1's QCS8550 (Adreno 740,
Cortex-X3). Several runs shared the GPU with other jobs; BENCHMARKS.md says which.
