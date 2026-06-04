import assert from "node:assert/strict";
import { existsSync, readFileSync } from "node:fs";
import path from "node:path";
import test from "node:test";

const root = process.cwd();

function read(relativePath) {
  return readFileSync(path.join(root, relativePath), "utf8");
}

test("backend runtime image is built from a tracked Dockerfile", () => {
  const dockerfilePath = "back/Dockerfile";

  assert.ok(existsSync(path.join(root, dockerfilePath)), "back/Dockerfile must exist");

  const dockerfile = read(dockerfilePath);

  assert.match(dockerfile, /^FROM eclipse-temurin:21-jre-jammy$/m);
  assert.match(dockerfile, /groupadd --system --gid 10001 maumon/);
  assert.match(dockerfile, /useradd --system --uid 10001 --gid maumon/);
  assert.match(dockerfile, /^USER maumon$/m);
  assert.match(dockerfile, /^HEALTHCHECK --interval=30s --timeout=5s --start-period=40s --retries=5/m);
  assert.match(dockerfile, /\/actuator\/health/);
  assert.match(dockerfile, /^ENTRYPOINT \["java", "-jar", "\/app\/maum-on-mobile-back\.jar"\]$/m);
  assert.doesNotMatch(dockerfile, /COPY .*\.env/);
  assert.doesNotMatch(dockerfile, /BEGIN [A-Z ]*PRIVATE KEY/);
});

