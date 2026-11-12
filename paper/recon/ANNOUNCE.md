Draft announcement for "Seeing Is Measuring" (muni.works/research/seeing-is-measuring). Not posted.

---

We built image-to-CAD.

You take three photos of a part next to a printed tag, and you get back an editable CAD program. It has the plate and every hole, counterbore, slot and boss, each with dimensions you can change. It's a program, not a mesh.

Part 4035 is two bosses on a plate. We recovered it to within 0.13 mm on every dimension.

It runs on irys, our differentiable renderer. irys renders each candidate program, fits it to the pixels, and scores it by how short a description of the photos it gives. A feature goes in only if it shortens that description.

Knowing when the answer is wrong was harder. The fit can return a wrong part with ±0.1 mm error bars. We measured how well those error bars separate right answers from wrong ones, and they scored 0.58 where chance is 0.5. So we built a check that works. We recover the part again with one more photo, and if the features change, we flag it. That caught 30 of 40 wrong answers, with 2 false alarms in 23 right ones.

This is coming to vcad. You'll take three photos, get a part you can edit, and see whether to trust it.

So far every photo is synthetic. Next we print parts and check them with calipers.

Paper: muni.works/research/seeing-is-measuring
