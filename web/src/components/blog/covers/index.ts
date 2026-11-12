import type { ComponentType } from "react";
import { Deciding } from "./Deciding";
import { Pavilion } from "./Pavilion";
import { FlashTiles } from "./FlashTiles";
import { PinnedRows } from "./PinnedRows";
import { PlasmaTorus } from "./PlasmaTorus";
import { Ridgelines } from "./Ridgelines";
import { SolarSystem } from "./SolarSystem";

// Cover art per post, chosen by `cover` in posts.json. The rail's two end labels
// travel with the art so the scrollbar reads in the cover's own terms.
export interface Cover {
  Art: ComponentType<{ og?: boolean }>;
  rail: { top: string; bottom: string; variant: string };
  /** Extra class on the title block, for art that needs the text off centre. */
  textClass?: string;
}

export const COVERS: Record<string, Cover> = {
  "solar-system": { Art: SolarSystem, rail: { top: "Earth", bottom: "Sun", variant: "orbit" } },
  ridgelines: { Art: Ridgelines, rail: { top: "Text", bottom: "Audio", variant: "voice" } },
  "plasma-torus": { Art: PlasmaTorus, rail: { top: "r", bottom: "R", variant: "seam" } },
  pavilion: { Art: Pavilion, rail: { top: "Pixels", bottom: "Parameters", variant: "orbit" }, textClass: "is-left" },
  "flash-tiles": { Art: FlashTiles, rail: { top: "Query", bottom: "Key", variant: "flash" } },
  deciding: { Art: Deciding, rail: { top: "a = 0.5", bottom: "a = 1", variant: "gate" }, textClass: "is-left" },
  "pinned-rows": { Art: PinnedRows, rail: { top: "g = 0.9", bottom: "g = 1", variant: "gate" } },
};

export function coverFor(id?: string): Cover {
  return (id && COVERS[id]) || COVERS["solar-system"];
}
