import { execFileSync } from "node:child_process";
import { existsSync, mkdirSync, readFileSync, writeFileSync } from "node:fs";
import { extname, join, resolve } from "node:path";

const repoRoot = process.cwd();
const args = parseArgs(process.argv.slice(2));
const contractPath = resolve(repoRoot, args.config ?? "contracts/security-release/security-gate.json");
const reportDir = resolve(repoRoot, args.reportDir ?? "build/reports/release-security");
const contract = readJson(contractPath);
const auditDir = resolve(repoRoot, args.auditDir ?? contract.auditInputs.directory);
const failures = [];

const sbom = buildSbom(contract);
const licenses = buildLicenseReport(sbom.components, contract);
const staticChecks = runStaticChecks(contract);
const auditResults = readAuditResults(sbom.ecosystems, contract, auditDir, args.requireAudits);

for (const license of licenses) {
  if (!license.allowed) {
    failures.push({
      reason: "unapproved_license",
      message: `${license.ecosystem}:${license.name} uses ${license.license}`,
      component: license.name,
    });
  }
}

for (const check of Object.values(staticChecks)) {
  failures.push(...check.failures);
}

for (const audit of auditResults) {
  failures.push(...audit.failures);
}

const report = {
  status: determineStatus(failures),
  generatedAt: new Date().toISOString(),
  severityThreshold: contract.auditInputs.severityThreshold,
  sbom,
  licenses,
  staticChecks,
  auditResults,
  failures,
};

mkdirSync(reportDir, { recursive: true });
writeFileSync(resolve(reportDir, "release-security-report.json"), `${JSON.stringify(report, null, 2)}\n`);
writeFileSync(resolve(reportDir, "release-security-sbom.json"), `${JSON.stringify(sbom, null, 2)}\n`);
writeFileSync(resolve(reportDir, "release-security-licenses.json"), `${JSON.stringify(licenses, null, 2)}\n`);
writeFileSync(resolve(reportDir, "release-security-report.md"), renderMarkdown(report));

if (process.env.GITHUB_STEP_SUMMARY) {
  writeFileSync(process.env.GITHUB_STEP_SUMMARY, `\n${renderMarkdown(report)}\n`, { flag: "a" });
}

console.log(`Release security report: ${resolve(reportDir, "release-security-report.json")}`);
console.log(renderConsoleSummary(report));

if (report.status !== "pass") {
  for (const failure of failures.slice(0, 40)) {
    console.error(`${failure.reason}: ${failure.message}`);
  }
  if (failures.length > 40) {
    console.error(`Additional failures omitted from log: ${failures.length - 40}`);
  }
  process.exit(1);
}

function buildSbom(config) {
  const ecosystems = config.ecosystems.map((ecosystem) => ({
    id: ecosystem.id,
    name: ecosystem.name,
    present: isEcosystemPresent(ecosystem),
    auditRequired: ecosystem.auditRequiredWhenPresent,
    manifest: ecosystem.manifest,
    lockfile: ecosystem.lockfile,
  }));
  const components = [
    ...readFlutterComponents(),
    ...readGradleComponents(),
    ...readRubyComponents(),
    ...readNodeComponents(),
  ];

  return {
    format: "maum-on-mobile-release-sbom",
    version: 1,
    ecosystems,
    components: components.sort((a, b) =>
      `${a.ecosystem}:${a.name}`.localeCompare(`${b.ecosystem}:${b.name}`),
    ),
  };
}

function isEcosystemPresent(ecosystem) {
  return existsSync(resolve(repoRoot, ecosystem.manifest));
}

function buildLicenseReport(components, config) {
  return components.map((component) => {
    const license = config.licenseOverrides?.[component.ecosystem]?.[component.name] ?? "UNKNOWN";

    return {
      ecosystem: component.ecosystem,
      name: component.name,
      version: component.version,
      scope: component.scope,
      license,
      allowed: config.licenseAllowList.includes(license),
    };
  });
}

