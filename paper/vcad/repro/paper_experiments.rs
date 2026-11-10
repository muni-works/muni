// Experiments added for the paper, beyond vcad's own gate tests. repro.sh copies this file into
// crates/vcad-kernel-diff/tests/ next to paper_m9_base.rs (m9_many_parameters.rs without its //! header).
// Each test prints PAPER<TAB>key<TAB>value lines; only tests named paper_* are run.
include!("paper_m9_base.rs");

use vcad_kernel_diff::{synthesize_all, synthesize_seeding, volume_with_derivative};
use vcad_kernel_primitives::{make_cone, make_cylinder, make_torus};

fn p(key: &str, v: f64) {
    eprintln!("PAPER\t{key}\t{v:e}");
}

const STEPS: [i32; 6] = [-6, -5, -4, -3, -2, -1];

fn tess_n(n: u32, hs: u32) -> TessellationParams {
    TessellationParams { circle_segments: n, height_segments: hs, latitude_segments: n, ..Default::default() }
}

/// Rebuild, tessellate from scratch, integrate: no plan shared between evaluations.
fn fresh_volume(b: &BRepSolid, t: &TessellationParams) -> Option<(f64, usize)> {
    let plan = capture_plan(b, t).ok()?;
    let m = evaluate_plan(b, &plan).ok()?;
    Some((m.volume(), plan.nodes.len()))
}

struct Case {
    name: &'static str,
    theta: f64,
    tess: TessellationParams,
    build: Box<dyn Fn(f64) -> BRepSolid>,
}

fn table1_cases() -> Vec<Case> {
    use vcad_kernel_sketch::SketchProfile;
    let t = 0.25f64;
    let a0 = t.atan();
    vec![
        Case { name: "extrude", theta: 2.0, tess: tess_n(16, 2), build: Box::new(|d| {
            let pr = SketchProfile::rectangle(Point3::origin(), Vec3::x(), Vec3::y(), 4.0, 3.0);
            vcad_kernel_sketch::extrude(&pr, Vec3::z() * d).expect("extrude")
        }) },
        Case { name: "hole_r", theta: 2.5, tess: tess_n(32, 3), build: Box::new(|r| {
            Solid::cube(10.0, 8.0, 5.0).difference(&Solid::cylinder(r, 7.0, 32).translate(5.0, 4.0, -1.0)).as_brep().unwrap().clone()
        }) },
        Case { name: "cyl_h", theta: 8.0, tess: tess_n(24, 4), build: Box::new(|h| make_cylinder(5.0, h, 24)) },
        Case { name: "fillet_r", theta: 1.5, tess: tess_n(16, 2), build: Box::new(|r| {
            vcad_kernel_fillet::fillet_all_edges(&make_cube(10.0, 10.0, 10.0), r)
        }) },
        Case { name: "fillet_a", theta: 10.0, tess: tess_n(16, 2), build: Box::new(|a| {
            vcad_kernel_fillet::fillet_all_edges(&make_cube(a, a, a), 1.5)
        }) },
        Case { name: "cone_a", theta: a0, tess: tess_n(24, 2), build: Box::new(|al: f64| {
            let t = al.tan();
            make_cone(20.0 * t, 12.0 * t, 8.0, 24)
        }) },
        Case { name: "cone_h", theta: 8.0, tess: tess_n(24, 2), build: Box::new(|h| make_cone(5.0, (20.0 - h) * 0.25, h, 24)) },
        Case { name: "torus_r", theta: 3.0, tess: tess_n(24, 2), build: Box::new(|r| make_torus(8.0, r, 24)) },
        Case { name: "torus_R", theta: 8.0, tess: tess_n(24, 2), build: Box::new(|m| make_torus(m, 3.0, 24)) },
    ]
}

