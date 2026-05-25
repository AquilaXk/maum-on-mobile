import { existsSync, mkdirSync, readFileSync, statSync, writeFileSync } from "node:fs";
import { dirname, resolve } from "node:path";
import { fileURLToPath } from "node:url";

const __dirname = dirname(fileURLToPath(import.meta.url));
const repoRoot = resolve(__dirname, "../..");

const args = parseArgs(process.argv.slice(2));
const platform = args.platform;
const reportDir = resolve(repoRoot, args.reportDir ?? "build/reports/mobile-quality");
const configPath = resolve(repoRoot, args.config ?? "tools/ci/mobile-quality-gate-scenarios.json");
const skipBuildArtifact = args.skipBuildArtifact === true;

if (!["android", "ios"].includes(platform)) {
  failUsage("Expected --platform to be either android or ios.");
}

const config = JSON.parse(readFileSync(configPath, "utf8"));
const platformConfig = config.platforms?.[platform];
if (!platformConfig) {
  failUsage(`Missing platform configuration for ${platform}.`);
}

const artifactResults = (platformConfig.buildArtifacts ?? []).map((relativePath) => {
  const absolutePath = resolve(repoRoot, relativePath);
  return {
    path: relativePath,
    exists: existsSync(absolutePath),
    kind: existsSync(absolutePath) ? (statSync(absolutePath).isDirectory() ? "directory" : "file") : "missing",
  };
});

const scenarioResults = config.scenarios.map((scenario) => evaluateScenario(scenario, platform));
const requiredFields = config.report?.requiredFields ?? [];
const missingReportFields = scenarioResults.flatMap((result) =>
  requiredFields
    .filter((field) => !(field in result))
    .map((field) => `${result.scenario}:${field}`)
);

const missingArtifacts = skipBuildArtifact ? [] : artifactResults.filter((artifact) => !artifact.exists);
const failedScenarios = scenarioResults.filter((scenario) => scenario.status !== "pass");
const status = missingArtifacts.length === 0 && failedScenarios.length === 0 && missingReportFields.length === 0
  ? "pass"
  : "fail";

const report = {
  platform,
  status,
  generatedAt: new Date().toISOString(),
  buildArtifacts: artifactResults,
  summary: {
    scenarios: scenarioResults.length,
    passed: scenarioResults.length - failedScenarios.length,
    failed: failedScenarios.length,
    missingArtifacts: missingArtifacts.length,
    missingReportFields: missingReportFields.length,
  },
  scenarios: scenarioResults,
  missingReportFields,
};

mkdirSync(reportDir, { recursive: true });
const jsonReportPath = resolve(reportDir, `mobile-quality-${platform}.json`);
const markdownReportPath = resolve(reportDir, `mobile-quality-${platform}.md`);
writeFileSync(jsonReportPath, `${JSON.stringify(report, null, 2)}\n`);
writeFileSync(markdownReportPath, renderMarkdownReport(report));

console.log(`Mobile quality gate report: ${jsonReportPath}`);
console.log(renderConsoleSummary(report));

if (process.env.GITHUB_STEP_SUMMARY) {
  writeFileSync(process.env.GITHUB_STEP_SUMMARY, `\n${renderMarkdownReport(report)}\n`, { flag: "a" });
}

if (status !== "pass") {
  process.exitCode = 1;
}

function evaluateScenario(scenario, platform) {
  const evidence = (scenario.evidence ?? []).map((entry) => {
    const absolutePath = resolve(repoRoot, entry.path);
    if (!existsSync(absolutePath)) {
      return {
        path: entry.path,
        status: "fail",
        missingPatterns: entry.patterns ?? [],
      };
    }

    const contents = readFileSync(absolutePath, "utf8");
    const missingPatterns = (entry.patterns ?? []).filter((pattern) => !contents.includes(pattern));
    return {
      path: entry.path,
      status: missingPatterns.length === 0 ? "pass" : "fail",
      missingPatterns,
    };
  });

  const failedEvidence = evidence.filter((entry) => entry.status !== "pass");
  return {
    platform,
    scenario: scenario.id,
    name: scenario.name,
    status: failedEvidence.length === 0 ? "pass" : "fail",
    area: scenario.area,
    failureStep: scenario.failureStep,
    evidence,
  };
}

function renderMarkdownReport(report) {
  const lines = [
    `### Mobile Quality Gate (${report.platform})`,
    "",
    `- status: ${report.status}`,
    `- scenarios: ${report.summary.passed}/${report.summary.scenarios} passed`,
    `- missing artifacts: ${report.summary.missingArtifacts}`,
    "",
    "#### Build Artifacts",
    "",
    ...report.buildArtifacts.map((artifact) => `- ${artifact.exists ? "PASS" : "FAIL"} ${artifact.path} (${artifact.kind})`),
    "",
    "#### Scenarios",
    "",
    ...report.scenarios.map((scenario) => {
      const failedEvidence = scenario.evidence
        .filter((entry) => entry.status !== "pass")
        .map((entry) => `${entry.path}: ${entry.missingPatterns.join(", ")}`)
        .join("; ");
      return `- ${scenario.status === "pass" ? "PASS" : "FAIL"} ${scenario.scenario} [${scenario.area}] ${scenario.failureStep}${failedEvidence ? ` - ${failedEvidence}` : ""}`;
    }),
  ];

  if (report.missingReportFields.length > 0) {
    lines.push("", "#### Report Contract", "", ...report.missingReportFields.map((field) => `- FAIL ${field}`));
  }

  return `${lines.join("\n")}\n`;
}

function renderConsoleSummary(report) {
  const failed = report.scenarios
    .filter((scenario) => scenario.status !== "pass")
    .map((scenario) => `${scenario.scenario} (${scenario.area}: ${scenario.failureStep})`);

  return [
    `status=${report.status}`,
    `platform=${report.platform}`,
    `scenarios=${report.summary.passed}/${report.summary.scenarios}`,
    `missingArtifacts=${report.summary.missingArtifacts}`,
    failed.length > 0 ? `failed=${failed.join("; ")}` : "failed=none",
  ].join("\n");
}

function parseArgs(rawArgs) {
  const parsed = {
    platform: undefined,
    reportDir: undefined,
    config: undefined,
    skipBuildArtifact: false,
  };

  for (let index = 0; index < rawArgs.length; index += 1) {
    const arg = rawArgs[index];
    if (arg === "--platform") {
      parsed.platform = rawArgs[++index];
    } else if (arg === "--report-dir") {
      parsed.reportDir = rawArgs[++index];
    } else if (arg === "--config") {
      parsed.config = rawArgs[++index];
    } else if (arg === "--skip-build-artifact") {
      parsed.skipBuildArtifact = true;
    } else {
      failUsage(`Unknown argument: ${arg}`);
    }
  }

  return parsed;
}

function failUsage(message) {
  console.error(message);
  console.error("Usage: node tools/ci/run-mobile-quality-gate.mjs --platform <android|ios> [--report-dir path] [--skip-build-artifact]");
  process.exit(2);
}
