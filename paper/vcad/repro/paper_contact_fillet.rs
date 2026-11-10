// Shape through contact where θ moves many surfaces: a filleted box resting on one blended edge.
// θ = fillet radius, which moves 12 blend cylinders and 8 corner spheres. Copied by repro.sh into
// crates/vcad-kernel-physics/tests/.
use phyz::math::{DVec, Mat3, SpatialTransform, Vec3};
use phyz::{Joint, JointType, Model, ModelBuilder};
use vcad_kernel::vcad_kernel_fillet::fillet_all_edges;
use vcad_kernel_diff::{ParamSeeding, SurfaceSeed};
use vcad_kernel_geom::{CylinderSurface, SphereSurface};
use vcad_kernel_math::Vec3 as KVec3;
use vcad_kernel_physics::diff::interop::AdjointRolloutSpec;
use vcad_kernel_physics::{contact_rollout_gradient, BodyMassProps, ContactConfig, DiffBody};
use vcad_kernel_primitives::{make_cube, BRepSolid};
use vcad_kernel_tessellate::TessellationParams;

const S: f64 = 20.0;
const R0: f64 = 2.0;
const DENSITY: f64 = 2700.0;
const DT: f64 = 1e-3;
const STEPS: usize = 800;

fn tess() -> TessellationParams {
    TessellationParams { circle_segments: 16, height_segments: 2, ..Default::default() }
}

fn body<'a>() -> DiffBody<'a> {
    DiffBody {
        build: Box::new(|t: &[f64]| fillet_all_edges(&make_cube(S, S, S), t[0])),
        seeding_for: Box::new(|brep: &BRepSolid, t: &[f64], _k: usize| {
            let r = t[0];
            let comp = |c: f64| if (c - r).abs() < 1e-6 { 1.0 } else if (c - (S - r)).abs() < 1e-6 { -1.0 } else { 0.0 };
            let mut s = ParamSeeding::new();
            for (i, x) in brep.geometry.surfaces.iter().enumerate() {
                if let Some(c) = x.as_any().downcast_ref::<CylinderSurface>() {
                    s.seed(i, SurfaceSeed::CylinderRadius { rate: 1.0 });
                    s.seed(i, SurfaceSeed::Translate { velocity: KVec3::new(comp(c.center.x), comp(c.center.y), comp(c.center.z)) });
                } else if let Some(c) = x.as_any().downcast_ref::<SphereSurface>() {
                    s.seed(i, SurfaceSeed::SphereRadius { rate: 1.0 });
                    s.seed(i, SurfaceSeed::Translate { velocity: KVec3::new(comp(c.center.x), comp(c.center.y), comp(c.center.z)) });
                }
            }
            Ok(s)
        }),
        density_kg_m3: DENSITY,
        tess: tess(),
    }
}

fn model(props: &[BodyMassProps]) -> Model {
    let s = std::f64::consts::FRAC_1_SQRT_2;
    // world +z in the body frame is (0, s, s): the edge y = z = 0 points straight down
    let e = Mat3::new(1.0, 0.0, 0.0, 0.0, s, s, 0.0, -s, s);
    let joint = Joint {
        joint_type: JointType::Prismatic,
        parent_to_joint: SpatialTransform::new(e, Vec3::zeros()),
        axis: Vec3::new(0.0, s, s),
        damping: 0.0,
        limits: None,
        ..Default::default()
    };
    ModelBuilder::new().gravity(Vec3::new(0.0, 0.0, -9.81)).dt(DT).add_body("box", -1, joint, props[0].to_spatial_inertia()).build()
}

fn spec<'a>() -> AdjointRolloutSpec<'a> {
    AdjointRolloutSpec {
        build_model: Box::new(|p: &[BodyMassProps]| model(p)),
        q0: vec![0.0],
        v0: vec![0.0],
        steps: STEPS,
        ctrl: Box::new(|_t| DVec::from_slice(&[0.0])),
        objective_value: Box::new(|q, _v| q[0]),
        objective_gradient: Box::new(|q, v| {
            let mut g = vec![0.0; q.len()];
            g[0] = 1.0;
            (g, vec![0.0; v.len()])
        }),
    }
}

fn contact() -> ContactConfig {
    // the blend's lowest point sits at height r(√2 − 1) along world z at q = 0
    ContactConfig { ground_height_m: R0 * (2f64.sqrt() - 1.0) * 1e-3, stiffness: 100.0, damping: 0.5 }
}

#[test]
fn paper_contact_filleted_box() {
    let bodies = [body()];
    let (j, g) = contact_rollout_gradient(&bodies, &spec(), &contact(), &[0], &[R0]).expect("gradient");
    eprintln!("PAPER\tcbox::J\t{j:e}");
    eprintln!("PAPER\tcbox::grad\t{:e}", g[0]);
    eprintln!("PAPER\tcbox::surface_only\t{:e}", -(2f64.sqrt() - 1.0) * 1e-3);
    let at = |r: f64| {
        let b = [body()];
        contact_rollout_gradient(&b, &spec(), &contact(), &[0], &[r]).expect("probe").0
    };
    for e in [-4, -3, -2] {
        let h = 10f64.powi(e);
        eprintln!("PAPER\tcbox::fd::{e}\t{:e}", (at(R0 + h) - at(R0 - h)) / (2.0 * h));
    }
}
