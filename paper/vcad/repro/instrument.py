#!/usr/bin/env python3
"""Generate report.patch: add `PAPER<TAB>key<TAB>value` prints to vcad's gate tests.

Used once, by hand, to produce repro/report.patch against the pinned vcad commit.
The patch only adds eprintln! lines after statements that already compute a
measured quantity (a relative error, a node-wise comparison, a continuum gap),
so every gate keeps its own assertion and the printed value is the one it checks.

    python3 instrument.py <vcad-checkout>      # edits the test files in place
    (cd <vcad-checkout> && git diff) > report.patch
"""
import re
import sys
from pathlib import Path

FILES = [
    "crates/vcad-kernel-diff/tests/m0_extrude_volume.rs",
    "crates/vcad-kernel-diff/tests/m1_frozen_lift.rs",
    "crates/vcad-kernel-diff/tests/m2_boolean_hole.rs",
    "crates/vcad-kernel-diff/tests/m3_boundary_trim.rs",
    "crates/vcad-kernel-diff/tests/m3_mass_properties.rs",
    "crates/vcad-kernel-diff/tests/m4_fillet_radius.rs",
    "crates/vcad-kernel-diff/tests/m5_reverse_mode.rs",
    "crates/vcad-kernel-diff/tests/m6_synthesized_seeding.rs",
    "crates/vcad-kernel-diff/tests/m7_cone_torus.rs",
    "crates/vcad-kernel-diff/tests/m9_many_parameters.rs",
    "crates/vcad-kernel-diff/tests/m3_flywheel_optimize.rs",
    "crates/vcad-kernel-diff/tests/m10_second_order.rs",
    "crates/vcad-kernel-physics/tests/m8_rollout_gradient.rs",
    "crates/vcad-kernel-physics/tests/m11_adjoint_rollout.rs",
    "crates/vcad-kernel-physics/tests/m11_contact_gradient.rs",
    "crates/vcad-eval/tests/document_gradient.rs",
]

FN_RE = re.compile(r"^(?:pub )?fn (\w+)")
# single-line `let <name> = <expr>;` whose name marks a measured comparison
LET_RE = re.compile(r"^(\s*)let (rel\w*|gap\w*) = (.*);\s*$")
CMP_RE = re.compile(r"^(\s*)let (\w+) = compare_velocities\(.*\);\s*$")
IDENT_RE = re.compile(r"(?<![\w.:])([a-z_][a-z0-9_]*)\b(?!\s*[(!:\[.])")
SKIP = {"as", "f64", "abs", "max", "min", "std", "powi", "sqrt", "norm", "let", "mut", "if", "else"}


REL_ASSERT_RE = re.compile(r"^(\s*)rel\((\w+), (\w+)\) <= \w+,\s*$")
LABEL_RE = re.compile(r"\b(what|label): &str")