/// Seam dV/dθ with a synthesized seeding (the base handed to the synthesizer is the instance the seam uses).
fn seam_dv(build: &dyn Fn(f64) -> BRepSolid, th: f64, t: &TessellationParams) -> Option<(f64, f64, usize)> {
    let base = build(th);
    let f = |x: &[f64]| if x[0] == th { base.clone() } else { build(x[0]) };
    let s = synthesize_seeding(&f, &[th], 0, 1e-6).ok()?;
    let plan = capture_plan(&base, t).ok()?;
    let seam = evaluate_with_sensitivity(&base, &plan, &s).ok()?;
    let (v, dv) = volume_with_derivative(&seam);
    Some((v, dv, plan.nodes.len()))
}

#[test]
fn paper_rebuild_fd_no_shared_plan() {
    for c in table1_cases() {
        if let Some((_, dv, n)) = seam_dv(&*c.build, c.theta, &c.tess) {
            p(&format!("rebuild::{}::seam", c.name), dv);
            p(&format!("rebuild::{}::nodes", c.name), n as f64);
        }
        for e in STEPS {
            let h = 10f64.powi(e);
            let a = fresh_volume(&(c.build)(c.theta + h), &c.tess);
            let b = fresh_volume(&(c.build)(c.theta - h), &c.tess);
            if let (Some((va, na)), Some((vb, nb))) = (a, b) {
                p(&format!("rebuild::{}::fd::{e}", c.name), (va - vb) / (2.0 * h));
                p(&format!("rebuild::{}::dn::{e}", c.name), na as f64 - nb as f64);
            }
        }
    }
}

fn rel_miss_j(q: &[f64; 5], t: &Targets) -> f64 {
    let r = residuals(q, t);
    r.iter().map(|x| x * x).sum()
}
fn residuals(q: &[f64; 5], t: &Targets) -> [f64; 5] {
    [(q[0] - t.v) / t.v, (q[1] - t.c[0]) / t.c[0], (q[2] - t.c[1]) / t.c[1], (q[3] - t.c[2]) / t.c[2], (q[4] - t.izz) / t.izz]
}
/// The QoIs at θ on a mesh tessellated from scratch at θ.
fn fresh_q(theta: &[f64]) -> Option<([f64; 5], usize)> {
    let b = build(theta);
    let plan = capture_plan(&b, &tess()).ok()?;
    let m = evaluate_plan(&b, &plan).ok()?;
    let (v, c, p0, p1) = moments(&m.positions, &m.triangles);
    Some(([v, c[0] / v, c[1] / v, c[2] / v, p0 + p1], plan.nodes.len()))
}

#[test]
fn paper_fd_step_sweep_on_five_parameter_box() {
    let t = targets_at(&THETA_STAR);
    let rev = QoiMatch { t };
    let (_, g) = objective_gradient_reverse(&build, &seeding_for, &rev, &THETA0, &tess()).unwrap();
    let plan = capture_plan(&build(&THETA0), &tess()).unwrap();
    for k in 0..5 {
        p(&format!("sweep::seam::{k}"), g[k]);
        for e in -8..=-1 {
            let h = 10f64.powi(e);
            let (mut a, mut b) = (THETA0, THETA0);
            a[k] += h;
            b[k] -= h;
            let planned = |x: &[f64; 5]| -> Option<f64> {
                let m = evaluate_plan(&build(x), &plan).ok()?;
                let (v, c, p0, p1) = moments(&m.positions, &m.triangles);
                Some(rel_miss_j(&[v, c[0] / v, c[1] / v, c[2] / v, p0 + p1], &t))
            };
            if let (Some(ja), Some(jb)) = (planned(&a), planned(&b)) {
                p(&format!("sweep::plan::{k}::{e}"), (ja - jb) / (2.0 * h));
            }
            if let (Some((qa, _)), Some((qb, _))) = (fresh_q(&a), fresh_q(&b)) {
                p(&format!("sweep::fresh::{k}::{e}"), (rel_miss_j(&qa, &t) - rel_miss_j(&qb, &t)) / (2.0 * h));
            }
        }
    }
}

