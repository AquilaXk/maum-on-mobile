import assert from "node:assert/strict";
import test from "node:test";
import {
  findForbiddenBranchName,
  findForbiddenCommitMessages,
  findForbiddenTextPatterns,
  findForbiddenTrackedFiles,
  findIntakeViolations,
  findMissingRequiredTrackedFiles,
  runRepoHygieneCheck,
} from "./check-repo-hygiene.mjs";

const decode = (b64) => Buffer.from(b64, "base64").toString("utf8");

test("required governance files pass when complete and fail when missing", () => {
  const complete = [
    "README.md",
    "CONTRIBUTING.md",
    "SECURITY.md",
    "THIRD_PARTY_NOTICES.md",
    "TODO.md",
    ".github/ISSUE_TEMPLATE/config.yml",
    ".github/ISSUE_TEMPLATE/bug_report.yml",
    ".github/release.yml",
    ".github/workflows/ci.yml",
  ];
  assert.deepEqual(findMissingRequiredTrackedFiles(complete), []);
  assert.equal(findMissingRequiredTrackedFiles(["README.md"]).length, 8);
});

test("external intake rules allow only bug_report.yml and config.yml", () => {
  assert.deepEqual(
    findIntakeViolations([".github/ISSUE_TEMPLATE/config.yml", ".github/ISSUE_TEMPLATE/bug_report.yml"]),
    []
  );
  assert.equal(findIntakeViolations([".github/ISSUE_TEMPLATE/feature_request.yml"]).length, 1);
  assert.equal(findIntakeViolations([".github/pull_request_template.md"]).length, 1);
  assert.equal(findIntakeViolations([".github/dependabot.yml"]).length, 1);
});

test("forbidden tracked file, content, commit, and branch guards reject agent artifacts", () => {
  const forbiddenFile = decode("QUdFTlRTLm1k");
  const forbiddenDir = decode("LmNsYXVkZS8=") + "settings.json";
  const forbiddenBot = decode("LmNvZGVyYWJiaXQueWFtbA==");
  const trailer = `${decode("Q28tQXV0aG9yZWQtQnk6")} Bot <bot@example.com>`;

  assert.equal(findForbiddenTrackedFiles([forbiddenFile, forbiddenDir, forbiddenBot, ".env"]).length, 4);
  assert.equal(findForbiddenTextPatterns("sample.md", `Header ${decode("QW50aWdyYXZpdHk=")}`).length, 1);
  assert.equal(findForbiddenCommitMessages([{ sha: "abc1234", message: `msg\n\n${trailer}` }]).length, 1);
  assert.equal(findForbiddenBranchName("claude/test-branch").length, 1);
  assert.deepEqual(findForbiddenBranchName("perf/oss-ux-bit-query-opt"), []);
});

test("live repository passes repo hygiene check", () => {
  const repoRoot = new URL("../..", import.meta.url).pathname;
  assert.doesNotThrow(() => runRepoHygieneCheck(repoRoot));
});
