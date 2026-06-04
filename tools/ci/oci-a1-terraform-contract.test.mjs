import assert from "node:assert/strict";
import { execFileSync } from "node:child_process";
import { existsSync, readFileSync } from "node:fs";
import path from "node:path";
import test from "node:test";

const root = process.cwd();
const terraformRoot = "infra/terraform/oci/always-free-a1-flex";
const terraformPath = path.join(root, terraformRoot);

function read(relativePath) {
  return readFileSync(path.join(root, relativePath), "utf8");
}

function readTerraform(fileName) {
  return read(path.join(terraformRoot, fileName));
}

test("OCI A1 Terraform template exposes the expected tracked files", () => {
  for (const fileName of [
    "versions.tf",
    "providers.tf",
    "locals.tf",
    "images.tf",
    "network.tf",
    "compute.tf",
    "storage.tf",
    "outputs.tf",
    "variables.tf",
    "cloud-init.yaml",
    "terraform.tfvars.example",
    "maum-on-mobile-oci-a1.env.example",
  ]) {
    assert.ok(existsSync(path.join(terraformPath, fileName)), `Missing Terraform file: ${fileName}`);
  }

  assert.ok(!existsSync(path.join(terraformPath, "README.md")), "Markdown docs outside the root README must not be tracked");
});

test("OCI A1 Terraform template keeps the source shape but lowers data storage by default", () => {
  const locals = readTerraform("locals.tf");
  const variables = readTerraform("variables.tf");
  const compute = readTerraform("compute.tf");
  const storage = readTerraform("storage.tf");
  const cloudInit = readTerraform("cloud-init.yaml");

  assert.match(locals, /instance_shape\s*=\s*"VM\.Standard\.A1\.Flex"/);
  assert.match(locals, /Project\s*=\s*"maum-on-mobile"/);
  assert.match(variables, /variable "instance_ocpus"[\s\S]*default\s*=\s*4/);
  assert.match(variables, /variable "instance_memory_in_gbs"[\s\S]*default\s*=\s*24/);
  assert.match(variables, /variable "boot_volume_size_in_gbs"[\s\S]*default\s*=\s*50/);
  assert.match(variables, /variable "create_data_volume"[\s\S]*default\s*=\s*true/);
  assert.match(variables, /variable "data_volume_size_in_gbs"[\s\S]*default\s*=\s*50/);
  assert.match(variables, /variable "data_volume_vpus_per_gb"[\s\S]*default\s*=\s*0/);
  assert.match(variables, /variable "data_volume_mount_path"[\s\S]*default\s*=\s*"\/var\/lib\/maumon-data"/);
  assert.match(compute, /shape\s*=\s*local\.instance_shape/);
  assert.match(compute, /boot_volume_size_in_gbs\s*=\s*var\.boot_volume_size_in_gbs/);
  assert.match(storage, /count\s*=\s*var\.create_data_volume \? 1 : 0/);
  assert.match(storage, /size_in_gbs\s*=\s*var\.data_volume_size_in_gbs/);
  assert.match(cloudInit, /data_volume_enabled="\$\{data_volume_enabled\}"/);
  assert.match(cloudInit, /Data volume disabled; keeping the default Docker data root\./);
});

test("OCI A1 Terraform networking matches public staging requirements", () => {
  const network = readTerraform("network.tf");
  const variables = readTerraform("variables.tf");

  assert.match(variables, /variable "vcn_cidr"[\s\S]*default\s*=\s*"10\.41\.0\.0\/16"/);
  assert.match(variables, /variable "subnet_cidr"[\s\S]*default\s*=\s*"10\.41\.1\.0\/24"/);
  assert.match(network, /resource "oci_core_vcn" "this"/);
  assert.match(network, /resource "oci_core_internet_gateway" "this"/);
  assert.match(network, /destination\s*=\s*"0\.0\.0\.0\/0"/);
  assert.match(network, /description\s*=\s*"SSH ingress only from operator CIDR"/);
  assert.match(network, /max\s*=\s*22/);
  assert.match(network, /description\s*=\s*"HTTP ingress for staging"/);
  assert.match(network, /max\s*=\s*80/);
  assert.match(network, /description\s*=\s*"HTTPS ingress for staging"/);
  assert.match(network, /max\s*=\s*443/);
  assert.match(network, /prohibit_public_ip_on_vnic\s*=\s*false/);
});