function runStaticChecks(config) {
  return {
    secretScan: scanSecrets(config),
    binaryArtifactScan: scanBinaryArtifacts(config),
    mobileSecurity: checkMobileSecurity(config),
    backendSecurity: checkBackendSecurity(config),
    logging: checkSensitiveLogging(),
  };
}

function scanSecrets(config) {
  const trackedFiles = gitLsFiles();
  const extensions = new Set(config.secretScan.trackedTextExtensions);
  const patterns = config.secretScan.denyPatterns.map((pattern) => ({
    id: pattern.id,
    regex: new RegExp(pattern.regex, "g"),
  }));
  const failures = [];

  for (const file of trackedFiles) {
    if (!extensions.has(extname(file))) {
      continue;
    }
    const content = readOptional(file);
    for (const pattern of patterns) {
      if (pattern.regex.test(content) && !isAllowedSecretFinding(config, file, pattern.id)) {
        failures.push({
          reason: "secret_exposure",
          message: `${file} matches secret pattern ${pattern.id}`,
          file,
          pattern: pattern.id,
        });
      }
      pattern.regex.lastIndex = 0;
    }
  }

  return {
    status: failures.length === 0 ? "pass" : "fail",
    scannedFiles: trackedFiles.filter((file) => extensions.has(extname(file))).length,
    failures,
  };
}

function isAllowedSecretFinding(config, file, patternId) {
  return (config.secretScan.allowedFindings ?? []).some((allowed) =>
    allowed.file === file && allowed.patternId === patternId,
  );
}

function scanBinaryArtifacts(config) {
  const forbiddenExtensions = new Set(config.binaryArtifactScan.forbiddenTrackedExtensions);
  const files = gitLsFiles().filter((file) => forbiddenExtensions.has(extname(file)));
  const failures = files.map((file) => ({
    reason: "binary_artifact_committed",
    message: `Forbidden release binary or credential artifact is tracked: ${file}`,
    file,
  }));

  return {
    status: failures.length === 0 ? "pass" : "fail",
    forbiddenFiles: files,
    failures,
  };
}

function checkMobileSecurity(config) {
  const failures = [];
  const mobile = config.mobileSecurity;
  const manifest = readOptional(mobile.androidManifest);
  const privacyContract = readJson(resolve(repoRoot, mobile.storePrivacyContract));
  const expectedAndroidPermissions = new Set(
    privacyContract.permissions.flatMap((permission) => permission.androidPermissions),
  );
  const declaredAndroidPermissions = new Set(
    [...manifest.matchAll(/<uses-permission\s+[^>]*android:name="([^"]+)"/g)].map((match) => match[1]),
  );

  for (const permission of expectedAndroidPermissions) {
    if (!declaredAndroidPermissions.has(permission)) {
      failures.push({
        reason: "android_permission_missing",
        message: `Android manifest is missing ${permission}`,
      });
    }
  }

  for (const permission of declaredAndroidPermissions) {
    if (!expectedAndroidPermissions.has(permission) && !mobile.androidAllowedExtraPermissions.includes(permission)) {
      failures.push({
        reason: "android_permission_undeclared",
        message: `Android permission is not declared in store privacy policy: ${permission}`,
      });
    }
  }

  if (/android:usesCleartextTraffic="true"/.test(manifest)) {
    failures.push({
      reason: "android_cleartext_traffic_allowed",
      message: "Android manifest allows cleartext traffic.",
    });
  }

  const infoPlist = readOptional(mobile.iosInfoPlist);
  if (/<key>NSAllowsArbitraryLoads<\/key>\s*<true\/>/.test(infoPlist)) {
    failures.push({
      reason: "ios_cleartext_traffic_allowed",
      message: "iOS ATS allows arbitrary network loads.",
    });
  }

  if (!existsSync(resolve(repoRoot, mobile.iosPrivacyManifest))) {
    failures.push({
      reason: "ios_privacy_manifest_missing",
      message: "iOS privacy manifest is missing.",
    });
  } else {
    const privacyManifest = readOptional(mobile.iosPrivacyManifest);
    if (!/<key>NSPrivacyTracking<\/key>\s*<false\/>/.test(privacyManifest)) {
      failures.push({
        reason: "ios_privacy_tracking_enabled",
        message: "iOS privacy manifest must declare tracking as false.",
      });
    }
    for (const dataType of privacyContract.dataCategories.flatMap((category) => category.appStoreDataTypes)) {
      if (!privacyManifest.includes(dataType)) {
        failures.push({
          reason: "ios_privacy_data_type_missing",
          message: `iOS privacy manifest is missing ${dataType}.`,
        });
      }
    }
  }

  const pods = readPodNames(mobile.iosPodLockfile);
  const unmanagedPods = pods.filter((pod) => !mobile.iosAllowedPodsWithoutPrivacyManifest.includes(pod));

  return {
    status: failures.length === 0 ? "pass" : "fail",
    androidPermissions: [...declaredAndroidPermissions].sort(),
    iosPodsRequiringPrivacyReview: unmanagedPods,
    failures,
  };
}

