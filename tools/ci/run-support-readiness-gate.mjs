import { existsSync, mkdirSync, readFileSync, writeFileSync } from "node:fs";
import { isAbsolute, relative, resolve } from "node:path";

const repoRoot = process.cwd();
const args = parseArgs(process.argv.slice(2));
const contractPath = resolvePath(args.config ?? "contracts/support/release-support-readiness.json");
const reportDir = resolvePath(args.reportDir ?? "build/reports/support-readiness");
const contract = readJson(contractPath);
const failures = [];

const contacts = validateContacts(contract.contacts ?? {});
failures.push(...contacts.failures);

const reviewResponse = validateReviewResponse(contract.reviewResponse ?? {}, contract.contacts ?? {});
failures.push(...reviewResponse.failures);

const diagnostics = validateDiagnostics(contract.diagnostics ?? {});
failures.push(...diagnostics.failures);

const staticEvidence = validateStaticEvidence(contract.staticEvidence ?? []);
failures.push(...staticEvidence.failures);

const runtimeEvidence = validateRuntimeEvidence(contract.runtimeEvidence ?? {});
failures.push(...runtimeEvidence.failures);

const report = {
  status: failures.length === 0 ? "pass" : "blocked",
  generatedAt: new Date().toISOString(),
  contract: {
    path: relativeDisplayPath(contractPath),
    version: contract.version,
  },
  releaseBlockers: contract.releaseBlockers ?? [],
  contacts,
  reviewResponse,
  diagnostics,
  staticEvidence,
  runtimeEvidence,
  failures,
};

mkdirSync(reportDir, { recursive: true });
writeFileSync(resolve(reportDir, "support-readiness-report.json"), `${JSON.stringify(report, null, 2)}\n`);
writeFileSync(resolve(reportDir, "support-readiness-runtime-evidence.json"), `${JSON.stringify(runtimeEvidence, null, 2)}\n`);
writeFileSync(resolve(reportDir, "support-readiness-report.md"), renderMarkdown(report));

if (process.env.GITHUB_STEP_SUMMARY) {
  writeFileSync(process.env.GITHUB_STEP_SUMMARY, `\n${renderMarkdown(report)}\n`, { flag: "a" });
}

console.log(`Support readiness report: ${resolve(reportDir, "support-readiness-report.json")}`);
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

function validateContacts(contacts) {
  const contactFailures = [];
  const storeListing = readJson(resolvePath(contract.storeListingContract ?? "contracts/store-listing/store-listing.json"));
  const storePrivacy = readJson(resolvePath(contract.storePrivacyContract ?? "contracts/store-privacy/data-safety.json"));
  const legal = readText("front/lib/features/legal/domain/legal_disclosures.dart");

  for (const field of ["supportEmail", "privacyEmail", "supportUrl", "privacyPolicyUrl", "termsUrl", "incidentNoticeUrl"]) {
    if (!nonEmpty(contacts[field])) {
      contactFailures.push({
        reason: "missing_support_contact",
        message: `Support contact field '${field}' is missing.`,
        field,
      });
    }
  }

  if (nonEmpty(contacts.supportEmail) && !/^[^@\s]+@[^@\s]+\.[^@\s]+$/.test(contacts.supportEmail)) {
    contactFailures.push({
      reason: "missing_support_contact",
      message: "Support email is not a valid email address.",
      field: "supportEmail",
    });
  }

  if (nonEmpty(contacts.privacyEmail) && !/^[^@\s]+@[^@\s]+\.[^@\s]+$/.test(contacts.privacyEmail)) {
    contactFailures.push({
      reason: "missing_support_contact",
      message: "Privacy email is not a valid email address.",
      field: "privacyEmail",
    });
  }

  const expectedMatches = [
    ["store listing support email", contacts.supportEmail, storeListing.links?.supportEmail],
    ["Google Play support email", contacts.supportEmail, storeListing.googlePlay?.supportEmail],
    ["store privacy support email", contacts.supportEmail, storePrivacy.storeLinks?.supportEmail],
    ["store listing support URL", contacts.supportUrl, storeListing.links?.supportUrl],
    ["App Store support URL", contacts.supportUrl, storeListing.appStore?.supportUrl],
    ["store listing privacy policy URL", contacts.privacyPolicyUrl, storeListing.links?.privacyPolicyUrl],
    ["store privacy policy URL", contacts.privacyPolicyUrl, storePrivacy.storeLinks?.privacyPolicyUrl],
    ["store terms URL", contacts.termsUrl, storeListing.links?.termsUrl],
  ];
  for (const [label, actual, expected] of expectedMatches) {
    if (actual !== expected) {
      contactFailures.push({
        reason: "support_contact_mismatch",
        message: `${label} does not match the support contract.`,
        actual,
        expected,
      });
    }
  }

  for (const value of [
    contacts.supportEmail,
    contacts.privacyEmail,
    contacts.supportUrl,
    contacts.privacyPolicyUrl,
    contacts.termsUrl,
    contacts.incidentNoticeUrl,
  ]) {
    if (nonEmpty(value) && !legal.includes(value)) {
      contactFailures.push({
        reason: "support_contact_mismatch",
        message: `Legal disclosure source does not include '${value}'.`,
        value,
      });
    }
  }

  return {
    status: contactFailures.length === 0 ? "pass" : "fail",
    ...contacts,
    failures: contactFailures,
  };
}

