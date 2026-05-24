import assert from "node:assert/strict";
import { execFile } from "node:child_process";
import { mkdtemp, readFile, writeFile } from "node:fs/promises";
import { tmpdir } from "node:os";
import { dirname, resolve } from "node:path";
import test from "node:test";
import { fileURLToPath } from "node:url";
import { promisify } from "node:util";

const __dirname = dirname(fileURLToPath(import.meta.url));
const repoRoot = resolve(__dirname, "../..");
const execFileAsync = promisify(execFile);

test("ci workflow detects changed paths before platform jobs", async () => {
  const workflow = await readWorkflow();
  const changes = jobBlock(workflow, "changes");

  assert.match(changes, /name: Changes/);
  assert.match(changes, /fetch-depth: 0/);
  assert.match(changes, /id: filter/);
  assert.match(changes, /git diff --name-only/);
  assert.match(changes, /bash tools\/ci\/detect-changed-paths\.sh changed-files\.txt/);

  for (const output of ["android", "backend", "frontend", "ios", "javascript", "repository", "docs_only", "ci"]) {
    assert.match(changes, new RegExp(`${output}: \\$\\{\\{ steps\\.filter\\.outputs\\.${output} \\}\\}`));
  }
});

test("ci jobs are gated by changed path outputs", async () => {
  const workflow = await readWorkflow();

  assertJobGate(workflow, "android", "android");
  assertJobGate(workflow, "backend", "backend");
  assertJobGate(workflow, "frontend", "frontend");
  assertJobGate(workflow, "ios", "ios");
  assertJobGate(workflow, "javascript", "javascript");

  const repositoryContracts = jobBlock(workflow, "repository-contracts");
  assert.match(repositoryContracts, /needs: changes/);
  assert.match(
    repositoryContracts,
    /if: \$\{\{ needs\.changes\.outputs\.repository == 'true' \|\| needs\.changes\.outputs\.docs_only == 'true' \|\| needs\.changes\.outputs\.ci == 'true' \}\}/
  );
});

test("platform jobs skip cleanly before scaffolds exist", async () => {
  const workflow = await readWorkflow();

  assert.match(jobBlock(workflow, "android"), /Android scaffold not found; skipping Android checks\./);
  assert.match(jobBlock(workflow, "backend"), /Backend scaffold not found; skipping backend checks\./);
  assert.match(jobBlock(workflow, "frontend"), /Frontend scaffold not found; skipping frontend checks\./);
  assert.match(jobBlock(workflow, "ios"), /iOS scaffold not found; skipping iOS checks\./);
  assert.match(jobBlock(workflow, "javascript"), /JavaScript scaffold not found; skipping JavaScript checks\./);
});

test("frontend job supports Flutter and Node scaffolds", async () => {
  const frontend = jobBlock(await readWorkflow(), "frontend");

  assert.match(frontend, /\[\[ -f front\/pubspec\.yaml \]\]/);
  assert.match(frontend, /echo "stack=flutter"/);
  assert.match(frontend, /subosito\/flutter-action@[a-f0-9]{40}/);
  assert.match(frontend, /flutter pub get/);
  assert.match(frontend, /flutter analyze/);
  assert.match(frontend, /flutter test/);
  assert.match(frontend, /\[\[ -f front\/package\.json \]\]/);
  assert.match(frontend, /echo "stack=node"/);
});

test("ci pins GitHub Action references to immutable commits", async () => {
  const workflow = await readWorkflow();

  assert.doesNotMatch(workflow, /uses: [^\s]+@v\d/m);
  assert.match(workflow, /actions\/checkout@[a-f0-9]{40}/);
  assert.match(workflow, /actions\/setup-node@[a-f0-9]{40}/);
  assert.match(workflow, /actions\/setup-java@[a-f0-9]{40}/);
  assert.match(workflow, /subosito\/flutter-action@[a-f0-9]{40}/);
});

