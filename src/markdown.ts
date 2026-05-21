import { escapeAttr, escapeHtml, highlightJson } from "./ui";

export interface MarkdownHeading {
  id: string;
  level: number;
  text: string;
}

export interface MarkdownResult {
  html: string;
  headings: MarkdownHeading[];
}

interface MarkdownOptions {
  copyButtons?: boolean;
  headingIds?: boolean;
}

export function renderMarkdown(markdown: string, options: MarkdownOptions = {}): MarkdownResult {
  const lines = markdown.replace(/\r\n/g, "\n").split("\n");
  const html: string[] = [];
  const headings: MarkdownHeading[] = [];
  let paragraph: string[] = [];
  let list: string[] = [];
  let listType: "ul" | "ol" | null = null;
  let codeLang = "";
  let codeLines: string[] | null = null;

  const flushParagraph = () => {
    if (!paragraph.length) return;
    html.push(`<p>${renderInline(paragraph.join(" "))}</p>`);
    paragraph = [];
  };

  const flushList = () => {
    if (!list.length || !listType) return;
    html.push(`<${listType}>${list.map((item) => `<li>${renderInline(item)}</li>`).join("")}</${listType}>`);
    list = [];
    listType = null;
  };

  const flushCode = () => {
    if (!codeLines) return;
    const code = codeLines.join("\n");
    const highlighted = highlightCode(code, codeLang);
    const copy = options.copyButtons
      ? `<button class="code-copy" type="button" data-copy="${escapeAttr(code)}">Copy</button>`
      : "";
    html.push(
      `<figure class="md-code" data-lang="${escapeAttr(codeLang || "text")}">` +
        `<figcaption><span>${escapeHtml(codeLang || "text")}</span>${copy}</figcaption>` +
        `<pre><code>${highlighted}</code></pre>` +
      `</figure>`
    );
    codeLines = null;
    codeLang = "";
  };

  for (const line of lines) {
    const fence = /^```(\S*)\s*$/.exec(line);
    if (fence) {
      if (codeLines) flushCode();
      else {
        flushParagraph();
        flushList();
        codeLang = fence[1] || "text";
        codeLines = [];
      }
      continue;
    }

    if (codeLines) {
      codeLines.push(line);
      continue;
    }

    const heading = /^(#{1,3})\s+(.+)$/.exec(line);
    if (heading) {
      flushParagraph();
      flushList();
      const level = heading[1].length;
      const text = stripInline(heading[2]);
      const id = slugify(text);
      headings.push({ id, level, text });
      const idAttr = options.headingIds !== false ? ` id="${escapeAttr(id)}"` : "";
      html.push(`<h${level}${idAttr}>${renderInline(heading[2])}</h${level}>`);
      continue;
    }

    const unordered = /^\s*[-*]\s+(.+)$/.exec(line);
    const ordered = /^\s*\d+\.\s+(.+)$/.exec(line);
    if (unordered || ordered) {
      flushParagraph();
      const nextType = unordered ? "ul" : "ol";
      if (listType && listType !== nextType) flushList();
      listType = nextType;
      list.push((unordered || ordered)?.[1] || "");
      continue;
    }

    if (!line.trim()) {
      flushParagraph();
      flushList();
      continue;
    }

    paragraph.push(line.trim());
  }

  flushCode();
  flushParagraph();
  flushList();
  return { html: html.join("\n"), headings };
}

function renderInline(value: string): string {
  let text = escapeHtml(value);
  text = text.replace(/`([^`]+)`/g, "<code>$1</code>");
  text = text.replace(/\*\*([^*]+)\*\*/g, "<strong>$1</strong>");
  text = text.replace(
    /\[([^\]]+)\]\((https?:\/\/[^)\s]+)\)/g,
    (_match, label: string, href: string) =>
      `<a href="${escapeAttr(href)}" target="_blank" rel="noreferrer">${label}</a>`
  );
  return text;
}

function stripInline(value: string): string {
  return value.replace(/`([^`]+)`/g, "$1").replace(/\*\*([^*]+)\*\*/g, "$1").replace(/\[([^\]]+)\]\([^)]+\)/g, "$1");
}

function slugify(value: string): string {
  return value
    .toLowerCase()
    .replace(/[^a-z0-9]+/g, "-")
    .replace(/^-+|-+$/g, "") || "section";
}

function highlightCode(code: string, lang: string): string {
  const normalized = lang.toLowerCase();
  if (normalized === "json") return highlightJson(code);
  if (["js", "jsx", "ts", "tsx", "typescript", "javascript"].includes(normalized)) return highlightTs(code);
  if (["bash", "sh", "shell"].includes(normalized)) return highlightShell(code);
  if (normalized === "http") return highlightHttp(code);
  return escapeHtml(code);
}

function highlightTs(code: string): string {
  return escapeHtml(code)
    .replace(/(&quot;[^&]*?&quot;|'[^']*')/g, '<span class="tok-str">$1</span>')
    .replace(/\b(import|from|const|let|var|await|async|for|of|return|new|process|console)\b/g, '<span class="tok-kw">$1</span>')
    .replace(/\b(true|false|null|undefined)\b/g, '<span class="tok-bool">$1</span>');
}

function highlightShell(code: string): string {
  return escapeHtml(code)
    .replace(/^(\s*)(curl|npm|npx|pnpm|yarn|export)\b/gm, '$1<span class="tok-kw">$2</span>')
    .replace(/(&quot;[^&]*?&quot;|'[^']*')/g, '<span class="tok-str">$1</span>');
}

function highlightHttp(code: string): string {
  return escapeHtml(code).replace(/^([A-Za-z-]+):/gm, '<span class="j-key">$1</span><span class="j-punc">:</span>');
}
