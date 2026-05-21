import { describe, expect, it } from "vitest";
import { renderMarkdown } from "./markdown";

describe("markdown renderer", () => {
  it("renders headings and code fences with escaped highlighted code", () => {
    const result = renderMarkdown("## Install\n\n```ts\nconst value = \"ok\";\n```", { copyButtons: true });

    expect(result.headings).toEqual([{ id: "install", level: 2, text: "Install" }]);
    expect(result.html).toContain('id="install"');
    expect(result.html).toContain('class="md-code"');
    expect(result.html).toContain('data-copy="const value = &quot;ok&quot;;"');
    expect(result.html).toContain('<span class="tok-kw">const</span>');
  });

  it("escapes HTML in assistant-controlled markdown", () => {
    const result = renderMarkdown("Hello <script>alert(1)</script>");
    expect(result.html).toContain("&lt;script&gt;");
    expect(result.html).not.toContain("<script>");
  });
});