function checkBackendSecurity(config) {
  const failures = [];
  const backend = config.backendSecurity;
  const applicationConfig = readOptional(backend.applicationConfig);
  const jwtProperties = readOptional(backend.jwtProperties);

  if (!applicationConfig.includes("secret: ${APP_JWT_SECRET}")) {
    failures.push({
      reason: "weak_jwt_secret_policy",
      message: "JWT secret must be required without a default value.",
    });
  }

  if (!new RegExp(`@field:Size\\(min = ${backend.minimumJwtSecretLength}`).test(jwtProperties)) {
    failures.push({
      reason: "weak_jwt_secret_policy",
      message: `JWT properties must require at least ${backend.minimumJwtSecretLength} characters.`,
    });
  }

  return {
    status: failures.length === 0 ? "pass" : "fail",
    minimumJwtSecretLength: backend.minimumJwtSecretLength,
    failures,
  };
}

function checkSensitiveLogging() {
  const files = gitLsFiles().filter((file) =>
    file.startsWith("back/src/main/kotlin/") || file.startsWith("front/lib/"),
  );
  const failures = [];

  for (const file of files) {
    const content = readOptional(file);
    if (/\bprintStackTrace\s*\(|\bprintln\s*\(|\bdebugPrint\s*\(/.test(content)) {
      failures.push({
        reason: "sensitive_log_risk",
        message: `Production source uses direct console logging: ${file}`,
        file,
      });
    }
  }

  return {
    status: failures.length === 0 ? "pass" : "fail",
    scannedFiles: files.length,
    failures,
  };
}

function readAuditResults(ecosystems, config, directory, requireAudits) {
  const threshold = severityRank(config.auditInputs.severityThreshold);

  return ecosystems.map((ecosystem) => {
    if (!ecosystem.present) {
      return {
        ecosystem: ecosystem.id,
        status: "not_present",
        vulnerabilities: [],
        failures: [],
      };
    }

    const auditPath = resolve(directory, config.auditInputs.filePattern.replace("<ecosystem>", ecosystem.id));
    if (!existsSync(auditPath)) {
      const failures = requireAudits && ecosystem.auditRequired
        ? [{
            reason: "missing_audit_result",
            message: `Missing required audit result for ${ecosystem.id}: ${auditPath}`,
            ecosystem: ecosystem.id,
          }]
        : [];

      return {
        ecosystem: ecosystem.id,
        status: requireAudits && ecosystem.auditRequired ? "blocked" : "not_provided",
        path: auditPath,
        vulnerabilities: [],
        failures,
      };
    }

    const document = readJson(auditPath);
    const vulnerabilities = normalizeVulnerabilities(document);
    const failures = vulnerabilities
      .filter((vulnerability) => severityRank(vulnerability.severity) >= threshold)
      .map((vulnerability) => ({
        reason: "high_or_higher_vulnerability",
        message: `${ecosystem.id}:${vulnerability.package ?? "unknown"} ${vulnerability.id ?? "unknown"} severity=${vulnerability.severity}`,
        ecosystem: ecosystem.id,
        vulnerability,
      }));

    return {
      ecosystem: ecosystem.id,
      status: failures.length === 0 ? "pass" : "fail",
      path: auditPath,
      vulnerabilities,
      failures,
    };
  });
}

function normalizeVulnerabilities(document) {
  if (Array.isArray(document)) {
    return document;
  }
  if (Array.isArray(document.vulnerabilities)) {
    return document.vulnerabilities;
  }
  if (Array.isArray(document.advisories)) {
    return document.advisories;
  }
  return [];
}

function severityRank(severity) {
  const normalized = String(severity ?? "").toLowerCase();
  const ranks = {
    none: 0,
    low: 1,
    moderate: 2,
    medium: 2,
    high: 3,
    critical: 4,
  };

  return ranks[normalized] ?? 0;
}

function determineStatus(allFailures) {
  if (allFailures.length === 0) {
    return "pass";
  }
  if (allFailures.some((failure) => failure.reason === "missing_audit_result")) {
    return "blocked";
  }
  return "fail";
}

function readFlutterComponents() {
  const manifestPath = "front/pubspec.yaml";
  if (!existsSync(resolve(repoRoot, manifestPath))) {
    return [];
  }

  return parsePubspecDependencies(readOptional(manifestPath), manifestPath).map((dependency) => ({
    ecosystem: "flutter",
    name: dependency.name,
    version: dependency.version,
    scope: dependency.scope,
    source: manifestPath,
  }));
}

function parsePubspecDependencies(contents, source) {
  const dependencies = [];
  let scope = undefined;
  const lines = contents.split("\n");

  for (let index = 0; index < lines.length; index += 1) {
    const line = lines[index];
    const topLevel = line.match(/^([a-zA-Z_]+):\s*$/);
    if (topLevel) {
      scope = ["dependencies", "dev_dependencies"].includes(topLevel[1]) ? topLevel[1] : undefined;
      continue;
    }

    if (!scope) {
      continue;
    }

    const dependency = line.match(/^  ([a-zA-Z0-9_]+):\s*(.*)$/);
    if (!dependency) {
      continue;
    }

    const name = dependency[1];
    const value = dependency[2].trim();
    if (name === "sdk") {
      continue;
    }
    dependencies.push({
      name,
      version: value.length > 0 ? value : "sdk",
      scope,
      source,
    });
  }

  return dependencies;
}

function readGradleComponents() {
  const files = ["back/build.gradle.kts", "front/android/app/build.gradle.kts"];
  const components = [];

  for (const file of files) {
    if (!existsSync(resolve(repoRoot, file))) {
      continue;
    }
    const contents = readOptional(file);
    const dependencyRegex = /\b(implementation|testImplementation|runtimeOnly|testRuntimeOnly)\("([^":]+:[^":]+)(?::([^"]+))?"\)/g;
    for (const match of contents.matchAll(dependencyRegex)) {
      components.push({
        ecosystem: "gradle",
        name: match[2],
        version: match[3] ?? "managed",
        scope: match[1],
        source: file,
      });
    }

    if (/implementation\(kotlin\("reflect"\)\)/.test(contents)) {
      components.push({
        ecosystem: "gradle",
        name: "org.jetbrains.kotlin:kotlin-reflect",
        version: "managed",
        scope: "implementation",
        source: file,
      });
    }
  }

  return components;
}

function readRubyComponents() {
  const gemfile = "front/ios/Gemfile";
  if (!existsSync(resolve(repoRoot, gemfile))) {
    return [];
  }

  const components = [];
  const gemRegex = /^gem "([^"]+)"(?:,\s*"([^"]+)")?/gm;
  const contents = readOptional(gemfile);
  for (const match of contents.matchAll(gemRegex)) {
    components.push({
      ecosystem: "ruby",
      name: match[1],
      version: match[2] ?? "unlocked",
      scope: "runtime",
      source: gemfile,
    });
  }

  return components;
}