#[test]
fn paper_fillet_continuum_gap_vs_resolution() {
    let minkowski_d = |r: f64| {
        let a = 10.0 - 2.0 * r;
        let pi = std::f64::consts::PI;
        -24.0 * a * r - 6.0 * pi * r * r + 6.0 * pi * a * r + 4.0 * pi * r * r
    };
    let f = |r: f64| vcad_kernel_fillet::fillet_all_edges(&make_cube(10.0, 10.0, 10.0), r);
    p("gap::continuum", minkowski_d(1.5));
    for n in [8u32, 16, 32, 64, 128, 256] {
        if let Some((v, dv, nodes)) = seam_dv(&f, 1.5, &tess_n(n, 2)) {
            p(&format!("gap::{n}::dv"), dv);
            p(&format!("gap::{n}::v"), v);
            p(&format!("gap::{n}::nodes"), nodes as f64);
        }
    }
}

struct Hist {
    rows: Vec<(f64, f64, f64, usize)>,
}

fn solve(mut a: Vec<Vec<f64>>, mut b: Vec<f64>) -> Vec<f64> {
    let n = b.len();
    for c in 0..n {
        let piv = (c..n).max_by(|x, y| a[*x][c].abs().total_cmp(&a[*y][c].abs())).unwrap();
        a.swap(c, piv);
        b.swap(c, piv);
        for r in c + 1..n {
            let f = a[r][c] / a[c][c];
            for k in c..n {
                let v = a[c][k];
                a[r][k] -= f * v;
            }
            b[r] -= f * b[c];
        }
    }
    for c in (0..n).rev() {
        for k in c + 1..n {
            b[c] -= a[c][k] * b[k];
        }
        b[c] /= a[c][c];
    }
    b
}

const DOT: fn(&[f64], &[f64]) -> f64 = |a, b| a.iter().zip(b).map(|(x, y)| x * y).sum();

/// The same projected L-BFGS (memory 8, Armijo 1e-4, halving) for every gradient oracle.
#[allow(clippy::type_complexity)]
fn lbfgs_driver(
    x0: &[f64],
    bounds: &[(f64, f64)],
    max_iters: usize,
    gtol: f64,
    j: &dyn Fn(&[f64]) -> Option<(f64, usize)>,
    g: &dyn Fn(&[f64]) -> Option<Vec<f64>>,
    err: &dyn Fn(&[f64]) -> f64,
) -> Hist {
    let t0 = Instant::now();
    let ms = || t0.elapsed().as_secs_f64() * 1e3;
    let project = |x: &mut Vec<f64>| {
        for (v, b) in x.iter_mut().zip(bounds) {
            *v = v.clamp(b.0, b.1);
        }
    };
    let mut x = x0.to_vec();
    let (mut fx, mut nodes) = j(&x).unwrap();
    let mut gx = g(&x).unwrap();
    let mut mem: Vec<(Vec<f64>, Vec<f64>)> = vec![];
    let mut h = Hist { rows: vec![(ms(), fx, err(&x), nodes)] };
    for _ in 0..max_iters {
        if DOT(&gx, &gx).sqrt() < gtol {
            break;
        }
        // two-loop recursion
        let mut d: Vec<f64> = gx.clone();
        let mut al = vec![0.0; mem.len()];
        for (i, (s, y)) in mem.iter().enumerate().rev() {
            al[i] = DOT(s, &d) / DOT(y, s);
            for (v, yy) in d.iter_mut().zip(y) {
                *v -= al[i] * yy;
            }
        }
        let first = mem.is_empty();
        if let Some((s, y)) = mem.last() {
            let gam = DOT(s, y) / DOT(y, y);
            d.iter_mut().for_each(|v| *v *= gam);
        }
        for (i, (s, y)) in mem.iter().enumerate() {
            let be = DOT(y, &d) / DOT(y, s);
            for (v, ss) in d.iter_mut().zip(s) {
                *v += (al[i] - be) * ss;
            }
        }
        d.iter_mut().for_each(|v| *v = -*v);
        if DOT(&d, &gx) >= 0.0 {
            mem.clear();
            d = gx.iter().map(|v| -v).collect();
        }
        let mut t = if first { 0.5 / DOT(&d, &d).sqrt() } else { 1.0 };
        let mut acc = None;
        for _ in 0..40 {
            let mut y: Vec<f64> = x.iter().zip(&d).map(|(a, b)| a + t * b).collect();
            project(&mut y);
            let s: Vec<f64> = y.iter().zip(&x).map(|(a, b)| a - b).collect();
            if let Some((fy, n)) = j(&y) {
                if fy <= fx + 1e-4 * DOT(&gx, &s) {
                    acc = Some((y, s, fy, n));
                    break;
                }
            }
            t *= 0.5;
        }
        let Some((y, s, fy, n)) = acc else { break };
        let Some(gy) = g(&y) else { break };
        let dg: Vec<f64> = gy.iter().zip(&gx).map(|(a, b)| a - b).collect();
        if DOT(&s, &dg) > 1e-12 * DOT(&s, &s).sqrt() * DOT(&dg, &dg).sqrt() {
            mem.push((s, dg));
            if mem.len() > 8 {
                mem.remove(0);
            }
        }
        x = y;
        fx = fy;
        gx = gy;
        nodes = n;
        h.rows.push((ms(), fx, err(&x), nodes));
    }
    h
}

