const fs = require("node:fs");
const path = require("node:path");

const repoRoot = path.resolve(__dirname, "..");
const tocPath = path.join(repoRoot, "GoodEnoughRaidTools.toc");
const toc = fs.readFileSync(tocPath, "utf8");
const workflowPath = path.join(repoRoot, ".github", "workflows", "curseforge-release.yml");

function assert(condition, message) {
  if (!condition) {
    throw new Error(message);
  }
}

function read(relativePath) {
  return fs.readFileSync(path.join(repoRoot, relativePath), "utf8");
}

const requiredTocLines = [
  "## Interface-TBC: 20505",
  "## SavedVariables: GoodEnoughRaidToolsDB",
  "Core.lua",
  "Buffs.lua",
  "UI.lua",
  "Commands.lua",
];

for (const line of requiredTocLines) {
  assert(toc.includes(line), `Missing TOC line: ${line}`);
}

const tocLuaFiles = toc
  .split(/\r?\n/)
  .map((line) => line.trim())
  .filter((line) => line.endsWith(".lua"));

for (const file of tocLuaFiles) {
  assert(fs.existsSync(path.join(repoRoot, file)), `TOC references missing file: ${file}`);
}

const core = read("Core.lua");
const buffs = read("Buffs.lua");
const commands = read("Commands.lua");
const readme = read("README.md");
const buildScript = read("scripts/build-release.sh");
const license = read("LICENSE");

assert(commands.includes('SLASH_GOODENOUGHRAIDTOOLS1 = "/gert"'), "Slash command registration is missing.");
assert(commands.includes("function GERT:HandleWhisperCommand"), "Whisper opt-out parser is missing.");
assert(commands.includes("function GERT:HandleReportCommand"), "Report command handler is missing.");
assert(commands.includes("missing/expiring <4m"), "Report wording does not mention expiring buffs.");
assert(buffs.includes("EXPIRING_THRESHOLD_SECONDS = 240"), "Buff expiry threshold is missing or changed.");
assert(buffs.includes("expires = expires"), "Scan results do not include expires metadata.");
assert(buffs.includes("expiring = expiring"), "Scan results do not include expiring metadata.");
assert(core.includes("GoodEnoughRaidToolsDB"), "SavedVariables name mismatch.");
assert(core.includes('expiring = "WARN"'), "WARN matrix state is missing.");
assert(readme.includes("/gert scan"), "README is missing command documentation.");
assert(readme.includes("gert unsub all"), "README is missing privacy whisper documentation.");
assert(readme.includes("under 4 minutes"), "README is missing expiry behavior documentation.");
assert(readme.includes("CurseForge Distribution"), "README is missing CurseForge distribution documentation.");
assert(readme.includes("MIT License"), "README is missing license documentation.");
assert(readme.includes("Limitations"), "README is missing limitations.");
assert(fs.existsSync(workflowPath), "CurseForge GitHub Actions workflow is missing.");
assert(buildScript.includes('addon_name="GoodEnoughRaidTools"'), "Release build script targets the wrong addon name.");
assert(license.includes("MIT License"), "LICENSE file is not MIT.");

console.log("verify.js: repository checks passed");
