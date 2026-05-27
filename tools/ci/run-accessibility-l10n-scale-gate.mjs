import { existsSync, mkdirSync, readFileSync, writeFileSync } from "node:fs";
import { isAbsolute, relative, resolve } from "node:path";

const repoRoot = process.cwd();
const args = parseArgs(process.argv.slice(2));
const contractPath = resolvePath(args.config ?? "contracts/accessibility/l10n-scale-gate.json");
const reportDir = resolvePath(args.reportDir ?? "build/reports/accessibility-l10n-scale");
const contract = readJson(contractPath);
const failures = [];

const screens = validateScreens(contract.screens ?? [], contract.storeListingContract, contract.usabilityContract);
failures.push(...screens.failures);

const criteria = validateCriteria(contract.criteria ?? {});
failures.push(...criteria.failures);

const terminology = validateTerminology(contract.terminology ?? []);
failures.push(...terminology.failures);

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
  screens,
  criteria,
  terminology,
  staticEvidence,
  runtimeEvidence,
  failures,
};

mkdirSync(reportDir, { recursive: true });
writeFileSync(resolve(reportDir, "accessibility-l10n-scale-report.json"), `${JSON.stringify(report, null, 2)}\n`);
writeFileSync(resolve(reportDir, "accessibility-l10n-scale-runtime-evidence.json"), `${JSON.stringify(runtimeEvidence, null, 2)}\n`);
writeFileSync(resolve(reportDir, "accessibility-l10n-scale-report.md"), renderMarkdown(report));

if (process.env.GITHUB_STEP_SUMMARY) {
  writeFileSync(process.env.GITHUB_STEP_SUMMARY, `\n${renderMarkdown(report)}\n`, { flag: "a" });
}

console.log(`Accessibility l10n scale report: ${resolve(reportDir, "accessibility-l10n-scale-report.json")}`);
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

function validateScreens(screens, storeListingContract, usabilityContract) {
  const storeListing = readJson(resolvePath(storeListingContract ?? "contracts/store-listing/store-listing.json"));
  const usability = readJson(resolvePath(usabilityContract ?? "tools/ci/mobile-usability-release-criteria.json"));
  const appRoutes = readFileSync(resolvePath("front/lib/app/app_routes.dart"), "utf8");
  const screenshotRoutes = new Set((storeListing.screenshots ?? []).flatMap((set) => (
    (set.captures ?? []).map((capture) => capture.routeKey)
  )));
  const usabilityScreens = new Set((usability.screens ?? []).map((screen) => screen.id));
  const requiredScreens = ["home", "diary", "story", "letter", "consultation", "notifications", "settings", "operations"];
  const screenById = new Map(screens.map((screen) => [screen.id, screen]));
  const screenFailures = [];
  const screenResults = [];

  for (const requiredScreen of requiredScreens) {
    if (!screenById.has(requiredScreen)) {
      screenFailures.push({
        reason: "missing_accessibility_answer",
        message: `Missing accessibility screen contract for '${requiredScreen}'.`,
        screenId: requiredScreen,
      });
    }
  }

  for (const screen of screens) {
    const failures = [];
    const appRoutePattern = new RegExp(`key: '${escapeRegExp(screen.routeKey ?? "")}'`, "m");
    if (!screen.routeKey || (!screenshotRoutes.has(screen.routeKey) && !appRoutePattern.test(appRoutes))) {
      failures.push({
        reason: "missing_accessibility_answer",
        message: `Screen '${screen.id}' does not map to a store screenshot or app route.`,
        screenId: screen.id,
        routeKey: screen.routeKey,
      });
    }
    if (!usabilityScreens.has(screen.id)) {
      failures.push({
        reason: "missing_accessibility_answer",
        message: `Screen '${screen.id}' is missing from the usability contract.`,
        screenId: screen.id,
      });
    }
    if ((screen.semanticLabels ?? []).length === 0) {
      failures.push({
        reason: "missing_accessibility_answer",
        message: `Screen '${screen.id}' must declare semantic labels.`,
        screenId: screen.id,
      });
    }
    if (screen.screenshotCandidate !== true) {
      failures.push({
        reason: "missing_accessibility_answer",
        message: `Screen '${screen.id}' must be marked as a screenshot candidate.`,
        screenId: screen.id,
      });
    }

    const evidence = validateEvidenceGroup(`screen:${screen.id}`, screen.evidenceItems ?? []);
    failures.push(...evidence.failures);
    screenFailures.push(...failures);
    screenResults.push({
      id: screen.id,
      routeKey: screen.routeKey,
      screenshotCandidate: screen.screenshotCandidate,
      semanticLabels: screen.semanticLabels ?? [],
      status: failures.length === 0 ? "pass" : "fail",
      evidence,
      failures,
    });
  }

  return {
    status: screenFailures.length === 0 ? "pass" : "fail",
    screens: screenResults,
    failures: screenFailures,
  };
}

