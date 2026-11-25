const fs = require("fs");
const path = require("path");
const luaparse = require("luaparse");

const ADDON_DIR = path.join(__dirname, "..", "AIQuestHelper");
const TOC = path.join(ADDON_DIR, "AIQuestHelper.toc");

function fail(msg) {
  console.error(msg);
  process.exit(1);
}

const listed = fs
  .readFileSync(TOC, "utf8")
  .split(/\r?\n/)
  .map((l) => l.trim().replace(/\\/g, "/"))
  .filter((l) => /\.lua$/i.test(l) && !l.startsWith("#"));

const own = fs.readdirSync(ADDON_DIR).filter((f) => /\.lua$/i.test(f));
const orphans = own.filter((f) => !listed.includes(f));
if (orphans.length) fail("not listed in AIQuestHelper.toc (would never load): " + orphans.join(", "));

let lines = 0;
for (const rel of listed) {
  const file = path.join(ADDON_DIR, rel);
  if (!fs.existsSync(file)) fail("listed in .toc but missing: " + rel);
  const source = fs.readFileSync(file, "utf8");
  lines += source.split("\n").length;
  try {
    luaparse.parse(source, { luaVersion: "5.1" });
  } catch (e) {
    fail("luaparse " + rel + ": " + e.message);
  }
}
console.log("luaparse: OK (" + listed.length + " files, " + lines + " lines)");