fn report(name: &str, h: &Hist) {
    for (i, r) in h.rows.iter().enumerate() {
        eprintln!("PAPER\tbase::{name}::{i}\t{:e}\t{:e}\t{:e}\t{}", r.0, r.1, r.2, r.3);
    }
    let last = h.rows.last().unwrap();
    p(&format!("base::{name}::iters"), (h.rows.len() - 1) as f64);
    p(&format!("base::{name}::ms"), last.0);
    p(&format!("base::{name}::J"), last.1);
    p(&format!("base::{name}::err"), last.2);
    let mut seen: Vec<usize> = h.rows.iter().map(|r| r.3).collect();
    seen.sort_unstable();
    seen.dedup();
    p(&format!("base::{name}::distinct_nodes"), seen.len() as f64);
}

#[test]
fn paper_optimizer_baselines() {
    let t = targets_at(&THETA_STAR);
    let rev = QoiMatch { t };
    let bounds = options().bounds;
    let err = |x: &[f64]| x.iter().zip(&THETA_STAR).map(|(a, b)| (a - b).abs()).fold(0.0_f64, f64::max);
    let j = |x: &[f64]| fresh_q(x).map(|(q, n)| (rel_miss_j(&q, &t), n));
    let seam = |x: &[f64]| objective_gradient_reverse(&build, &seeding_for, &rev, x, &tess()).ok().map(|r| r.1);
    report("lbfgs_seam", &lbfgs_driver(&THETA0, &bounds, 200, 1e-9, &j, &seam, &err));
    for e in [-6, -4, -2] {
        let h = 10f64.powi(e);
        let fd = |x: &[f64]| -> Option<Vec<f64>> {
            let mut g = vec![0.0; 5];
            for k in 0..5 {
                let (mut a, mut b) = (x.to_vec(), x.to_vec());
                a[k] += h;
                b[k] -= h;
                g[k] = (j(&a)?.0 - j(&b)?.0) / (2.0 * h);
            }
            Some(g)
        };
        report(&format!("lbfgs_fd{}", -e), &lbfgs_driver(&THETA0, &bounds, 200, 1e-9, &j, &fd, &err));
    }
    // Levenberg-Marquardt on the residual vector, with the seam's exact 5x5 Jacobian
    let t0 = Instant::now();
    let jac = |x: &[f64]| -> Option<Vec<Vec<f64>>> {
        let b = build(x);
        let plan = capture_plan(&b, &tess()).ok()?;
        let mut rows = vec![vec![0.0; 5]; 5];
        for k in 0..5 {
            let seam = evaluate_with_sensitivity(&b, &plan, &seeding_for(&b, k)).ok()?;
            let (_, d) = mass_properties_with_derivative(&seam, RHO);
            rows[0][k] = d.volume / t.v;
            rows[1][k] = d.centroid.x / t.c[0];
            rows[2][k] = d.centroid.y / t.c[1];
            rows[3][k] = d.centroid.z / t.c[2];
            rows[4][k] = d.inertia_origin[2][2] / t.izz;
        }
        Some(rows)
    };
    let mut x = THETA0.to_vec();
    let (q, n) = fresh_q(&x).unwrap();
    let mut r = residuals(&q, &t);
    let mut fx = DOT(&r, &r);
    let mut lam = 1e-4;
    let mut h = Hist { rows: vec![(0.0, fx, err(&x), n)] };
    for _ in 0..100 {
        if fx < 1e-24 {
            break;
        }
        let jm = jac(&x).unwrap();
        let mut stepped = false;
        for _ in 0..30 {
            let mut a = vec![vec![0.0; 5]; 5];
            let mut b = vec![0.0; 5];
            for i in 0..5 {
                for k in 0..5 {
                    for row in jm.iter() {
                        a[i][k] += row[i] * row[k];
                    }
                }
                a[i][i] *= 1.0 + lam;
                for (row, ri) in jm.iter().zip(&r) {
                    b[i] -= row[i] * ri;
                }
            }
            let d = solve(a, b);
            let mut y: Vec<f64> = x.iter().zip(&d).map(|(p, q)| p + q).collect();
            for (v, bd) in y.iter_mut().zip(&bounds) {
                *v = v.clamp(bd.0, bd.1);
            }
            if let Some((q, n)) = fresh_q(&y) {
                let ry = residuals(&q, &t);
                let fy = DOT(&ry, &ry);
                if fy < fx {
                    x = y;
                    r = ry;
                    fx = fy;
                    lam = (lam * 0.3).max(1e-12);
                    h.rows.push((t0.elapsed().as_secs_f64() * 1e3, fx, err(&x), n));
                    stepped = true;
                    break;
                }
            }
            lam *= 10.0;
        }
        if !stepped {
            break;
        }
    }
    report("lm_seam", &h);
}