function validateCriteria(criteria) {
  const requiredCriteria = ["screenReader", "textScale", "contrast", "touchTarget", "keyboardAutofill"];
  const criteriaFailures = [];
  const results = {};

  for (const criteriaId of requiredCriteria) {
    const criterion = criteria[criteriaId];
    if (!criterion) {
      criteriaFailures.push({
        reason: "missing_accessibility_answer",
        message: `Missing accessibility criterion '${criteriaId}'.`,
        criteriaId,
      });
      continue;
    }

    const failures = [];
    if (!criterion.owner || criterion.owner.trim().length === 0) {
      failures.push({
        reason: "missing_accessibility_answer",
        message: `Criterion '${criteriaId}' must declare an owner.`,
        criteriaId,
      });
    }
    if (!criterion.rule || criterion.rule.trim().length === 0) {
      failures.push({
        reason: "missing_accessibility_answer",
        message: `Criterion '${criteriaId}' must declare a rule.`,
        criteriaId,
      });
    }
    if (criteriaId === "textScale" && !sameNumberSet(criterion.requiredScales ?? [], [1, 1.5, 2])) {
      failures.push({
        reason: "missing_accessibility_answer",
        message: "Text scale criterion must cover 100%, 150%, and 200%.",
        criteriaId,
      });
    }
    if (criteriaId === "touchTarget" && Number(criterion.minimumDp) < 48) {
      failures.push({
        reason: "missing_accessibility_answer",
        message: "Touch target criterion must require at least 48dp.",
        criteriaId,
      });
    }
    if (criteriaId === "contrast" && (Number(criterion.minimumNormalTextRatio) < 4.5 || Number(criterion.minimumLargeTextRatio) < 3)) {
      failures.push({
        reason: "missing_accessibility_answer",
        message: "Contrast criterion must require at least 4.5:1 normal and 3:1 large text.",
        criteriaId,
      });
    }

    const evidence = validateEvidenceGroup(`criteria:${criteriaId}`, criterion.evidenceItems ?? []);
    failures.push(...evidence.failures);
    criteriaFailures.push(...failures);
    results[criteriaId] = {
      status: failures.length === 0 ? "pass" : "fail",
      owner: criterion.owner,
      rule: criterion.rule,
      evidence,
      failures,
    };
  }

  return {
    status: criteriaFailures.length === 0 ? "pass" : "fail",
    criteria: results,
    failures: criteriaFailures,
  };
}

function validateTerminology(terms) {
  const termFailures = [];
  const termResults = [];

  for (const term of terms) {
    const failures = [];
    if (!term.id || !term.canonical || term.canonical.trim().length === 0) {
      failures.push({
        reason: "term_mismatch",
        message: `Terminology entry '${term.id ?? "unknown"}' must declare a canonical term.`,
        termId: term.id,
      });
    }

    const evidence = validateEvidenceGroup(`term:${term.id ?? "unknown"}`, term.evidenceItems ?? [], {
      canonicalTerm: term.canonical,
      failureReason: "term_mismatch",
    });
    failures.push(...evidence.failures);
    termFailures.push(...failures);
    termResults.push({
      id: term.id,
      canonical: term.canonical,
      status: failures.length === 0 ? "pass" : "fail",
      evidence,
      failures,
    });
  }

  if (terms.length < 8) {
    termFailures.push({
      reason: "term_mismatch",
      message: "At least eight canonical Korean terms are required.",
    });
  }

  return {
    status: termFailures.length === 0 ? "pass" : "fail",
    terms: termResults,
    failures: termFailures,
  };
}