function validateReviewResponse(reviewResponse, contacts) {
  const reviewFailures = [];
  for (const field of ["owner", "contactEmail", "appStoreReviewStatus", "googlePlayReviewStatus"]) {
    if (!nonEmpty(reviewResponse[field])) {
      reviewFailures.push({
        reason: "missing_support_contact",
        message: `Review response field '${field}' is missing.`,
        field,
      });
    }
  }
  if (reviewResponse.contactEmail !== contacts.supportEmail) {
    reviewFailures.push({
      reason: "support_contact_mismatch",
      message: "Review response contact email must match support email.",
      actual: reviewResponse.contactEmail,
      expected: contacts.supportEmail,
    });
  }
  if (Number(reviewResponse.responseSlaHours) <= 0 || Number(reviewResponse.responseSlaHours) > 24) {
    reviewFailures.push({
      reason: "missing_support_contact",
      message: "Review response SLA must be between 1 and 24 hours.",
      field: "responseSlaHours",
    });
  }
  if (reviewResponse.incidentNoticeRequired !== true) {
    reviewFailures.push({
      reason: "missing_support_contact",
      message: "Review response contract must require an incident notice path.",
      field: "incidentNoticeRequired",
    });
  }

  return {
    status: reviewFailures.length === 0 ? "pass" : "fail",
    ...reviewResponse,
    failures: reviewFailures,
  };
}

function validateDiagnostics(diagnostics) {
  const diagnosticFailures = [];
  const requiredFields = diagnostics.requiredFields ?? [];
  const forbiddenFields = diagnostics.forbiddenFields ?? [];

  for (const field of ["appVersion", "buildNumber", "platform", "locale"]) {
    if (!requiredFields.includes(field)) {
      diagnosticFailures.push({
        reason: "missing_static_evidence",
        message: `Diagnostics must include safe field '${field}'.`,
        field,
      });
    }
  }

  for (const field of ["email", "memberId", "token", "password", "authorization"]) {
    if (!forbiddenFields.includes(field)) {
      diagnosticFailures.push({
        reason: "missing_static_evidence",
        message: `Diagnostics must explicitly forbid sensitive field '${field}'.`,
        field,
      });
    }
  }

  return {
    status: diagnosticFailures.length === 0 ? "pass" : "fail",
    requiredFields,
    forbiddenFields,
    failures: diagnosticFailures,
  };
}

function validateStaticEvidence(items) {
  const evidenceItems = items.map(validateEvidenceItem);
  const evidenceFailures = evidenceItems.flatMap((item) => item.failures);
  if (items.length === 0) {
    evidenceFailures.push({
      reason: "missing_static_evidence",
      message: "At least one static evidence item is required.",
    });
  }

  return {
    status: evidenceFailures.length === 0 ? "pass" : "fail",
    evidenceItems,
    failures: evidenceFailures,
  };
}

function validateEvidenceItem(item) {
  const itemFailures = [];
  const filePath = resolvePath(item.file);
  const fileExists = existsSync(filePath);
  const content = fileExists ? readFileSync(filePath, "utf8") : "";
  const patterns = item.patterns ?? [];
  const patternResults = patterns.map((pattern) => {
    const matched = fileExists && new RegExp(pattern, "m").test(content);
    if (!matched) {
      itemFailures.push({
        reason: "missing_static_evidence",
        message: `Evidence '${item.id}' is missing pattern '${pattern}' in ${item.file}.`,
        itemId: item.id,
        file: item.file,
        pattern,
      });
    }
    return { pattern, matched };
  });

  if (!fileExists) {
    itemFailures.push({
      reason: "missing_static_evidence",
      message: `Evidence '${item.id}' file does not exist: ${item.file}`,
      itemId: item.id,
      file: item.file,
    });
  }
  if (patterns.length === 0) {
    itemFailures.push({
      reason: "missing_static_evidence",
      message: `Evidence '${item.id}' must declare at least one pattern.`,
      itemId: item.id,
    });
  }

  return {
    id: item.id,
    file: item.file,
    status: itemFailures.length === 0 ? "pass" : "fail",
    patterns: patternResults,
    failures: itemFailures,
  };
}

