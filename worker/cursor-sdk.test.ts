import { describe, expect, it } from "vitest";
import { cursorSdkTestExports } from "./cursor-sdk";

describe("Cursor SDK harness", () => {
  it("does not emit incomplete SDK tool-call starts to OpenCode", () => {
    expect(cursorSdkTestExports.isEmittableSdkToolCall({ name: "edit", arguments: {} })).toBe(false);
    expect(cursorSdkTestExports.isEmittableSdkToolCall({ name: "write", arguments: { path: "package.json" } })).toBe(false);
    expect(cursorSdkTestExports.isEmittableSdkToolCall({ name: "shell", arguments: {} })).toBe(false);
  });

  it("allows SDK tool calls once required execution arguments are available", () => {
    expect(cursorSdkTestExports.isEmittableSdkToolCall({ name: "glob", arguments: {} })).toBe(true);
    expect(cursorSdkTestExports.isEmittableSdkToolCall({ name: "write", arguments: { path: "package.json", fileText: "{}" } })).toBe(true);
    expect(cursorSdkTestExports.isEmittableSdkToolCall({ name: "shell", arguments: { command: "npm test" } })).toBe(true);
  });

  it("converts completed SDK streaming edits into OpenCode writes", () => {
    expect(
      cursorSdkTestExports.normalizeSdkToolCallForOpenCode({
        name: "edit",
        arguments: { path: "scripts/verify.mjs", streamContent: "console.log('ok')\n" }
      })
    ).toEqual({
      name: "write",
      arguments: { path: "scripts/verify.mjs", fileText: "console.log('ok')\n" }
    });
    expect(cursorSdkTestExports.isEmittableSdkToolCall({ name: "edit", arguments: { path: "scripts/verify.mjs", streamContent: "x" } })).toBe(
      true
    );
  });
});