# (file stem, anchor substring, lines to add after the anchor line)
MANUAL = [
    ("document_gradient", "let rel = (g.derivative.volume - dv_exact).abs() / dv_exact;", [
        'eprintln!("PAPER\\tdocument_gradient::ir::dv\\t{:e}", g.derivative.volume);',
    ]),
    ("document_gradient", "let rel_izz = (g.derivative.inertia_origin[2][2] - fd_izz).abs() / fd_izz.abs();", [
        'eprintln!("PAPER\\tdocument_gradient::ir::dizz\\t{:e}", g.derivative.inertia_origin[2][2]);',
    ]),
    ("document_gradient", "let rel = (g.d_volume - fd_dv).abs() / fd_dv.abs();", [
        'eprintln!("PAPER\\tdocument_gradient::sens::dv\\t{:e}", g.d_volume);',
    ]),
    ("m5_reverse_mode", "let scale = fwd.abs().max(1.0);", [
        'eprintln!("PAPER\\tm5_reverse_mode::agree::{}::fwd\\t{:e}", what, fwd);',
        'eprintln!("PAPER\\tm5_reverse_mode::agree::{}::rev\\t{:e}", what, rev);',
    ]),
    ("m9_many_parameters", "let gd_evals = gd_evals.get();", [
        'for (n, it) in lbfgs.history.iter().enumerate() { eprintln!("PAPER\\tm9::lbfgs::J::{}\\t{:e}", n, it.objective); }',
        'for (n, it) in gd.history.iter().enumerate() { eprintln!("PAPER\\tm9::gd::J::{}\\t{:e}", n, it.objective); }',
    ]),
    ("m3_flywheel_optimize", 'eprintln!("stop: {:?}", result.stop);', [
        'for (n, it) in result.history.iter().enumerate() { eprintln!("PAPER\\tm3_flywheel::iter::{}\\t{:e}\\t{:e}\\t{:e}", n, it.theta[0], it.theta[1], it.objective); }',
    ]),
    ("m4_fillet_radius", "assert!(result.stop != StopReason::MaxIters", [
        'eprintln!("PAPER\\tm4_fillet_radius::optimize::r\\t{:e}", result.theta[0]);',
        'eprintln!("PAPER\\tm4_fillet_radius::optimize::iters\\t{:e}", result.history.len() as f64);',
    ]),
]


def instrument(path: Path) -> int:
    out, fn, label, added = [], "?", None, 0
    lines = path.read_text().splitlines()
    for lineno, line in enumerate(lines, 1):
        out.append(line)
        for stem, anchor, extra in MANUAL:
            if stem == path.stem and anchor in line:
                ind = re.match(r"^\s*", line).group(0)
                out.extend(ind + e for e in extra)
                added += 1
        m = FN_RE.match(line)
        if m:
            fn = m.group(1)
            lm = LABEL_RE.search(line)
            label = lm.group(1) if lm else None
            continue
        if label is None:
            lm = LABEL_RE.search(line) if line.startswith("    ") and ":" in line and fn != "?" and line.strip().endswith(",") else None
            if lm:
                label = lm.group(1)
        m = REL_ASSERT_RE.match(line)
        if m:
            ind, a, b = m.groups()
            # print just before the assert! line it belongs to
            stmt = out.pop(); head = out.pop()
            for v, nm in ((a, a), (b, b), (f"rel({a}, {b})", f"rel_{a}_vs_{b}")):
                out.append(emit(ind[:-4], path.stem, fn, label, nm, v))
            out.append(head); out.append(stmt)
            added += 1
            continue
        m = LET_RE.match(line)
        if m:
            ind, name, expr = m.groups()
            idents = []
            # operands are printed only when they are plain scalars (no vectors/norms)
            idx = re.findall(r"(?<![\w.])([a-z_][a-z0-9_]*\[0\])", expr)
            for i in ([] if ".norm()" in expr else IDENT_RE.findall(expr) + idx):
                if i not in SKIP and i not in idents and not i.isupper():
                    idents.append(i)
            # the comparison operands first (seam value, oracle value), then the error itself
            for i in idents + [name]:
                out.append(emit(ind, path.stem, f"{fn}@L{lineno}", label, i.replace("[0]", ""), i))
            added += 1
            continue
        m = CMP_RE.match(line)
        if m:
            ind, name = m.groups()
            out.append(emit(ind, path.stem, fn, label, f"{name}.max_rel_err", f"{name}.max_rel_err"))
            added += 1
    path.write_text("\n".join(out) + "\n")
    return added


def emit(ind, stem, fn, label, name, expr):
    if label:
        return f'{ind}eprintln!("PAPER\\t{stem}::{fn}::{{}}::{name}\\t{{:e}}", {label}, ({expr}) as f64);'
    return f'{ind}eprintln!("PAPER\\t{stem}::{fn}::{name}\\t{{:e}}", ({expr}) as f64);'


if __name__ == "__main__":
    root = Path(sys.argv[1])
    for f in FILES:
        p = root / f
        if p.exists():
            print(f"{f}: {instrument(p)} sites", file=sys.stderr)
