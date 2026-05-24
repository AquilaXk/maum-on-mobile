import { existsSync, readFileSync } from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";

const projectRoot = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "..");

const requiredFiles = [
  "app.json",
  "babel.config.js",
  "package.json",
  "tsconfig.json",
  "src/main.tsx",
  "src/App.tsx",
  "src/app/routes.ts",
  "src/app/supported-platforms.ts",
  "src/features/home/HomeScreen.tsx",
];

const requiredScripts = ["start", "android", "ios", "lint", "test", "typecheck", "build"];
const requiredDependencies = ["expo", "expo-status-bar", "react", "react-native"];
const requiredDevDependencies = ["@types/react", "typescript"];

function readJson(relativePath) {
  return JSON.parse(readFileSync(path.join(projectRoot, relativePath), "utf8"));
}

function assert(condition, message) {
  if (!condition) {
    throw new Error(message);
  }
}

export function validateProject() {
  for (const requiredFile of requiredFiles) {
    assert(existsSync(path.join(projectRoot, requiredFile)), `Missing required file: ${requiredFile}`);
  }

  const packageJson = readJson("package.json");
  const appJson = readJson("app.json");
  const routeSource = readFileSync(path.join(projectRoot, "src/app/routes.ts"), "utf8");
  const platformSource = readFileSync(path.join(projectRoot, "src/app/supported-platforms.ts"), "utf8");
  const entrySource = readFileSync(path.join(projectRoot, "src/main.tsx"), "utf8");

  for (const script of requiredScripts) {
    assert(packageJson.scripts?.[script], `Missing package script: ${script}`);
  }

  for (const dependency of requiredDependencies) {
    assert(packageJson.dependencies?.[dependency], `Missing runtime dependency: ${dependency}`);
  }

  for (const dependency of requiredDevDependencies) {
    assert(packageJson.devDependencies?.[dependency], `Missing dev dependency: ${dependency}`);
  }

  assert(packageJson.main === "src/main.tsx", "package.json main must point to src/main.tsx");
  assert(entrySource.includes("registerRootComponent"), "Expo entry point must register the root component");
  assert(appJson.expo?.ios?.bundleIdentifier, "app.json must define an iOS bundle identifier");
  assert(appJson.expo?.android?.package, "app.json must define an Android package name");
  assert(routeSource.includes("key: \"home\""), "Home route contract must be present");
  assert(routeSource.includes("initial: true"), "Initial route contract must be explicit");
  assert(platformSource.includes("\"android\""), "Android support contract must be present");
  assert(platformSource.includes("\"ios\""), "iOS support contract must be present");
  assert(!platformSource.includes("\"web\""), "The initial app contract must stay Android/iOS only");
}

if (process.argv[1] === fileURLToPath(import.meta.url)) {
  validateProject();
}
