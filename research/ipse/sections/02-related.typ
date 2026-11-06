= Related Work
*Modular versus end-to-end.* Driving moved from rule pipelines to large networks
@e2e_era_2026; UniAD kept modules but trained them jointly @uniad. IPSE keeps
typed modules as the interface while their insides become learned.

*Fast/slow humanoid systems.* GR00T N1 @gr00t_n1 pairs a slow vision-language model
with a fast motor policy; UniFS @unifs trains a fast-to-slow hierarchy jointly;
NeuroVLA @neurovla adds a reflex layer. Brain-morphic orchestration appears in
FrankenBot @frankenbot and Agentic Robot @agentic_robot, around hand-built modules.

*Predictive coding and active inference.* Prediction error as the cortical signal
@rao_ballard; own-motion prediction now saves robot video bandwidth @khc_2026.
We found no robot that uses prediction error as a shared signal across modules.

*Neuromodulation in robots.* Sparse since a neuromodulated patience model for
navigation @patience_2019 and learned plasticity @spikepropamine. No 2025–2026
humanoid work surfaced in our survey.

*Safety around learned controllers.* Barrier-certified cages for legged navigation
@caging_vln. IPSE instead makes safety anatomy: an innate brainstem and frozen
reflexes (§3).

*World models.* LeCun's modular blueprint @lecun_ami maps closely onto IPSE's organs;
JEPA-style predictors are candidates for learned organs.