#[test]
fn paper_costs() {
    let t = targets_at(&THETA_STAR);
    let fwd = forward_objective(t);
    let rev = QoiMatch { t };
    let reps = 30;
    let brep = build(&THETA_STAR);
    let plan = capture_plan(&brep, &tess()).unwrap();
    p("cost::nodes", plan.nodes.len() as f64);
    let ms = |f: &mut dyn FnMut()| {
        let t0 = Instant::now();
        for _ in 0..reps {
            f();
        }
        t0.elapsed().as_secs_f64() * 1e3 / reps as f64
    };
    p("cost::build", ms(&mut || { std::hint::black_box(build(&THETA_STAR)); }));
    p("cost::capture", ms(&mut || { std::hint::black_box(capture_plan(&brep, &tess()).unwrap()); }));
    let s = seeding_for(&brep, 3);
    p("cost::seeding", ms(&mut || { std::hint::black_box(seeding_for(&brep, 3)); }));
    p("cost::seam", ms(&mut || { std::hint::black_box(evaluate_with_sensitivity(&brep, &plan, &s).unwrap()); }));
    let seam = evaluate_with_sensitivity(&brep, &plan, &s).unwrap();
    p("cost::dual_qoi", ms(&mut || { std::hint::black_box(fwd(&seam)); }));
    let (_, w) = rev.value_and_mesh_gradient(&seam);
    p("cost::pullback", ms(&mut || { std::hint::black_box(evaluate_with_pullback(&brep, &plan, &w).unwrap()); }));
    let reps2 = 5;
    let t0 = Instant::now();
    for _ in 0..reps2 {
        for k in 0..5 {
            let (mut a, mut b) = (THETA_STAR, THETA_STAR);
            a[k] += 1e-4;
            b[k] -= 1e-4;
            std::hint::black_box((fresh_q(&a), fresh_q(&b)));
        }
    }
    p("cost::fd_gradient", t0.elapsed().as_secs_f64() * 1e3 / reps2 as f64);
    let t0 = Instant::now();
    for _ in 0..reps2 {
        std::hint::black_box(objective_gradient_reverse(&build, &seeding_for, &rev, &THETA_STAR, &tess()).unwrap());
    }
    p("cost::seam_gradient", t0.elapsed().as_secs_f64() * 1e3 / reps2 as f64);
    let t0 = Instant::now();
    for _ in 0..reps2 {
        std::hint::black_box(synthesize_all(&build, &THETA_STAR, 1e-6).unwrap());
    }
    p("cost::synthesize_all", t0.elapsed().as_secs_f64() * 1e3 / reps2 as f64);
    // flywheel: where its per-iterate time goes
    let th = [8.0, 5.0];
    let t0 = Instant::now();
    let fb = fly::build(&th);
    p("cost::fly::build", t0.elapsed().as_secs_f64() * 1e3);
    let t0 = Instant::now();
    let fp = capture_plan(&fb, &fly::tess()).unwrap();
    p("cost::fly::capture", t0.elapsed().as_secs_f64() * 1e3);
    p("cost::fly::nodes", fp.nodes.len() as f64);
}

