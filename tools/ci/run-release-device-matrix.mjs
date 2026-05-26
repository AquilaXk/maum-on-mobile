import { mkdirSync, readFileSync, writeFileSync } from "node:fs";
import { dirname, resolve } from "node:path";
import { fileURLToPath } from "node:url";

const __dirname = dirname(fileURLToPath(import.meta.url));
const repoRoot = resolve(__dirname, "../..");

const args = parseArgs(process.argv.slice(2));
const platform = args.platform;
const reportDir = resolve(repoRoot, args.reportDir ?? "build/reports/release-device-matrix");
const configPath = resolve(repoRoot, args.config ?? "contracts/release-candidate/device-matrix.json");

if (!["android", "ios"].includes(platform)) {
  failUsage("Expected --platform to be either android or ios.");
}

const matrix = JSON.parse(readFileSync(configPath, "utf8"));
const platformConfig = matrix.platforms?.[platform];
if (!platformConfig) {
  failUsage(`Missing platform configuration for ${platform}.`);
}

const scenarios = matrix.scenarios
  .filter((scenario) => scenario.platforms.includes(platform))
  .map((scenario) => ({
    platform,
    deviceProfiles: platformConfig.deviceProfiles.map((profile) => profile.id),
    scenario: scenario.id,
    name: scenario.name,
    priority: scenario.priority,
    area: scenario.area,
    mode: scenario.mode,
    status: "pending",
    passCriteria: scenario.passCriteria,
    evidenceRequired: scenario.evidenceRequired ?? [],
    automationCommands: scenario.automation?.commands ?? [],
    resultFields: scenario.resultFields,
    evidence: [],
    notes: "",
  }));

const report = {
  platform,
  status: "pending",
  generatedAt: new Date().toISOString(),
  requiredResultFields: platformConfig.requiredResultFields,
  smokeBuildCommands: platformConfig.smokeBuildCommands,
  deviceProfiles: platformConfig.deviceProfiles,
  summary: {
    scenarios: scenarios.length,
    automated: scenarios.filter((scenario) => scenario.mode === "automated").length,
    hybrid: scenarios.filter((scenario) => scenario.mode === "hybrid").length,
    manual: scenarios.filter((scenario) => scenario.mode === "manual").length,
  },
  reportContract: matrix.report,
  scenarios,
};

mkdirSync(reportDir, { recursive: true });
const jsonReportPath = resolve(reportDir, `release-device-matrix-${platform}.json`);
const markdownReportPath = resolve(reportDir, `release-device-matrix-${platform}.md`);

writeFileSync(jsonReportPath, `${JSON.stringify(report, null, 2)}\n`);
writeFileSync(markdownReportPath, renderMarkdownReport(report));

console.log(`Release candidate device matrix report: ${jsonReportPath}`);
console.log(renderConsoleSummary(report));

if (process.env.GITHUB_STEP_SUMMARY) {
  writeFileSync(process.env.GITHUB_STEP_SUMMARY, `\n${renderMarkdownReport(report)}\n`, { flag: "a" });
}

function renderMarkdownReport(report) {
  const lines = [
    `### Release Candidate Device Matrix (${report.platform})`,
    "",
    `- status: ${report.status}`,
    `- scenarios: ${report.summary.scenarios}`,
    `- automated: ${report.summary.automated}`,
    `- hybrid: ${report.summary.hybrid}`,
    `- manual: ${report.summary.manual}`,
    "",
    "#### Smoke Build Commands",
    "",
    ...report.smokeBuildCommands.map((command) => `- \`${command}\``),
    "",
    "#### Device Profiles",
    "",
    ...report.deviceProfiles.map((profile) => `- ${profile.id}: ${profile.deviceType}, ${profile.formFactor}, ${profile.osRange}`),
    "",
    "#### Scenario Checklist",
    "",
    ...report.scenarios.map((scenario) => {
      const automation = scenario.automationCommands.length > 0
        ? ` automation: ${scenario.automationCommands.map((command) => `\`${command}\``).join(", ")}`
        : "";
      return `- [ ] ${scenario.priority} ${scenario.scenario} [${scenario.area}/${scenario.mode}] ${scenario.passCriteria}${automation}`;
    }),
  ];

  return `${lines.join("\n")}\n`;
}

function renderConsoleSummary(report) {
  return [
    `status=${report.status}`,
    `platform=${report.platform}`,
    `scenarios=${report.summary.scenarios}`,
    `manual=${report.summary.manual}`,
    `hybrid=${report.summary.hybrid}`,
    `automated=${report.summary.automated}`,
  ].join("\n");
}

function parseArgs(rawArgs) {
  const parsed = {
    platform: undefined,
    reportDir: undefined,
    config: undefined,
  };

  for (let index = 0; index < rawArgs.length; index += 1) {
    const arg = rawArgs[index];
    if (arg === "--platform") {
      parsed.platform = rawArgs[++index];
    } else if (arg === "--report-dir") {
      parsed.reportDir = rawArgs[++index];
    } else if (arg === "--config") {
      parsed.config = rawArgs[++index];
    } else {
      failUsage(`Unknown argument: ${arg}`);
    }
  }

  return parsed;
}

function failUsage(message) {
  console.error(message);
  console.error("Usage: node tools/ci/run-release-device-matrix.mjs --platform <android|ios> [--report-dir path] [--config path]");
  process.exit(2);
}
