#!/usr/bin/env python3
"""tests.log -> measured.tsv: one `key<TAB>value[<TAB>value...]` row per measured quantity.

Keys come from the PAPER lines report.patch adds, plus the summary lines the
m9 / m10 tests already print (L-BFGS vs GD, Jacobian conditioning, timings).
Repeated keys keep the last value (a few operands print once per assertion).
Also checks that every test result line reports `ok` and exits non-zero otherwise.
"""
import re
import sys

rows, failed = {}, []
for line in open(sys.argv[1], encoding="utf8", errors="replace"):
    line = line.rstrip("\n")
    if "PAPER\t" in line:
        parts = line[line.index("PAPER\t"):].split("\t")
        rows[parts[1]] = parts[2:]
        continue
    if m := re.match(r"test (\S+) \.\.\. (ok|FAILED|ignored)", line):
        if m.group(2) == "FAILED":
            failed.append(m.group(1))
        rows[f"test::{m.group(1)}"] = [m.group(2)]
        continue
    if m := re.search(r"L-BFGS: stop (\w+), iters (\d+), evals (\d+), J (\S+), .*inf (\S+)", line):
        for k, v in zip(("stop", "iters", "evals", "J", "err_inf"), m.groups()):
            rows[f"m9::lbfgs::{k}"] = [v]
    elif m := re.search(r"GD:\s+stop (\w+), iters (\d+), evals (\d+), J (\S+), .*inf (\S+)", line):
        for k, v in zip(("stop", "iters", "evals", "J", "err_inf"), m.groups()):
            rows[f"m9::gd::{k}"] = [v]
    elif m := re.search(r"QoI Jacobian det (\S+), min pivot (\S+)", line):
        rows["m9::jac::det"], rows["m9::jac::min_pivot"] = [m.group(1)], [m.group(2)]
    elif m := re.search(r"^k(\d): forward (\S+) reverse (\S+) rel (\S+)", line):
        rows[f"m9::fwd_vs_rev::{m.group(1)}"] = list(m.groups()[1:])
    elif m := re.search(r"^FD k(\d): reverse (\S+) fd (\S+) rel (\S+)", line):
        rows[f"m9::fd::{m.group(1)}"] = list(m.groups()[1:])
    elif m := re.search(r"shared build\+capture (\S+) ms/iterate; differentiation: forward (\S+) ms .* reverse (\S+) ms", line):
        rows["m9::ms::build_capture"], rows["m9::ms::forward"], rows["m9::ms::reverse"] = [[g] for g in m.groups()]

    if m := re.search(r"segs=\s*(\d+) nodes=\s*(\d+): capture\s+(\S+)\s+seam\s+(\S+)\s+pullback\s+(\S+)", line):
        rows[f"m10::timing::{m.group(1)}"] = list(m.groups()[1:])
    if m := re.search(r"(rounded cube|flywheel)\s+segs=\s*(\d+) nodes=\s*(\d+) topo-verts=\s*(\d+): naive\s+(\S+)\s+grid\s+(\S+)", line):
        rows[f"m10::grid::{m.group(1).replace(' ', '_')}::{m.group(2)}"] = list(m.groups()[2:])

for k, v in rows.items():
    print("\t".join([k, *v]))
if failed:
    sys.exit(f"FAILED tests: {failed}")