test("OCI runtime deploy script is safe, idempotent, and verifies health", () => {
  const scriptPath = "tools/deploy/deploy-oci-a1-backend.sh";

  assert.ok(existsSync(path.join(root, scriptPath)), `${scriptPath} must exist`);

  const script = read(scriptPath);

  assert.match(script, /^set -euo pipefail$/m);
  assert.match(script, /required_vars=\(/);
  assert.match(script, /OCI_A1_SSH_HOST/);
  assert.match(script, /OCI_A1_BACKEND_ENV_B64/);
  assert.match(script, /OCI_A1_VERTEX_KEY_JSON_B64/);
  assert.match(script, /Invalid MAUMON_BACKEND_IMAGE_TAG/);
  assert.match(script, /docker_network="\$\{MAUMON_DOCKER_NETWORK:-maum-on-mobile\}"/);
  assert.match(script, /app_data_dir="\$\{MAUMON_APP_DATA_DIR:-\/var\/lib\/maumon-data\/app\}"/);
  assert.match(script, /Invalid MAUMON_DOCKER_NETWORK/);
  assert.match(script, /Invalid MAUMON_APP_DATA_DIR/);
  assert.match(script, /Invalid MAUMON_POSTGRES_CONTAINER_NAME/);
  assert.match(script, /Invalid MAUMON_POSTGRES_DATA_VOLUME/);
  assert.match(script, /Invalid MAUMON_POSTGRES_IMAGE_TAG/);
  assert.match(script, /Invalid MAUMON_DEPLOY_MANAGED_POSTGRES/);
  assert.match(script, /Invalid MAUMON_HOST_HTTP_PORT/);
  assert.match(script, /Invalid MAUMON_DEPLOY_HEALTH_TIMEOUT_SECONDS/);
  assert.match(script, /Invalid GITHUB_RUN_ID/);
  assert.match(script, /Invalid GITHUB_RUN_ATTEMPT/);
  assert.match(script, /tar -xzf "\$\{bundle_path\}" -C "\$\{release_dir\}"/);
  assert.match(script, /docker build -t "\$\{image_tag\}" -f "\$\{release_dir\}\/Dockerfile" "\$\{release_dir\}"/);
  assert.match(script, /container_uid="10001"/);
  assert.match(script, /chown "\$\{container_uid\}:\$\{container_gid\}" "\$\{vertex_key_file\}"/);
  assert.match(
    script,
    /MAUMON_DOCKER_NETWORK='\$\{docker_network\}' MAUMON_APP_DATA_DIR='\$\{app_data_dir\}'/,
  );
  assert.match(script, /MAUMON_DEPLOY_HEALTH_TIMEOUT_SECONDS='\$\{deploy_health_timeout_seconds\}'/);
  assert.match(script, /MAUMON_HOST_HTTP_PORT='\$\{host_http_port\}'/);
  assert.match(script, /remote_staging="\/tmp\/maum-on-mobile-deploy-\$\{deploy_run_id\}-\$\{deploy_run_attempt\}"/);
  assert.match(script, /\ninstall_runtime\n[\s\S]*\nprepare_runtime_resources\nallow_host_http_ingress\nprepare_managed_postgres\n\nsudo docker build/);
  assert.match(script, /container_name="maum-on-mobile-back"/);
  assert.match(script, /previous_container_name="maum-on-mobile-back-previous"/);
  assert.match(script, /network_name="\$\{MAUMON_DOCKER_NETWORK:-maum-on-mobile\}"/);
  assert.match(script, /app_data_dir="\$\{MAUMON_APP_DATA_DIR:-\/var\/lib\/maumon-data\/app\}"/);
  assert.match(script, /postgres_container_name="\$\{MAUMON_POSTGRES_CONTAINER_NAME:-maum-on-mobile-postgres\}"/);
  assert.match(script, /postgres_data_volume="\$\{MAUMON_POSTGRES_DATA_VOLUME:-maum-on-mobile-postgres-data\}"/);
  assert.match(script, /postgres_image_tag="\$\{MAUMON_POSTGRES_IMAGE_TAG:-postgres:16-alpine\}"/);
  assert.match(script, /host_http_port="\$\{MAUMON_HOST_HTTP_PORT:-80\}"/);
  assert.match(script, /docker network inspect "\$\{network_name\}"/);
  assert.match(script, /docker network create "\$\{network_name\}"/);
  assert.match(script, /install -d -m 0750 -o "\$\{container_uid\}" -g "\$\{container_gid\}" "\$\{app_data_dir\}"/);
  assert.match(script, /allow_host_http_ingress/);
  assert.match(script, /iptables -C INPUT -p tcp --dport "\$\{host_http_port\}" -j ACCEPT/);
  assert.match(script, /iptables -I INPUT \d+ -p tcp --dport "\$\{host_http_port\}" -j ACCEPT/);
  assert.match(script, /docker volume create "\$\{postgres_data_volume\}"/);
  assert.match(script, /--network-alias postgres/);
  assert.match(script, /POSTGRES_DB="\$\{db_name\}"/);
  assert.match(script, /pg_isready -U "\$\{db_username\}" -d "\$\{db_name\}"/);
  assert.match(script, /sudo awk -v key="\$\{key\}"/);
  assert.match(script, /docker stop "\$\{container_name\}"/);
  assert.match(script, /--network "\$\{network_name\}"/);
  assert.match(script, /--env-file "\$\{env_file\}"/);
  assert.match(script, /--publish "\$\{host_http_port\}:8080"/);
  assert.match(script, /--mount type=bind,source="\$\{app_data_dir\}",target=\/app\/data/);
  assert.match(script, /--mount type=bind,source="\$\{vertex_key_file\}",target=\/run\/secrets\/vertex-key\.json,readonly/);
  assert.match(script, /--health-cmd 'curl -fsS http:\/\/127\.0\.0\.1:8080\/actuator\/health \|\| exit 1'/);
  assert.match(script, /curl -fsS "http:\/\/127\.0\.0\.1:\$\{host_http_port\}\/actuator\/health"/);
  assert.match(script, /docker rm "\$\{previous_container_name\}"/);
  assert.match(script, /install -d -m 0700 '\$\{remote_staging\}'/);
  assert.match(script, /cleanup_remote_staging\(\)/);
  assert.match(script, /rm -f "\$\{staging_dir\}\/backend\.env" "\$\{staging_dir\}\/vertex-key\.json" "\$\{bundle_path\}"/);
  assert.match(script, /trap cleanup_remote_staging EXIT/);
  assert.match(script, /if ! sudo docker run/);
  assert.match(script, /rollback/);
  assert.doesNotMatch(script, /set -x/);
});

test("manual GitHub Actions deploy workflow builds jar, bundles it, and deploys over SSH", () => {
  const workflowPath = ".github/workflows/deploy-oci-a1.yml";

  assert.ok(existsSync(path.join(root, workflowPath)), `${workflowPath} must exist`);

  const workflow = read(workflowPath);

  assert.match(workflow, /^name: Deploy OCI A1 Backend$/m);
  assert.match(workflow, /workflow_dispatch:/);
  assert.match(workflow, /environment:/);
  assert.match(workflow, /name: \$\{\{ inputs\.environment \}\}/);
  assert.match(workflow, /permissions:\n  contents: read/);
  assert.match(workflow, /concurrency:/);
  assert.match(workflow, /uses: actions\/checkout@[a-f0-9]{40}/);
  assert.match(workflow, /persist-credentials: false/);
  assert.match(workflow, /uses: actions\/setup-java@[a-f0-9]{40}/);
  assert.match(workflow, /java-version: "21"/);
  assert.match(workflow, /working-directory: back/);
  assert.match(workflow, /\.\/gradlew --no-daemon test bootJar/);
  assert.match(workflow, /cp back\/Dockerfile build\/deploy-oci-a1\/Dockerfile/);
  assert.match(workflow, /tar -czf build\/maum-on-mobile-backend-bundle\.tar\.gz -C build\/deploy-oci-a1 \./);
  assert.match(workflow, /name: Compose backend env/);
  assert.match(workflow, /append_or_replace_env\(\)/);
  assert.match(workflow, /OCI_A1_BACKEND_ENV_B64_COMPOSED/);
  assert.match(workflow, /bash tools\/deploy\/deploy-oci-a1-backend\.sh/);

  for (const secret of [
    "OCI_A1_SSH_HOST",
    "OCI_A1_SSH_PORT",
    "OCI_A1_SSH_USER",
    "OCI_A1_SSH_PRIVATE_KEY_B64",
    "OCI_A1_SSH_KNOWN_HOSTS_B64",
    "OCI_A1_BACKEND_ENV_B64",
    "OCI_A1_VERTEX_KEY_JSON_B64",
    "SPRING__MAIL__HOST",
    "SPRING__MAIL__PORT",
    "SPRING__MAIL__USERNAME",
    "SPRING__MAIL__PASSWORD",
    "SPRING__MAIL__PROPERTIES__MAIL__SMTP__AUTH",
    "SPRING__MAIL__PROPERTIES__MAIL__SMTP__STARTTLS__ENABLE",
    "CUSTOM__MEMBER__SIGNUP__MAIL_ENABLED",
    "CUSTOM__MEMBER__SIGNUP__MAIL_FROM",
    "CUSTOM__MEMBER__SIGNUP__MAIL_SUBJECT",
    "APP_AUTH_SIGNUP_EMAIL_HASH_SECRET",
  ]) {
    assert.match(workflow, new RegExp(`secrets\\.${secret}`));
  }

  assert.match(
    workflow,
    /if \[\[ -n "\$\{SPRING__MAIL__HOST:-\}" && -n "\$\{CUSTOM__MEMBER__SIGNUP__MAIL_FROM:-\}" && -z "\$\{CUSTOM__MEMBER__SIGNUP__MAIL_ENABLED:-\}" \]\]/,
  );
  assert.doesNotMatch(workflow, /@v\d/);
});
