import { execFileSync } from "node:child_process";
import fs from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";

const REQUIRED_TRACKED_FILES = [
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

const ALLOWED_ISSUE_TEMPLATE_FILES = new Set(["bug_report.yml", "config.yml"]);
const ISSUE_TEMPLATE_DIR = ".github/ISSUE_TEMPLATE/";
const MAX_SCAN_BYTES = 2 * 1024 * 1024;
const SKIP_SCAN_PREFIXES = [
  "node_modules/",
  ".dart_tool/",
  ".gradle/",
  "build/",
  "dist/",
  ".next/",
];
const TEXT_EXTENSIONS = new Set([
  ".md",
  ".yml",
  ".yaml",
  ".json",
  ".mjs",
  ".js",
  ".ts",
  ".tsx",
  ".dart",
  ".kt",
  ".kts",
  ".java",
  ".sh",
  ".css",
  ".html",
  ".xml",
  ".sql",
  ".properties",
  ".gradle",
]);

const decode = (b64) => Buffer.from(b64, "base64").toString("utf8");
const escapeRegExp = (value) => value.replace(/[.*+?^${}()|[\]\\]/g, "\\$&");

// Keep forbidden local-only filenames, directory prefixes, and attribution markers Base64-encoded
// so this guard never triggers on its own source file.
const FORBIDDEN_FILE_NAMES = [
  "QUdFTlRTLm1k",
  "Q0xBVURFLm1k",
  "Q0xBVURFLmxvY2FsLm1k",
  "R0VNSU5JLm1k",
  "Q1VSU09SLm1k",
  "Q09QSUxPVC5tZA==",
  "aW1wbGVtZW50YXRpb25fcGxhbi5tZA==",
  "d2Fsa3Rocm91Z2gubWQ=",
  "LmNvZGVyYWJiaXQueWFtbA==",
].map(decode);

const FORBIDDEN_DIR_PREFIXES = [
  "LmFnZW50cy8=",
  "LmNsYXVkZS8=",
  "LmNvZGV4Lw==",
  "LmdlbWluaS8=",
  "ZG9jcy9hZ2VudC8=",
].map(decode);

const FORBIDDEN_TEXT_PATTERNS = [
  "QUdFTlRTLm1k",
  "Q0xBVURFLm1k",
  "Q0xBVURFLmxvY2FsLm1k",
  "R0VNSU5JLm1k",
  "Q1VSU09SLm1k",
  "Q09QSUxPVC5tZA==",
  "aW1wbGVtZW50YXRpb25fcGxhbi5tZA==",
  "d2Fsa3Rocm91Z2gubWQ=",
  "LmFnZW50cy8=",
  "LmNsYXVkZS8=",
  "LmNvZGV4Lw==",
  "LmdlbWluaS8=",
  "ZG9jcy9hZ2VudC8=",
  "QW50aWdyYXZpdHk=",
  "Q2xhdWRlIENvZGU=",
  "Q29kZVJhYmJpdA==",
  "LmNvZGVyYWJiaXQueWFtbA==",
  "Q28tQXV0aG9yZWQtQnk6",
  "Q2xhdWRlLVNlc3Npb246",
  "R2VuZXJhdGVkIHdpdGgg",
].map((b64) => ({
  len: decode(b64).length,
  regex: new RegExp(escapeRegExp(decode(b64)), "i"),
}));

const FORBIDDEN_BRANCH_PREFIX = /^(claude|codex)\//i;
const FORBIDDEN_INTAKE_FILE =
  /(^|\/)(pull_request_template(\.[^/]*)?|labeler\.ya?ml|labels\.ya?ml|issue_template\.[^/]*)$/i;
const FORBIDDEN_INTAKE_DIR = /(^|\/)pull_request_template\//i;
const ZERO_SHA = /^0+$/;

export function findMissingRequiredTrackedFiles(trackedFiles) {
  const trackedSet = new Set(trackedFiles.map((file) => file.trim()).filter(Boolean));
  return REQUIRED_TRACKED_FILES.filter((file) => !trackedSet.has(file)).map(
    (file) => `${file} (required governance/security contract file is missing)`
  );
}

export function findIntakeViolations(trackedFiles) {
  const violations = [];
  for (const rawFile of trackedFiles) {
    const rel = rawFile.trim();
    if (!rel) continue;
    if (rel.startsWith(ISSUE_TEMPLATE_DIR)) {
      const leaf = rel.slice(ISSUE_TEMPLATE_DIR.length);
      if (!ALLOWED_ISSUE_TEMPLATE_FILES.has(leaf)) {
        violations.push(`${rel} (only bug_report.yml and config.yml are allowed in ${ISSUE_TEMPLATE_DIR})`);
      }
      continue;
    }
    if (
      FORBIDDEN_INTAKE_FILE.test(rel) ||
      FORBIDDEN_INTAKE_DIR.test(rel) ||
      /^\.github\/dependabot\.ya?ml$/i.test(rel)
    ) {
      violations.push(`${rel} (solo workflow forbids PR templates, label configs, and dependabot PRs)`);
    }
  }
  return violations;
}

export function findForbiddenTrackedFiles(trackedFiles) {
  const violations = [];
  for (const rawFile of trackedFiles) {
    const rel = rawFile.trim();
    if (!rel) continue;

    const base = rel.includes("/") ? rel.slice(rel.lastIndexOf("/") + 1) : rel;
    if (FORBIDDEN_FILE_NAMES.includes(base)) {
      violations.push(`${rel} (forbidden local agent or bot config file must not be tracked)`);
      continue;
    }
    if (FORBIDDEN_DIR_PREFIXES.some((prefix) => rel.startsWith(prefix) || rel.includes(`/${prefix}`))) {
      violations.push(`${rel} (forbidden local agent directory must not be tracked)`);
      continue;
    }
    if (/(^|\/)\.env$/.test(rel) || /(^|\/)vertex-key\.json$/.test(rel) || /^\.gradle-local\//.test(rel)) {
      violations.push(`${rel} (local secret or gradle cache file must not be tracked)`);
    }
  }
  return violations;
}

export function findForbiddenTextPatterns(label, text) {
  const hits = [];
  for (const { len, regex } of FORBIDDEN_TEXT_PATTERNS) {
    if (regex.test(text)) {
      hits.push(`${label} (prohibited token of length ${len} detected)`);
    }
  }
  return hits;
}

export function findForbiddenTrackedFileContents(repoRoot, trackedFiles) {
  const violations = [];
  for (const rawFile of trackedFiles) {
    const rel = rawFile.trim();
    if (!rel) continue;
    if (SKIP_SCAN_PREFIXES.some((prefix) => rel.startsWith(prefix) || rel.includes(`/${prefix}`))) {
      continue;
    }
    const ext = path.extname(rel).toLowerCase();
    const base = path.basename(rel);
    if (!TEXT_EXTENSIONS.has(ext) && base !== ".gitignore") {
      continue;
    }
    const fullPath = path.join(repoRoot, rel);
    let stat;
    try {
      stat = fs.statSync(fullPath);
    } catch {
      continue;
    }
    if (!stat.isFile() || stat.size > MAX_SCAN_BYTES) {
      continue;
    }
    const content = fs.readFileSync(fullPath, "utf8");
    violations.push(...findForbiddenTextPatterns(rel, content));
  }
  return violations;
}

export function findForbiddenCommitMessages(commits) {
  const violations = [];
  for (const commit of commits) {
    violations.push(...findForbiddenTextPatterns(`commit ${commit.sha}`, commit.message));
  }
  return violations;
}

export function findForbiddenBranchName(branchName) {
  const trimmed = (branchName || "").trim();
  if (trimmed && FORBIDDEN_BRANCH_PREFIX.test(trimmed)) {
    return [`${trimmed} (agent-prefixed branch name is not allowed)`];
  }
  return [];
}

function readTrackedFiles(repoRoot) {
  const output = execFileSync("git", ["ls-files"], {
    cwd: repoRoot,
    encoding: "utf8",
  });
  return output.split(/\r?\n/).filter(Boolean);
}

function readCurrentBranch(repoRoot) {
  try {
    return execFileSync("git", ["symbolic-ref", "--quiet", "--short", "HEAD"], {
      cwd: repoRoot,
      encoding: "utf8",
    }).trim();
  } catch {
    return "";
  }
}

function hasCommit(repoRoot, rev) {
  try {
    execFileSync("git", ["rev-parse", "--verify", "--quiet", rev], {
      cwd: repoRoot,
      stdio: "ignore",
    });
    return true;
  } catch {
    return false;
  }
}

function readCommits(repoRoot, commitRange) {
  let args;
  if (commitRange && !ZERO_SHA.test(commitRange.base)) {
    args = ["log", `--format=%h%x1f%B%x1e`, `${commitRange.base}..${commitRange.head}`];
  } else if (commitRange) {
    args = ["log", "-n", "10", `--format=%h%x1f%B%x1e`, commitRange.head];
  } else if (hasCommit(repoRoot, "HEAD~5")) {
    args = ["log", "--format=%h%x1f%B%x1e", "HEAD~5..HEAD"];
  } else {
    args = ["log", "-n", "5", "--format=%h%x1f%B%x1e", "HEAD"];
  }
  const output = execFileSync("git", args, {
    cwd: repoRoot,
    encoding: "utf8",
  });
  return output
    .split("\x1e")
    .map((entry) => entry.trim())
    .filter(Boolean)
    .map((entry) => {
      const idx = entry.indexOf("\x1f");
      return idx < 0
        ? { sha: "HEAD", message: entry }
        : { sha: entry.slice(0, idx).trim(), message: entry.slice(idx + 1) };
    });
}

export function runRepoHygieneCheck(repoRoot, { commitRange = null } = {}) {
  const trackedFiles = readTrackedFiles(repoRoot);
  const violations = [
    ...findMissingRequiredTrackedFiles(trackedFiles),
    ...findIntakeViolations(trackedFiles),
    ...findForbiddenTrackedFiles(trackedFiles),
    ...findForbiddenTrackedFileContents(repoRoot, trackedFiles),
    ...findForbiddenCommitMessages(readCommits(repoRoot, commitRange)),
    ...findForbiddenBranchName(readCurrentBranch(repoRoot)),
  ];
  if (violations.length > 0) {
    throw new Error(`[repo-hygiene] check failed:\n- ${violations.join("\n- ")}`);
  }
}

if (process.argv[1] === fileURLToPath(import.meta.url)) {
  const repoRoot = path.resolve(import.meta.dirname, "../..");
  let commitRange = null;
  const idx = process.argv.indexOf("--commits");
  if (idx >= 0) {
    const base = process.argv[idx + 1];
    const head = process.argv[idx + 2];
    if (!base || !head) {
      throw new Error("Usage: node tools/ci/check-repo-hygiene.mjs [--commits <base-sha> <head-sha>]");
    }
    commitRange = { base, head };
  }
  runRepoHygieneCheck(repoRoot, { commitRange });
  console.log("[repo-hygiene] repository hygiene checks passed");
}
