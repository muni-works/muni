= Architecture
// §3 uses the four pillars as headings (IPSE.md §6a). Fig. 1: lifeform diagram.

== The scaffold
Organs today are hand-written: vestibular, memory, hippocampus map, cortex,
occipital, cerebellum, amygdala, medulla door. Each is a pure step,
`(state, timestamped inputs) -> (outputs, state)`, on a typed latched bus, behind
one body interface (K1, G1, tape, sim). This is scaffolding: it lets the robot live
and record its life before anything is learned, and every organ's recorded inputs
and outputs are the training set for the network that replaces it.
// Status: merged (#753–#794); stack test 20/20 on K1 and G1; not yet run on the robot.

== Interoception
Battery, joint temperature, motor current and IMU are first-class observations.
Drives are predictions about preferred interoceptive states; there is no drive module.

== Timescales
A multi-timescale world model (MTRSSM): a fast latent for sensorimotor dynamics,
a slow latent for situation and state of being. The slow latent keys episodic memory.

== Workspace
The slow latent doubles as a capacity-limited broadcast bottleneck @goyal_gw.
A local language model is inner speech, recruited by the workspace — a faculty,
not the planner.

== Selfhood
Not specified. Measured (E0) as the behavior-invariant representation that persists
while skills are acquired.

== Genome, epigenome, brainstem
*Genome:* frozen reflexes, priors over preferred interoceptive states
(temperament), body plan. *Epigenome:* learned networks, rewritten by sleep,
inheritable. *Brainstem:* the tiny innate core (medulla, deadman, hardware e-stop)
that keeps the body alive; learned organs may ask, never override.
