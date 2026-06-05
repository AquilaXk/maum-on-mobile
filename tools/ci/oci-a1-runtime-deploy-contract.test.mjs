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
  assert.match(script, /deploy_transport="\$\{MAUMON_DEPLOY_TRANSPORT:-ssh\}"/);
  assert.match(script, /Invalid MAUMON_DEPLOY_TRANSPORT/);
  assert.match(script, /ssh_required_vars=\(/);
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
  assert.match(script, /"MAUMON_DOCKER_NETWORK=\$\{docker_network\}"/);
  assert.match(script, /"MAUMON_APP_DATA_DIR=\$\{app_data_dir\}"/);
  assert.match(script, /"MAUMON_DEPLOY_HEALTH_TIMEOUT_SECONDS=\$\{deploy_health_timeout_seconds\}"/);
  assert.match(script, /"MAUMON_HOST_HTTP_PORT=\$\{host_http_port\}"/);
  assert.match(script, /"MAUMON_HOST_HTTP_RATE_LIMIT=\$\{host_http_rate_limit\}"/);
  assert.match(script, /"MAUMON_HOST_HTTP_RATE_LIMIT_BURST=\$\{host_http_rate_limit_burst\}"/);
  assert.match(script, /"MAUMON_HOST_HTTP_CONN_LIMIT=\$\{host_http_conn_limit\}"/);
  assert.match(script, /remote_staging="\/tmp\/maum-on-mobile-deploy-\$\{deploy_run_id\}-\$\{deploy_run_attempt\}"/);
  assert.match(script, /remote_script="\$\{tmp_dir\}\/remote-deploy\.sh"/);
  assert.match(script, /cat >"\$\{remote_script\}" <<'REMOTE'/);
  assert.match(script, /prepare_remote_staging\(\)/);
  assert.match(script, /run_remote_deploy\(\)/);
  assert.match(script, /if \[\[ "\$\{deploy_transport\}" == "local" \]\]/);
  assert.match(script, /bash "\$\{remote_script\}"/);
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
  assert.match(script, /host_http_rate_limit="\$\{MAUMON_HOST_HTTP_RATE_LIMIT:-60\/second\}"/);
  assert.match(script, /host_http_rate_limit_burst="\$\{MAUMON_HOST_HTTP_RATE_LIMIT_BURST:-120\}"/);
  assert.match(script, /host_http_conn_limit="\$\{MAUMON_HOST_HTTP_CONN_LIMIT:-80\}"/);
  assert.match(script, /http_rate_limit_chain="MAUMON_HTTP_RATE_LIMIT"/);
  assert.match(script, /iptables -N "\$\{http_rate_limit_chain\}"/);
  assert.match(script, /iptables -F "\$\{http_rate_limit_chain\}"/);
  assert.match(script, /--connlimit-above "\$\{host_http_conn_limit\}"/);
  assert.match(script, /--hashlimit-name maumon-http/);
  assert.match(script, /--hashlimit-upto "\$\{host_http_rate_limit\}"/);
  assert.match(script, /--hashlimit-burst "\$\{host_http_rate_limit_burst\}"/);
  assert.match(script, /iptables -C INPUT -p tcp --dport "\$\{host_http_port\}" -j "\$\{http_rate_limit_chain\}"/);
  assert.match(script, /iptables -I INPUT 1 -p tcp --dport "\$\{host_http_port\}" -j "\$\{http_rate_limit_chain\}"/);
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

test("OCI deploy diagnostics collector records runtime state without exposing secrets", () => {
  const scriptPath = "tools/deploy/collect-oci-a1-deploy-diagnostics.sh";

  assert.ok(existsSync(path.join(root, scriptPath)), `${scriptPath} must exist`);

  const script = read(scriptPath);

  assert.match(script, /^set -euo pipefail$/m);
  assert.match(script, /phase="before"/);
  assert.match(script, /output_dir="deploy-debug"/);
  assert.match(script, /container_name="maum-on-mobile-back"/);
  assert.match(script, /previous_container_name="maum-on-mobile-back-previous"/);
  assert.match(script, /metadata\.txt/);
  assert.match(script, /GITHUB_RUN_ID/);
  assert.match(script, /docker info/);
  assert.match(script, /docker ps -a/);
  assert.match(script, /container-status\.txt/);
  assert.match(script, /previous-container-status\.txt/);
  assert.match(script, /image-status\.txt/);
  assert.match(script, /docker inspect --format/);
  assert.match(script, /docker image inspect --format/);
  assert.doesNotMatch(script, /container-inspect\.json|image-inspect\.json/);
  assert.doesNotMatch(script, /docker logs/);
  assert.doesNotMatch(script, /set -x/);
  assert.doesNotMatch(script, /printenv|env >|cat .*\.env/);
});

test("GitHub Actions deploy workflow builds jar, bundles it, and deploys on the server runner", () => {
  const workflowPath = ".github/workflows/deploy-oci-a1.yml";

  assert.ok(existsSync(path.join(root, workflowPath)), `${workflowPath} must exist`);

  const workflow = read(workflowPath);

  assert.match(workflow, /^name: Deploy OCI A1 Backend$/m);
  assert.match(workflow, /workflow_dispatch:/);
  assert.match(workflow, /dry_run:/);
  assert.match(workflow, /description: "Run deployment checks without changing the running backend"/);
  assert.match(workflow, /default: true/);
  assert.match(workflow, /ref:/);
  assert.doesNotMatch(workflow, /image_tag_suffix:/);
  assert.match(workflow, /environment:/);
  assert.match(workflow, /name: \$\{\{ needs\.prepare\.outputs\.environment \}\}/);
  assert.match(workflow, /runs-on:\n\s+- self-hosted\n\s+- Linux\n\s+- ARM64\n\s+- oci-a1-deploy/);
  assert.match(workflow, /permissions:\n  contents: read\n  deployments: write/);
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
  assert.match(workflow, /MAUMON_DEPLOY_TRANSPORT: local/);
  assert.match(workflow, /if: needs\.prepare\.outputs\.dry_run != 'true'/);
  assert.match(workflow, /name: Prepare deploy diagnostics/);
  assert.match(workflow, /name: Run preflight diagnostics/);
  assert.match(workflow, /name: Run postflight diagnostics/);
  assert.match(workflow, /name: Collect failure diagnostics/);
  assert.match(workflow, /bash tools\/deploy\/collect-oci-a1-deploy-diagnostics\.sh/);
  assert.match(workflow, /name: Upload deploy diagnostics/);
  assert.match(workflow, /uses: actions\/upload-artifact@[a-f0-9]{40}/);
  assert.match(workflow, /name: deploy-debug-\$\{\{ needs\.prepare\.outputs\.short_sha \}\}/);
  assert.match(workflow, /retention-days: 14/);

  for (const secret of [
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

test("backend deploy workflow auto-runs production deploy after successful main CI", () => {
  const workflowPath = ".github/workflows/deploy-oci-a1.yml";

  assert.ok(existsSync(path.join(root, workflowPath)), `${workflowPath} must exist`);

  const workflow = read(workflowPath);

  assert.match(workflow, /workflow_run:\n\s+workflows: \["CI"\]\n\s+types: \[completed\]\n\s+branches:\n\s+- main/);
  assert.match(workflow, /jobs:\n  prepare:/);
  assert.match(workflow, /WORKFLOW_RUN_CONCLUSION: \$\{\{ github\.event\.workflow_run\.conclusion \}\}/);
  assert.match(workflow, /WORKFLOW_RUN_HEAD_BRANCH: \$\{\{ github\.event\.workflow_run\.head_branch \}\}/);
  assert.match(workflow, /WORKFLOW_RUN_HEAD_SHA: \$\{\{ github\.event\.workflow_run\.head_sha \}\}/);
  assert.match(workflow, /DISPATCH_DRY_RUN: \$\{\{ inputs\.dry_run \}\}/);
  assert.match(workflow, /DISPATCH_REF: \$\{\{ inputs\.ref \}\}/);
  assert.match(workflow, /deploy_environment="production"/);
  assert.match(workflow, /deploy_reason="main CI completed successfully"/);
  assert.match(workflow, /dry_run="false"/);
  assert.match(workflow, /dry_run="\$\{DISPATCH_DRY_RUN:-true\}"/);
  assert.match(workflow, /git rev-parse --verify "\$\{DISPATCH_REF\}\^\{commit\}"/);
  assert.match(workflow, /deploy_sha="\$\(git rev-parse "\$\{DISPATCH_REF\}\^\{commit\}"\)"/);
  assert.match(workflow, /git fetch --no-tags origin "\$\{DISPATCH_REF\}"/);
  assert.match(workflow, /git fetch --no-tags origin main:refs\/remotes\/origin\/main/);
  assert.match(workflow, /if \[\[ "\$\{dry_run\}" != "true" && "\$\{should_deploy\}" == "true" && "\$\{deploy_sha\}" != "\$\{main_sha\}" \]\]/);
  assert.match(workflow, /stale deployment SHA/);
  assert.match(workflow, /changed_files="\$\(mktemp\)"/);
  assert.match(workflow, /git diff --name-only "\$\{deploy_sha\}\^" "\$\{deploy_sha\}" >"\$\{changed_files\}"/);
  assert.match(workflow, /env -u GITHUB_OUTPUT -u GITHUB_STEP_SUMMARY bash tools\/ci\/detect-changed-paths\.sh "\$\{changed_files\}"/);
  assert.match(workflow, /deploy_changed="\$\(printf '%s\\n' "\$\{gate_output\}" \| awk -F= '\$1 == "deploy" \{ print \$2 \}'\)"/);
  assert.match(workflow, /no deployment-impacting files changed/);
  assert.match(workflow, /### Deployment impact/);
  assert.match(workflow, /short_sha="\$\{deploy_sha:0:12\}"/);
  assert.match(workflow, /short_sha=\$\{short_sha\}/);
  assert.match(workflow, /deploy_reason: \$\{\{ steps\.context\.outputs\.deploy_reason \}\}/);
  assert.match(workflow, /dry_run: \$\{\{ steps\.context\.outputs\.dry_run \}\}/);
  assert.match(workflow, /\| deploy_reason \| \$\{deploy_reason\} \|/);
  assert.match(workflow, /\| dry_run \| \$\{dry_run\} \|/);
  assert.match(workflow, /if: needs\.prepare\.outputs\.should_deploy != 'true'/);
  assert.match(workflow, /if: needs\.prepare\.outputs\.should_deploy == 'true'/);
});