function validateStaticEvidence(groups) {
  const groupFailures = [];
  const groupResults = [];

  for (const group of groups) {
    const failures = [];
    if (!group.id || !group.owner) {
      failures.push({
        reason: "missing_static_evidence",
        message: `Static evidence group '${group.id ?? "unknown"}' must declare id and owner.`,
        groupId: group.id,
      });
    }
    const evidence = validateEvidenceGroup(`static:${group.id ?? "unknown"}`, group.evidenceItems ?? []);
    failures.push(...evidence.failures);
    groupFailures.push(...failures);
    groupResults.push({
      id: group.id,
      owner: group.owner,
      status: failures.length === 0 ? "pass" : "fail",
      evidence,
      failures,
    });
  }

  if (groups.length === 0) {
    groupFailures.push({
      reason: "missing_static_evidence",
      message: "At least one static accessibility evidence group is required.",
    });
  }

  return {
    status: groupFailures.length === 0 ? "pass" : "fail",
    groups: groupResults,
    failures: groupFailures,
  };
}

function validateEvidenceGroup(groupId, items, options = {}) {
  const evidenceItems = items.map((item) => validateEvidenceItem(groupId, item, options));
  const groupFailures = evidenceItems.flatMap((item) => item.failures);

  if (items.length === 0) {
    groupFailures.push({
      reason: options.failureReason ?? "missing_static_evidence",
      message: `Evidence group '${groupId}' must declare at least one item.`,
      groupId,
    });
  }

  return {
    status: groupFailures.length === 0 ? "pass" : "fail",
    evidenceItems,
    failures: groupFailures,
  };
}

function validateEvidenceItem(groupId, item, options = {}) {
  const reason = options.failureReason ?? "missing_static_evidence";
  const failures = [];
  const filePath = resolvePath(item.file);
  const fileExists = Boolean(item.file) && existsSync(filePath);
  const content = fileExists ? readFileSync(filePath, "utf8") : "";
  const patternResults = (item.patterns ?? []).map((pattern) => {
    const matched = fileExists && new RegExp(pattern, "m").test(content);
    if (!matched && item.required !== false) {
      failures.push({
        reason,
        message: `Evidence '${item.id ?? "unknown"}' is missing pattern '${pattern}' in ${item.file ?? "unknown"}.`,
        groupId,
        itemId: item.id,
        file: item.file,
        pattern,
      });
    }
    return { pattern, matched };
  });

  if (!item.id || item.id.trim().length === 0) {
    failures.push({
      reason,
      message: `Evidence item in group '${groupId}' is missing id.`,
      groupId,
    });
  }
  if (!fileExists && item.required !== false) {
    failures.push({
      reason,
      message: `Evidence '${item.id ?? "unknown"}' file does not exist: ${item.file ?? "unknown"}`,
      groupId,
      itemId: item.id,
      file: item.file,
    });
  }
  if ((item.patterns ?? []).length === 0 && item.required !== false) {
    failures.push({
      reason,
      message: `Evidence '${item.id ?? "unknown"}' must declare at least one pattern.`,
      groupId,
      itemId: item.id,
    });
  }
  if (options.canonicalTerm && fileExists && !content.includes(options.canonicalTerm)) {
    failures.push({
      reason: "term_mismatch",
      message: `Evidence '${item.id ?? "unknown"}' does not contain canonical term '${options.canonicalTerm}'.`,
      groupId,
      itemId: item.id,
      canonicalTerm: options.canonicalTerm,
    });
  }

  return {
    id: item.id,
    file: item.file,
    status: failures.length === 0 ? "pass" : "fail",
    patterns: patternResults,
    failures,
  };
}

