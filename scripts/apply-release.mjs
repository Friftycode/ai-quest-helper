// node scripts/apply-release.mjs <version>
import fs from "node:fs";

const [version] = process.argv.slice(2);
if (!version) {
  console.error("usage: node scripts/apply-release.mjs <version>");
  process.exit(1);
}

const TOC = "AIQuestHelper/AIQuestHelper.toc";
fs.writeFileSync(TOC, fs.readFileSync(TOC, "utf8").replace(/^## Version:.*$/m, `## Version: ${version}`));

const pkg = JSON.parse(fs.readFileSync("package.json", "utf8"));
pkg.version = version;
fs.writeFileSync("package.json", JSON.stringify(pkg, null, 2) + "\n");
console.log(`version=${version}`);