#[test]
fn paper_plan_validity_radius() {
    let brep = build(&THETA_STAR);
    let plan = capture_plan(&brep, &tess()).unwrap();
    let ladder: Vec<f64> = (0..=26).map(|i| 1e-6 * 10f64.powf(i as f64 / 4.0)).collect();
    for k in 0..5 {
        let mut last = 0.0;
        let mut why = String::from("none");
        for h in &ladder {
            let mut ok = true;
            for s in [1.0, -1.0] {
                let mut x = THETA_STAR;
                x[k] += s * h;
                if let Err(e) = evaluate_plan(&build(&x), &plan) {
                    ok = false;
                    why = format!("{e:?}").split(|c: char| !c.is_alphanumeric()).next().unwrap_or("").to_string();
                }
            }
            if !ok {
                break;
            }
            last = *h;
        }
        p(&format!("radius::{k}::h"), last);
        eprintln!("PAPER\tradius::{k}::why\t{why}");
    }
}

#[test]
fn paper_sag_adaptive_jumps() {
    let mut x = THETA_STAR;
    let (mut changes, mut prev_n, mut prev_v, mut prev_d, mut max_jump) = (0, 0usize, 0.0f64, 0.0f64, 0.0f64);
    let (lo, hi, nn) = (1.6, 2.4, 800);
    for i in 0..=nn {
        x[4] = lo + (hi - lo) * i as f64 / nn as f64;
        let Some((q, n)) = fresh_q(&x) else { continue };
        eprintln!("PAPER\tsag::{i}\t{:e}\t{}\t{:e}", x[4], n, q[0]);
        if i > 1 && n != prev_n {
            changes += 1;
            max_jump = max_jump.max(((q[0] - prev_v) - prev_d).abs());
        }
        if i > 0 {
            prev_d = q[0] - prev_v;
        }
        prev_n = n;
        prev_v = q[0];
    }
    p("sag::changes", changes as f64);
    p("sag::max_jump_rel", max_jump / prev_v);
}

#[test]
fn paper_second_derivative_step_sweep() {
    let torus = |r: f64| make_torus(8.0, r, 24);
    let cube = |r: f64| vcad_kernel_fillet::fillet_all_edges(&make_cube(10.0, 10.0, 10.0), r);
    for e in [-5, -4, -3, -2, -1] {
        let h = 10f64.powi(e);
        for (name, f, th, t) in [
            ("torus", &torus as &dyn Fn(f64) -> BRepSolid, 3.0, tess_n(24, 2)),
            ("fillet", &cube as &dyn Fn(f64) -> BRepSolid, 1.5, tess_n(16, 2)),
        ] {
            if let (Some((_, a, _)), Some((_, b, _))) = (seam_dv(f, th + h, &t), seam_dv(f, th - h, &t)) {
                p(&format!("second::{name}::{e}"), (a - b) / (2.0 * h));
            }
        }
    }
}

