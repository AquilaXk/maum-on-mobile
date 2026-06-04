import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import { test } from "node:test";

const applicationYaml = readFileSync("back/src/main/resources/application.yml", "utf8");

test("backend readiness health does not depend on optional SMTP by default", () => {
  assert.match(
    applicationYaml,
    /^management:\n(?:  [^\n]*\n)*  health:\n(?:    [^\n]*\n)*    mail:\n(?:      [^\n]*\n)*      enabled: \${MANAGEMENT_HEALTH_MAIL_ENABLED:false}/m,
  );
});