function readNodeComponents() {
  const packageJson = "package.json";
  if (!existsSync(resolve(repoRoot, packageJson))) {
    return [];
  }

  const manifest = readJson(resolve(repoRoot, packageJson));
  const components = [];
  for (const [scope, dependencies] of Object.entries({
    dependencies: manifest.dependencies ?? {},
    dev_dependencies: manifest.devDependencies ?? {},
  })) {
    for (const [name, version] of Object.entries(dependencies)) {
      components.push({
        ecosystem: "node",
        name,
        version,
        scope,
        source: packageJson,
      });
    }
  }

  return components;
}

function readPodNames(lockfile) {
  if (!existsSync(resolve(repoRoot, lockfile))) {
    return [];
  }
  const podsBlock = readOptional(lockfile).match(/^PODS:\n([\s\S]*?)(?=\n[A-Z ]+:\n|$)/m)?.[1] ?? "";
  return [...podsBlock.matchAll(/^\s+- ([A-Za-z0-9_+.-]+)/gm)].map((match) => match[1]);
}

function renderMarkdown(report) {
  const lines = [
    "### Release Security Gate",
    "",
    "| field | value |",
    "| --- | --- |",
    `| status | ${report.status} |`,
    `| components | ${report.sbom.components.length} |`,
    `| licenses | ${report.licenses.length} |`,
    `| failures | ${report.failures.length} |`,
    "",
    "#### Static Checks",
    "",
    ...Object.entries(report.staticChecks).map(([name, check]) => `- ${name}: ${check.status}`),
    "",
    "#### Audit Results",
    "",
    ...report.auditResults.map((audit) => `- ${audit.ecosystem}: ${audit.status} (${audit.vulnerabilities.length} vulnerabilities)`),
    "",
    "#### SBOM Components",
    "",
    "| ecosystem | name | version | scope | license |",
    "| --- | --- | --- | --- | --- |",
    ...report.sbom.components.map((component) => {
      const license = report.licenses.find(
        (entry) => entry.ecosystem === component.ecosystem && entry.name === component.name,
      )?.license ?? "UNKNOWN";
      return `| ${component.ecosystem} | ${component.name} | ${component.version} | ${component.scope} | ${license} |`;
    }),
    "",
    "#### License Summary",
    "",
    ...report.licenses.map((license) => `- ${license.ecosystem}:${license.name} ${license.license} (${license.allowed ? "allowed" : "blocked"})`),
  ];

  if (report.failures.length > 0) {
    lines.push("", "#### Failures", "");
    lines.push(...report.failures.map((failure) => `- ${failure.reason}: ${failure.message}`));
  }

  return `${lines.join("\n")}\n`;
}

