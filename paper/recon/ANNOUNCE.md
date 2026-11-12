Draft announcement for "Seeing Is Measuring" (muni.works/research/seeing-is-measuring). Not posted.

---

We built image-to-CAD.

Three photos of a part next to a printed tag go in. An editable CAD program comes out - the plate, every hole, counterbore, slot and boss, with real dimensions you can change. Not a mesh. A program.

Part 4035: two bosses on a plate, recovered to 0.13 mm on every dimension.

It runs on irys, our differentiable renderer. Every candidate program gets rendered, fitted to the pixels, and scored by how short a description of the photos it gives. A feature only goes in if it pays for itself.

Then the hard part: knowing when it's wrong. A fit will happily hand you a wrong part with ±0.1 mm error bars - we measured it, and the error bars barely beat a coin flip. So we built a check that works: recover again with one more photo, and if the features change, flag it. It catches 30 of 40 wrong answers, with 2 false alarms in 23 right ones.

That's coming to vcad. Snap three photos, get a part you can edit, and know whether to trust it.

All of this is on synthetic photos so far. Printed parts and calipers are next.

Paper: muni.works/research/seeing-is-measuring
