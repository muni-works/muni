// The vcad cover's numbers: the torus gates of paper/vcad (make_torus(8, 3), 24 segments,
// vcad d10f279), copied from paper/vcad/data/measured.tsv. Volumes in mm³, radii in mm.
export const VCAD_TORUS = {
  R: 8,
  r: 3,
  // m7_cone_torus::torus_gate
  dVdr: 926.0324090208981,
  dVdrFdRel: 4.509028033275415e-10,
  dVdR: 173.6310766953672,
  dVdRFdRel: 3.169971469552118e-9,
  // m10_second_order::m10_torus_minor_radius_second_derivative
  d2Vdr2: 308.67746966661355,
  d2Vdr2FdRel: 1.6996657900804495e-6,
} as const;