test("repository contracts preserve local docs and issue template policies", async () => {
  const workflow = await readWorkflow();
  const repositoryContracts = jobBlock(workflow, "repository-contracts");

  assert.match(repositoryContracts, /git diff --check/);
  assert.match(repositoryContracts, /node --test tools\/ci\/\*\.test\.mjs/);
  assert.match(repositoryContracts, /ruby -e 'require "yaml"/);
  assert.match(repositoryContracts, /Unexpected tracked Markdown file/);
  assert.match(repositoryContracts, /Unexpected tracked local agent file/);
});

test("path classifier treats README and pull request template changes as docs-only", async () => {
  const outputs = await classifyChangedFiles(["README.md", ".github/pull_request_template.md"]);

  assert.equal(outputs.docs_only, "true");
  assert.equal(outputs.android, "false");
  assert.equal(outputs.backend, "false");
  assert.equal(outputs.frontend, "false");
  assert.equal(outputs.ios, "false");
  assert.equal(outputs.javascript, "false");
  assert.equal(outputs.repository, "false");
  assert.equal(outputs.ci, "false");
});

test("path classifier enables repository checks for GitHub issue template changes", async () => {
  const outputs = await classifyChangedFiles([".github/ISSUE_TEMPLATE/feature_request.yml"]);

  assert.equal(outputs.docs_only, "false");
  assert.equal(outputs.repository, "true");
  assert.equal(outputs.android, "false");
  assert.equal(outputs.backend, "false");
  assert.equal(outputs.frontend, "false");
  assert.equal(outputs.ios, "false");
  assert.equal(outputs.javascript, "false");
});

test("path classifier enables Android checks for Android or Gradle changes", async () => {
  const outputs = await classifyChangedFiles(["android/app/build.gradle.kts", "gradle/libs.versions.toml"]);

  assert.equal(outputs.docs_only, "false");
  assert.equal(outputs.android, "true");
  assert.equal(outputs.backend, "false");
  assert.equal(outputs.frontend, "false");
  assert.equal(outputs.ios, "false");
  assert.equal(outputs.javascript, "false");
});

test("path classifier enables iOS checks for iOS changes", async () => {
  const outputs = await classifyChangedFiles(["ios/MaumOn/AppDelegate.swift"]);

  assert.equal(outputs.docs_only, "false");
  assert.equal(outputs.android, "false");
  assert.equal(outputs.backend, "false");
  assert.equal(outputs.frontend, "false");
  assert.equal(outputs.ios, "true");
  assert.equal(outputs.javascript, "false");
});

test("path classifier enables JavaScript checks for package or source changes", async () => {
  const outputs = await classifyChangedFiles(["package.json", "src/app.ts"]);

  assert.equal(outputs.docs_only, "false");
  assert.equal(outputs.android, "false");
  assert.equal(outputs.backend, "false");
  assert.equal(outputs.frontend, "false");
  assert.equal(outputs.ios, "false");
  assert.equal(outputs.javascript, "true");
});

test("path classifier enables backend checks for back changes", async () => {
  const outputs = await classifyChangedFiles(["back/src/main/java/com/maumonmobile/App.java"]);

  assert.equal(outputs.docs_only, "false");
  assert.equal(outputs.backend, "true");
  assert.equal(outputs.frontend, "false");
  assert.equal(outputs.android, "false");
  assert.equal(outputs.ios, "false");
});

test("path classifier enables frontend checks for front changes", async () => {
  const outputs = await classifyChangedFiles(["front/src/screens/HomeScreen.tsx"]);

  assert.equal(outputs.docs_only, "false");
  assert.equal(outputs.backend, "false");
  assert.equal(outputs.frontend, "true");
  assert.equal(outputs.android, "false");
  assert.equal(outputs.ios, "false");
});

test("path classifier keeps front package changes in frontend gate", async () => {
  const outputs = await classifyChangedFiles(["front/package.json"]);

  assert.equal(outputs.docs_only, "false");
  assert.equal(outputs.frontend, "true");
  assert.equal(outputs.javascript, "false");
});

test("path classifier keeps back Gradle changes in backend gate", async () => {
  const outputs = await classifyChangedFiles(["back/build.gradle.kts", "back/gradlew"]);

  assert.equal(outputs.docs_only, "false");
  assert.equal(outputs.backend, "true");
  assert.equal(outputs.android, "false");
});

test("path classifier enables root JavaScript checks for root package changes", async () => {
  const outputs = await classifyChangedFiles(["package.json", "src/app.ts"]);

  assert.equal(outputs.docs_only, "false");
  assert.equal(outputs.backend, "false");
  assert.equal(outputs.frontend, "false");
  assert.equal(outputs.android, "false");
  assert.equal(outputs.ios, "false");
  assert.equal(outputs.javascript, "true");
});

test("path classifier enables all checks for ci workflow changes", async () => {
  const outputs = await classifyChangedFiles([".github/workflows/ci.yml"]);

  assert.equal(outputs.docs_only, "false");
  assert.equal(outputs.ci, "true");
  assert.equal(outputs.android, "true");
  assert.equal(outputs.backend, "true");
  assert.equal(outputs.frontend, "true");
  assert.equal(outputs.ios, "true");
  assert.equal(outputs.javascript, "true");
  assert.equal(outputs.repository, "true");
});

test("path classifier enables all checks when no changed files are available", async () => {
  const outputs = await classifyChangedFiles([]);

  assert.equal(outputs.docs_only, "false");
  assert.equal(outputs.android, "true");
  assert.equal(outputs.backend, "true");
  assert.equal(outputs.frontend, "true");
  assert.equal(outputs.ios, "true");
  assert.equal(outputs.javascript, "true");
  assert.equal(outputs.repository, "true");
});

async function readWorkflow() {
  return readFile(resolve(repoRoot, ".github/workflows/ci.yml"), "utf8");
}

function assertJobGate(workflow, jobId, outputName) {
  const block = jobBlock(workflow, jobId);

  assert.match(block, /needs: changes/);
  assert.match(block, new RegExp(`if: \\$\\{\\{ needs\\.changes\\.outputs\\.${outputName} == 'true' \\}\\}`));
}

function jobBlock(workflow, jobId) {
  const expression = new RegExp(`\\n  ${escapeRegExp(jobId)}:\\n([\\s\\S]*?)(?=\\n  [a-zA-Z0-9_-]+:\\n|\\n*$)`);
  const match = workflow.match(expression);

  assert.ok(match, `Expected job '${jobId}' to exist`);

  return match[1];
}

function escapeRegExp(value) {
  return value.replace(/[.*+?^${}()|[\]\\]/g, "\\$&");
}

async function classifyChangedFiles(files) {
  const directory = await mkdtemp(resolve(tmpdir(), "maum-mobile-ci-paths-"));
  const changedFilesPath = resolve(directory, "changed-files.txt");
  const outputPath = resolve(directory, "github-output.txt");

  await writeFile(changedFilesPath, files.length > 0 ? `${files.join("\n")}\n` : "");
  await execFileAsync("bash", [resolve(repoRoot, "tools/ci/detect-changed-paths.sh"), changedFilesPath], {
    env: {
      ...process.env,
      GITHUB_OUTPUT: outputPath,
      GITHUB_STEP_SUMMARY: resolve(directory, "summary.md"),
    },
  });

  const rawOutput = await readFile(outputPath, "utf8");

  return Object.fromEntries(
    rawOutput
      .trim()
      .split("\n")
      .filter(Boolean)
      .map((line) => line.split("=", 2))
  );
}