function validateRuntimeEvidence(config) {
  const runtimeDir = resolvePath(args.runtimeEvidenceDir ?? config.defaultDirectory ?? "contracts/accessibility/runtime-evidence");
  const requireRuntimeEvidence = args.requireRuntimeEvidence === true;

  if (!requireRuntimeEvidence && !existsSync(runtimeDir)) {
    return {
      status: "not_required",
      directory: relativeDisplayPath(runtimeDir),
      files: [],
      failures: [],
    };
  }

  const files = [];
  const runtimeFailures = [];

  for (const requiredFile of config.requiredFiles ?? []) {
    const filePath = resolve(runtimeDir, requiredFile.filename);
    if (!existsSync(filePath)) {
      const failure = {
        reason: "missing_runtime_evidence",
        message: `Missing required accessibility runtime evidence file: ${requiredFile.filename}`,
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
    const scenarioById = new Map((evidence.scenarios ?? []).map((scenario) => [scenario.id, scenario]));
    const fileFailures = [];
    const scenarioResults = [];

    for (const scenarioId of requiredFile.requiredScenarios ?? []) {
      const scenario = scenarioById.get(scenarioId);
      if (!scenario) {
        fileFailures.push({
          reason: "missing_runtime_evidence",
          message: `Missing required runtime scenario '${scenarioId}' in ${requiredFile.filename}`,
          file: requiredFile.filename,
          scenarioId,
        });
        continue;
      }
      if (scenario.status !== "pass") {
        fileFailures.push({
          reason: "runtime_accessibility_smoke_failed",
          message: `Runtime accessibility scenario '${scenarioId}' did not pass in ${requiredFile.filename}.`,
          file: requiredFile.filename,
          scenarioId,
          status: scenario.status,
        });
      }
      if (!scenario.evidenceUrl || scenario.evidenceUrl.trim().length === 0) {
        fileFailures.push({
          reason: "missing_runtime_evidence",
          message: `Runtime accessibility scenario '${scenarioId}' is missing evidenceUrl in ${requiredFile.filename}.`,
          file: requiredFile.filename,
          scenarioId,
        });
      }
      scenarioResults.push({
        id: scenarioId,
        status: scenario.status,
        evidenceUrl: scenario.evidenceUrl,
      });
    }

    runtimeFailures.push(...fileFailures);
    files.push({
      id: requiredFile.id,
      filename: requiredFile.filename,
      status: fileFailures.length === 0 ? "pass" : "fail",
      scenarios: scenarioResults,
      generatedAt: evidence.generatedAt,
      failures: fileFailures,
    });
  }

  return {
    status: runtimeFailures.length === 0 ? "pass" : "fail",
    directory: relativeDisplayPath(runtimeDir),
    required: requireRuntimeEvidence,
    files,
    failures: runtimeFailures,
  };
}

function sameNumberSet(left, right) {
  return left.length === right.length && left.every((value) => right.includes(value));
}

function readJson(filePath) {
  return JSON.parse(readFileSync(filePath, "utf8"));
}

function resolvePath(value) {
  if (!value || typeof value !== "string") {
    return repoRoot;
  }
  return isAbsolute(value) ? value : resolve(repoRoot, value);
}

function relativeDisplayPath(value) {
  const resolved = resolvePath(value);
  const display = relative(repoRoot, resolved);
  return display && !display.startsWith("..") ? display : resolved;
}

function renderConsoleSummary(report) {
  return [
    `status=${report.status}`,
    `screens=${report.screens.status}`,
    `criteria=${report.criteria.status}`,
    `terminology=${report.terminology.status}`,
    `staticEvidence=${report.staticEvidence.status}`,
    `runtimeEvidence=${report.runtimeEvidence.status}`,
    `failures=${report.failures.length}`,
  ].join("\n");
}

function renderMarkdown(report) {
  const lines = [
    "# Accessibility L10n Scale",
    "",
    `- Status: ${report.status}`,
    `- Contract: ${report.contract.path}`,
    `- Release blockers: ${report.releaseBlockers.join(", ")}`,
    "",
    "## Core Screens",
    "",
    `- Status: ${report.screens.status}`,
    ...report.screens.screens.map((screen) => `- ${screen.id}: ${screen.status}`),
    "",
    "## Criteria",
    "",
    `- Status: ${report.criteria.status}`,
    ...Object.entries(report.criteria.criteria).map(([id, result]) => `- ${id}: ${result.status}`),
    "",
    "## Terminology",
    "",
    `- Status: ${report.terminology.status}`,
    ...report.terminology.terms.map((term) => `- ${term.id}: ${term.status} (${term.canonical})`),
    "",
    "## Runtime Evidence",
    "",
    `- Status: ${report.runtimeEvidence.status}`,
    `- Directory: ${report.runtimeEvidence.directory}`,
  ];

  if (report.failures.length > 0) {
    lines.push("", "## Failures", "");
    for (const failure of report.failures) {
      lines.push(`- ${failure.reason}: ${failure.message}`);
    }
  }

  return `${lines.join("\n")}\n`;
}

function parseArgs(values) {
  const parsed = {};
  for (let index = 0; index < values.length; index += 1) {
    const value = values[index];
    if (!value.startsWith("--")) {
      continue;
    }
    const key = value
      .slice(2)
      .replace(/-([a-z])/g, (_, character) => character.toUpperCase());
    const next = values[index + 1];
    if (!next || next.startsWith("--")) {
      parsed[key] = true;
      continue;
    }
    parsed[key] = next;
    index += 1;
  }
  return parsed;
}

function escapeRegExp(value) {
  return value.replace(/[.*+?^${}()|[\]\\]/g, "\\$&");
}