function validateRuntimeEvidence(config) {
  const runtimeDir = resolvePath(args.runtimeEvidenceDir ?? config.defaultDirectory ?? "contracts/support/runtime-evidence");
  const requireRuntimeEvidence = args.requireRuntimeEvidence === true;

  if (!requireRuntimeEvidence && !existsSync(runtimeDir)) {
    return {
      status: "not_required",
      directory: relativeDisplayPath(runtimeDir),
      files: [],
      failures: [],
    };
  }

  const runtimeFailures = [];
  const files = [];

  for (const requiredFile of config.requiredFiles ?? []) {
    const filePath = resolve(runtimeDir, requiredFile.filename);
    if (!existsSync(filePath)) {
      const failure = {
        reason: "missing_runtime_evidence",
        message: `Missing required support runtime evidence file: ${requiredFile.filename}`,
        file: requiredFile.filename,
      };
      if (requireRuntimeEvidence) {
        runtimeFailures.push(failure);
      }
      files.push({
        id: requiredFile.id,
        filename: requiredFile.filename,
        status: "missing",
        scenarios: [],
        failures: requireRuntimeEvidence ? [failure] : [],
      });
      continue;
    }

    const evidence = readJson(filePath);
    const scenarios = evidence.scenarios ?? [];
    const scenarioById = new Map(scenarios.map((scenario) => [scenario.id, scenario]));
    const fileFailures = [];

    for (const scenarioId of requiredFile.requiredScenarios ?? []) {
      const scenario = scenarioById.get(scenarioId);
      if (!scenario) {
        fileFailures.push({
          reason: "missing_runtime_evidence",
          message: `Missing required support runtime scenario '${scenarioId}' in ${requiredFile.filename}`,
          file: requiredFile.filename,
          scenarioId,
        });
        continue;
      }
      if (scenario.status !== "pass") {
        fileFailures.push({
          reason: "runtime_support_flow_failed",
          message: `Support runtime scenario '${scenarioId}' did not pass in ${requiredFile.filename}.`,
          file: requiredFile.filename,
          scenarioId,
          status: scenario.status,
        });
      }
    }

    runtimeFailures.push(...fileFailures);
    files.push({
      id: requiredFile.id,
      filename: requiredFile.filename,
      status: fileFailures.length === 0 ? "pass" : "fail",
      scenarios,
      failures: fileFailures,
    });
  }

  return {
    status: runtimeFailures.length === 0 ? "pass" : "fail",
    directory: relativeDisplayPath(runtimeDir),
    files,
    failures: runtimeFailures,
  };
}

function renderMarkdown(report) {
  const lines = [
    "# Support Readiness Gate",
    "",
    `Status: ${report.status}`,
    `Generated: ${report.generatedAt}`,
    "",
    "## Support Contacts",
    "",
    `- supportEmail: ${report.contacts.supportEmail ?? "-"}`,
    `- privacyEmail: ${report.contacts.privacyEmail ?? "-"}`,
    `- incidentNoticeUrl: ${report.contacts.incidentNoticeUrl ?? "-"}`,
    "",
    "## Review Response",
    "",
    `- owner: ${report.reviewResponse.owner ?? "-"}`,
    `- contactEmail: ${report.reviewResponse.contactEmail ?? "-"}`,
    `- responseSlaHours: ${report.reviewResponse.responseSlaHours ?? "-"}`,
    "",
    "## Diagnostics",
    "",
    `- requiredFields: ${(report.diagnostics.requiredFields ?? []).join(", ")}`,
    `- forbiddenFields: ${(report.diagnostics.forbiddenFields ?? []).join(", ")}`,
    "",
    "## Runtime Evidence",
    "",
    `- status: ${report.runtimeEvidence.status}`,
    `- directory: ${report.runtimeEvidence.directory}`,
    "",
    "## Failures",
    "",
  ];

  if (report.failures.length === 0) {
    lines.push("- none");
  } else {
    for (const failure of report.failures) {
      lines.push(`- ${failure.reason}: ${failure.message}`);
    }
  }

  return `${lines.join("\n")}\n`;
}

function renderConsoleSummary(report) {
  return [
    `status=${report.status}`,
    `contacts=${report.contacts.status}`,
    `reviewResponse=${report.reviewResponse.status}`,
    `diagnostics=${report.diagnostics.status}`,
    `staticEvidence=${report.staticEvidence.status}`,
    `runtimeEvidence=${report.runtimeEvidence.status}`,
    `failures=${report.failures.length}`,
  ].join(" ");
}

function readJson(pathValue) {
  return JSON.parse(readFileSync(pathValue, "utf8"));
}

function readText(relativePath) {
  return readFileSync(resolvePath(relativePath), "utf8");
}

function resolvePath(pathValue) {
  if (isAbsolute(pathValue)) {
    return pathValue;
  }
  return resolve(repoRoot, pathValue);
}

function relativeDisplayPath(pathValue) {
  return relative(repoRoot, pathValue) || ".";
}

function nonEmpty(value) {
  return typeof value === "string" && value.trim().length > 0;
}

function parseArgs(argv) {
  const parsed = {};
  for (let index = 0; index < argv.length; index += 1) {
    const arg = argv[index];
    if (!arg.startsWith("--")) {
      continue;
    }
    const key = toCamelCase(arg.slice(2));
    const next = argv[index + 1];
    if (!next || next.startsWith("--")) {
      parsed[key] = true;
    } else {
      parsed[key] = next;
      index += 1;
    }
  }
  return parsed;
}

function toCamelCase(value) {
  return value.replace(/-([a-z])/g, (_, character) => character.toUpperCase());
}
