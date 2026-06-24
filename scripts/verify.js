const fs = require("node:fs");
const path = require("node:path");

const repoRoot = path.resolve(__dirname, "..");
const tocPath = path.join(repoRoot, "GoodEnoughRaidTools.toc");
const toc = fs.readFileSync(tocPath, "utf8");

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
const commands = read("Commands.lua");
const readme = read("README.md");

assert(commands.includes('SLASH_GOODENOUGHRAIDTOOLS1 = "/gert"'), "Slash command registration is missing.");
assert(commands.includes("function GERT:HandleWhisperCommand"), "Whisper opt-out parser is missing.");
assert(commands.includes("function GERT:HandleReportCommand"), "Report command handler is missing.");
assert(core.includes("GoodEnoughRaidToolsDB"), "SavedVariables name mismatch.");
assert(readme.includes("/gert scan"), "README is missing command documentation.");
assert(readme.includes("gert unsub all"), "README is missing privacy whisper documentation.");
assert(readme.includes("Limitations"), "README is missing limitations.");

console.log("verify.js: repository checks passed");