mod fly {
    use super::*;
    pub const DISC_R: f64 = 40.0;
    pub const BOLT_R: f64 = 25.0;
    pub fn build(theta: &[f64]) -> BRepSolid {
        let disc = Solid::cylinder(DISC_R, 10.0, 24);
        let mut part = disc.difference(&Solid::cylinder(theta[0], 12.0, 24).translate(0.0, 0.0, -1.0));
        for k in 0..4 {
            let a = std::f64::consts::FRAC_PI_2 * k as f64;
            part = part.difference(&Solid::cylinder(theta[1], 12.0, 24).translate(BOLT_R * a.cos(), BOLT_R * a.sin(), -1.0));
        }
        part.as_brep().unwrap().clone()
    }
    pub fn tess() -> TessellationParams {
        TessellationParams { circle_segments: 24, height_segments: 2, ..Default::default() }
    }
    pub fn seeding(brep: &BRepSolid, k: usize) -> ParamSeeding {
        let mut s = ParamSeeding::new();
        s.seed_where(&brep.geometry, |x| {
            x.as_any().downcast_ref::<CylinderSurface>().map(|c| {
                let d = (c.center.x * c.center.x + c.center.y * c.center.y).sqrt();
                if k == 0 { d < 1e-9 && c.radius < DISC_R - 1e-9 } else { (d - BOLT_R).abs() < 1e-9 }
            }).unwrap_or(false)
        }, SurfaceSeed::CylinderRadius { rate: 1.0 });
        s
    }
}

#[test]
fn paper_flywheel_lbfgs() {
    use vcad_kernel_diff::mass_properties;
    let eval = |x: &[f64]| -> Option<(f64, f64, usize)> {
        let b = fly::build(x);
        let plan = capture_plan(&b, &fly::tess()).ok()?;
        let m = evaluate_plan(&b, &plan).ok()?;
        let q = mass_properties(&m.positions, &m.triangles, RHO);
        Some((q.mass, q.inertia_centroid[2][2], plan.nodes.len()))
    };
    let (_, target, _) = eval(&[8.0, 5.0]).unwrap();
    let (m_ref, _, _) = eval(&[3.0, 2.5]).unwrap();
    let lambda = 100.0;
    let j = |x: &[f64]| eval(x).map(|(m, i, n)| {
        let miss = (i - target) / target;
        (m / m_ref + lambda * miss * miss, n)
    });
    let obj = move |seam: &SeamMesh| -> (f64, f64) {
        let (q, d) = mass_properties_with_derivative(seam, RHO);
        let miss = (q.inertia_centroid[2][2] - target) / target;
        (q.mass / m_ref + lambda * miss * miss, d.mass / m_ref + lambda * 2.0 * miss * d.inertia_centroid[2][2] / target)
    };
    let g = |x: &[f64]| objective_gradient(&fly::build, &fly::seeding, &obj, x, &fly::tess()).ok().map(|r| r.1);
    let h = lbfgs_driver(&[3.0, 2.5], &[(2.0, 12.0), (2.0, 8.0)], 60, 1e-4, &j, &g, &|_| 0.0);
    report("fly_lbfgs", &h);
    // the path, for the figure: re-run printing θ
    let path = std::cell::RefCell::new(Vec::<Vec<f64>>::new());
    let g2 = |x: &[f64]| { path.borrow_mut().push(x.to_vec()); g(x) };
    let _ = lbfgs_driver(&[3.0, 2.5], &[(2.0, 12.0), (2.0, 8.0)], 60, 1e-4, &j, &g2, &|_| 0.0);
    for (i, x) in path.borrow().iter().enumerate() {
        eprintln!("PAPER\tfly::path::{i}\t{:e}\t{:e}", x[0], x[1]);
    }
    let last = path.borrow().last().unwrap().clone();
    let (m, inertia, _) = eval(&last).unwrap();
    p("fly::mass_ratio_final", m / eval(&[8.0, 5.0]).unwrap().0);
    p("fly::inertia_miss", (inertia - target).abs() / target);
}
