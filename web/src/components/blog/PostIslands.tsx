"use client";

import { useEffect, useState, type ReactNode } from "react";
import { createPortal } from "react-dom";
import { DeriveLab } from "./DeriveLab";

// Interactive pieces inside a Typst-built post. The source leaves an empty element with a
// known id (web build only); this mounts the matching component into it after hydration.
const ISLANDS: Record<string, () => ReactNode> = {
  "derive-lab": () => <DeriveLab />,
};

export function PostIslands() {
  const [hosts, setHosts] = useState<[string, Element][]>([]);
  useEffect(() => {
    setHosts(
      Object.keys(ISLANDS)
        .map((id) => [id, document.getElementById(id)] as [string, Element | null])
        .filter((h): h is [string, Element] => h[1] !== null),
    );
  }, []);
  return <>{hosts.map(([id, el]) => createPortal(ISLANDS[id](), el, id))}</>;
}
