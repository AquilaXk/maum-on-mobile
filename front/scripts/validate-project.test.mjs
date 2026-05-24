import test from "node:test";
import assert from "node:assert/strict";
import { validateProject } from "./validate-project.mjs";

test("mobile project contract is valid", () => {
  assert.doesNotThrow(() => validateProject());
});
