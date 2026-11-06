= Architecture
// Fig. 1: the lifeform diagram (genome, epigenome, body, brainstem, development, life, sleep, offspring).

== One typed bus
Every inter-organ message type is defined once and carried on latched streams
(`ipse-pons`). The motor door stays a socket because a lease *is* the connection:
when the holder dies, the kernel closes it and the grant ends.
// Status: merged (#753, #756, #774, #779, #789).

== Organs are pure steps
`(state, timestamped inputs) -> (outputs, state)`; no clock, file or socket inside.
One runtime drives organs from sockets (live) or tape (deterministic).
Eight organs: vestibular, memory, hippocampus map, cortex, occipital, cerebellum,
amygdala, medulla door. // Status: merged (#760–#792).

== The body is one interface
`describe`, `step(cmd) -> state`, `truth`; implementations for a point body, tape,
phyz K1/G1 and the real K1. The stack test runs the whole brain on K1 and G1 (20/20).
// Status: merged (#761, #793); real K1 body in progress.

== Genome, epigenome, brainstem
*Genome:* frozen reflex networks, innate drives (pain, hunger, fear of falling), body plan.
*Epigenome:* shipped organ networks, rewritten by sleep, inherited by new robots.
*Brainstem:* the tiny innate core (medulla) that keeps the body alive; learned
organs may ask, never override. A power cut and deadman stay small and verifiable.
