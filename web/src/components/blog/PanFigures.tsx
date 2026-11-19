"use client";

import { usePathname } from "next/navigation";
import { useEffect } from "react";

// Some Typst drawings run past their own frame (a card or label set wider than the figure).
// On a wide screen that spills into the margin; in a phone's panning figure the scroller would
// clip it. Measure each panning drawing once and pass its overhang to post.css as --pan-bleed,
// a fraction of the drawn width. A panning drawing with blank space on its left opens scrolled to its content.
export function PanFigures() {
  const path = usePathname(); // a client-side move to another post swaps the body: measure again
  useEffect(() => {
    document.querySelectorAll<SVGSVGElement>(".post figure.pan > svg").forEach((svg) => {
      const frame = svg.viewBox.baseVal.width;
      if (!frame) return;
      const box = svg.getBBox();
      const bleed = Math.max(0, -box.x, box.x + box.width - frame) / frame;
      if (bleed > 0.005) (svg.parentElement as HTMLElement).style.setProperty("--pan-bleed", bleed.toFixed(3));
      // a drawing that pans opens on its content, not on blank margin
      const fig = svg.parentElement as HTMLElement;
      if (fig.scrollWidth > fig.clientWidth + 1) {
        // blank frame left of the drawing, from its visible marks (glyph <defs> sit at the origin)
        const { left, width } = svg.getBoundingClientRect();
        const marks = [...svg.querySelectorAll("path, use, image, rect")].filter((m) => !m.closest("defs"));
        const lead = Math.min(...marks.map((m) => m.getBoundingClientRect()).filter((r) => (r.width || r.height) && r.width < width * 0.9) /* not a backdrop */.map((r) => r.left)) - left;
        if (lead > 24) fig.scrollLeft = lead - 8;
      }
    });
  }, [path]);
  return null;
}
