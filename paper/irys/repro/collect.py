#!/usr/bin/env python3
"""tests.log + constants.tsv -> measured.tsv: `key<TAB>value<TAB>source` per quantity.

Values come from the `PAPER<TAB>key<TAB>value` lines irys's tests and examples
print. A key printed more than once keeps every value; keys ending in `_ms`
from repeated runs become `<key>_lo` / `<key>_hi`, and the rest keep the last.
Exits non-zero if any test reports FAILED.
"""
import re
import sys

log, constants, rev = sys.argv[1], sys.argv[2], sys.argv[3][:10]
vals, failed = {}, []
for line in open(log, encoding="utf8", errors="replace"):
    line = line.rstrip("\n")
    if "PAPER\t" in line:
        _, k, v = line[line.index("PAPER\t"):].split("\t")[:3]
        vals.setdefault(k, []).append(v)
    elif m := re.match(r"test (\S+) \.\.\. FAILED", line):
        failed.append(m.group(1))

rows = {}
for line in open(constants, encoding="utf8"):
    if line.strip() and not line.startswith("#"):
        k, v, src = (line.rstrip("\n").split("\t") + [""])[:3]
        rows[k] = (v, src)
for k, vs in vals.items():
    src = f"repro irys {rev}"
    if k.endswith("_ms") and len(vs) > 1:
        f = [float(v) for v in vs]
        rows[k.removesuffix("_ms") + "_lo"] = (f"{min(f):.4g}", src)
        rows[k.removesuffix("_ms") + "_hi"] = (f"{max(f):.4g}", src)
    rows[k] = (vs[-1], src)
for k, (v, src) in rows.items():
    print(f"{k}\t{v}\t{src}")
if failed:
    sys.exit(f"FAILED tests: {failed}")