test("OCI A1 Terraform keeps populated secrets and state out of git", () => {
  const gitignore = read(".gitignore");
  const tfvarsExample = readTerraform("terraform.tfvars.example");
  const envExample = readTerraform("maum-on-mobile-oci-a1.env.example");
  const allTemplateText = [
    "providers.tf",
    "variables.tf",
    "terraform.tfvars.example",
    "maum-on-mobile-oci-a1.env.example",
    "cloud-init.yaml",
  ]
    .map(readTerraform)
    .join("\n");

  for (const pattern of [
    "**/.terraform/",
    "**/.terraform.lock.hcl",
    "**/*.tfstate",
    "**/*.tfstate.*",
    "**/*.tfplan",
    "**/terraform.tfvars",
    "**/terraform.tfvars.json",
    "**/*.auto.tfvars",
    "**/*.auto.tfvars.json",
  ]) {
    assert.match(gitignore, new RegExp(pattern.replace(/[.*+?^${}()|[\]\\]/g, "\\$&")));
  }

  assert.match(gitignore, /!\*\*\/terraform\.tfvars\.example/);
  assert.match(tfvarsExample, /ocid1\.tenancy\.oc1\.\.example/);
  assert.match(tfvarsExample, /ssh-ed25519 example-public-key/);
  assert.match(envExample, /^OCI_A1_SSH_PRIVATE_KEY_B64=$/m);
  assert.match(envExample, /^OCI_A1_VERTEX_KEY_JSON_B64=$/m);
  assert.doesNotMatch(allTemplateText, /BEGIN [A-Z ]*PRIVATE KEY/);
  assert.doesNotMatch(allTemplateText, /Bearer [A-Za-z0-9._-]+/);
  assert.doesNotMatch(allTemplateText, /129\.154\./);
});

test("OCI A1 deployment env template includes Vertex AI runtime and release-readiness mirrors", () => {
  const appConfig = read("back/src/main/resources/application.yml");
  const readinessContract = read("contracts/infra/production-deploy-readiness.json");
  const envExample = readTerraform("maum-on-mobile-oci-a1.env.example");

  for (const name of [
    "GOOGLE_CLOUD_PROJECT_ID",
    "VERTEX_AI_LOCATION",
    "VERTEX_AI_MODEL",
    "GOOGLE_APPLICATION_CREDENTIALS",
  ]) {
    assert.match(appConfig, new RegExp(name));
    assert.match(envExample, new RegExp(`^${name}=`, "m"));
  }

  assert.match(envExample, /^GOOGLE_CLOUD_PROJECT_ID=grepp-ai-project$/m);
  assert.match(envExample, /^VERTEX_AI_LOCATION=us-central1$/m);
  assert.match(envExample, /^VERTEX_AI_MODEL=gemini-2\.5-flash$/m);
  assert.match(envExample, /^GOOGLE_APPLICATION_CREDENTIALS=\/run\/secrets\/vertex-key\.json$/m);

  for (const name of ["MAUMON_GOOGLE_CLOUD_PROJECT_ID", "MAUMON_GOOGLE_APPLICATION_CREDENTIALS"]) {
    assert.match(readinessContract, new RegExp(name));
    assert.match(envExample, new RegExp(`^${name}=`, "m"));
  }
});

test("OCI A1 deployment env template includes signup SMTP runtime variables", () => {
  const appConfig = read("back/src/main/resources/application.yml");
  const envExample = readTerraform("maum-on-mobile-oci-a1.env.example");

  for (const name of [
    "SPRING__MAIL__HOST",
    "SPRING__MAIL__PORT",
    "SPRING__MAIL__USERNAME",
    "SPRING__MAIL__PASSWORD",
    "SPRING__MAIL__PROPERTIES__MAIL__SMTP__AUTH",
    "SPRING__MAIL__PROPERTIES__MAIL__SMTP__STARTTLS__ENABLE",
    "CUSTOM__MEMBER__SIGNUP__MAIL_ENABLED",
    "CUSTOM__MEMBER__SIGNUP__MAIL_FROM",
    "CUSTOM__MEMBER__SIGNUP__MAIL_SUBJECT",
  ]) {
    assert.match(appConfig, new RegExp(name));
    assert.match(envExample, new RegExp(`^${name}=`, "m"));
  }

  assert.match(envExample, /^SPRING__MAIL__PORT=587$/m);
  assert.match(envExample, /^SPRING__MAIL__PROPERTIES__MAIL__SMTP__AUTH=true$/m);
  assert.match(envExample, /^SPRING__MAIL__PROPERTIES__MAIL__SMTP__STARTTLS__ENABLE=true$/m);
  assert.match(envExample, /^CUSTOM__MEMBER__SIGNUP__MAIL_ENABLED=false$/m);
  assert.match(envExample, /^CUSTOM__MEMBER__SIGNUP__MAIL_SUBJECT=\[Maum On\] 회원가입 이메일 인증$/m);
});

test("OCI A1 Terraform files are formatted", () => {
  execFileSync("terraform", ["-chdir=infra/terraform/oci/always-free-a1-flex", "fmt", "-check", "-recursive"], {
    cwd: root,
    encoding: "utf8",
    stdio: "pipe",
  });
});
