import { readFileSync } from "node:fs";
import { join } from "node:path";
import postsJson from "../../posts.json";

export interface Post {
  slug: string;
  title: string;
  subtitle: string;
  date: string;
  author: string;
  description: string;
  /** cover art id (see components/blog/covers); absent = the solar system */
  cover?: string;
}

export const posts: Post[] = [...postsJson].sort((a, b) => b.date.localeCompare(a.date));

export function getPost(slug: string): Post | undefined {
  return posts.find((p) => p.slug === slug);
}

/** The post body, compiled from Typst by `npm run posts`. Read at build time. */
export function getPostHtml(slug: string): string {
  return tagWide(readFileSync(join(process.cwd(), "src/content/posts", `${slug}.html`), "utf8"));
}

/** Marks what may be wider than a phone, for post.css to pan rather than shrink or overflow:
 *  drawn figures (an svg with labels, not a lone photo) get `pan` and their drawn width as
 *  --pan-w, and display equations (a paragraph holding only a math svg) get `display-math`. */
function tagWide(html: string): string {
  return html
    .replace(/<figure([^>]*)>([\s\S]*?)<\/figure>/g, (fig, attrs: string, body: string) => {
      const svg = body.match(/^\s*(?:<figcaption[\s\S]*?<\/figcaption>\s*)?<svg[^>]*style="[^"]*width: ([\d.]+)em/);
      // under ~28em (≈400px) it fits a phone well enough already
      if (!svg || parseFloat(svg[1]) < 28 || (body.match(/typst-text/g)?.length ?? 0) <= 2) return fig;
      const cls = attrs.match(/class="([^"]*)"/);
      const tagged = cls ? attrs.replace(cls[0], `class="${cls[1]} pan"`) : `${attrs} class="pan"`;
      return `<figure${tagged} style="--pan-w: ${svg[1]}em">${body}</figure>`;
    })
    .replace(/<p>(\s*<span class="math">(?:(?!<\/span>)[\s\S])*<\/svg><\/span>\s*)<\/p>/g, '<p class="display-math">$1</p>');
}

export function formatDate(date: string): string {
  return new Date(`${date}T12:00:00Z`).toLocaleDateString("en-US", { year: "numeric", month: "long", day: "numeric" });
}
