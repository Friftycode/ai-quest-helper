// node scripts/apply-release.mjs <version> [classicEraInterface]
// The Classic Era number in the Interface line is replaced; the Forever number stays.
import fs from "node:fs";

const [version, iface] = process.argv.slice(2);
if (!version) {
  console.error("usage: node scripts/apply-release.mjs <version> [interface]");
  process.exit(1);
}

const TOC = "AIQuestHelper/AIQuestHelper.toc";
let toc = fs.readFileSync(TOC, "utf8");
if (iface && /^1\d{4}$/.test(iface)) {
  toc = toc.replace(/^(## Interface:\s*)(.*)$/m, (_, head, list) => {
    const nums = list.split(",").map((n) => n.trim());
    const i = nums.findIndex((n) => /^11\d{3}$/.test(n));
    if (i >= 0) nums[i] = iface;
    return head + nums.join(", ");
  });
}
toc = toc.replace(/^## Version:.*$/m, `## Version: ${version}`);
fs.writeFileSync(TOC, toc);

const pkg = JSON.parse(fs.readFileSync("package.json", "utf8"));
pkg.version = version;
fs.writeFileSync("package.json", JSON.stringify(pkg, null, 2) + "\n");
console.log(`version=${version}` + (iface ? ` interface=${iface}` : " (interface unchanged)"));
