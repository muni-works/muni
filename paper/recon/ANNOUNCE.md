Draft announcement for "Seeing Is Measuring" (muni.works/research/seeing-is-measuring). Not posted.

---

Part 3000 came back with every dimension at ±0.1 mm. The plate was 2.15 mm short and its hole was missing.

That's the problem with reading CAD from photos. The fit tells you how sure it is, and it's sure about the wrong part too.

So we measured it. We recover editable CAD programs - a plate, its holes, counterbores, slots, bosses - from photographs, through irys. Then we asked whether anything the fit reports can tell a right answer from a wrong one.

The error bars can't. 17 of the 37 parts with every bar under 1 mm were wrong. Residual checks can't either - they caught 4 of 37 wrong answers on held-out parts. Most wrong answers explain the photos they were fitted to.

What works: recover the part again with one more photo, and flag it if the features change. That caught 30 of 40 wrong answers, with 2 false alarms in 23 right ones. Choosing which photo to take didn't beat a random one.

So vcad will take three photos, recover from two and from all three, and only call a part trusted when they agree.

Every photo in the paper is synthetic, and there's a confound we haven't ruled out yet - it's all in the paper.

Paper: muni.works/research/seeing-is-measuring

Let me know what you think.