function renderConsoleSummary(report) {
  return [
    `status=${report.status}`,
    `components=${report.sbom.components.length}`,
    `licenses=${report.licenses.length}`,
    `failures=${report.failures.length}`,
  ].join("\n");
}

function gitLsFiles() {
  return execFileSync("git", ["ls-files"], { cwd: repoRoot, encoding: "utf8" })
    .split("\n")
    .filter(Boolean);
}

function readJson(path) {
  return JSON.parse(readFileSync(path, "utf8"));
}

function readOptional(path) {
  return readFileSync(resolve(repoRoot, path), "utf8");
}

function parseArgs(rawArgs) {
  const parsed = {
    auditDir: undefined,
    config: undefined,
    reportDir: undefined,
    requireAudits: false,
  };

  for (let index = 0; index < rawArgs.length; index += 1) {
    const arg = rawArgs[index];
    if (arg === "--audit-dir") {
      parsed.auditDir = rawArgs[++index];
    } else if (arg === "--config") {
      parsed.config = rawArgs[++index];
    } else if (arg === "--report-dir") {
      parsed.reportDir = rawArgs[++index];
    } else if (arg === "--require-audits") {
      parsed.requireAudits = true;
    } else {
      failUsage(`Unknown argument: ${arg}`);
    }
  }

  return parsed;
}

function failUsage(message) {
  console.error(message);
  console.error("Usage: node tools/ci/run-release-security-gate.mjs [--report-dir path] [--audit-dir path] [--config path] [--require-audits]");
  process.exit(2);
}
