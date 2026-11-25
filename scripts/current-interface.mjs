// Prints the TOC interface number for the live Classic Era client (1.15.x),
// from Blizzard's product-versions service. Prints nothing on any failure.
// Interface = major*10000 + minor*100 + patch (1.15.9 -> 11509).

const URL = "https://us.version.battle.net/v2/products/wow_classic_era/versions";

try {
  const res = await fetch(URL, { headers: { "User-Agent": "toc-interface-check" } });
  if (!res.ok) process.exit(0);
  const lines = (await res.text()).split(/\r?\n/).filter(Boolean);
  const header = lines.find((l) => l.includes("VersionsName"));
  if (!header) process.exit(0);
  const cols = header.split("|").map((c) => c.split("!")[0].trim());
  const vi = cols.indexOf("VersionsName");
  const ri = cols.indexOf("Region");
  if (vi < 0) process.exit(0);
  const row = lines.find((l) => {
    const f = l.split("|");
    return f.length > vi && (ri < 0 || f[ri] === "us") && /^\d+\.\d+\.\d+/.test(f[vi]);
  });
  if (!row) process.exit(0);
  const [maj, min, pat] = row.split("|")[vi].split(".").map(Number);
  const iface = maj * 10000 + min * 100 + pat;
  if (!Number.isFinite(iface) || iface < 10000 || iface > 19999) process.exit(0);
  process.stdout.write(String(iface));
} catch {
  process.exit(0);
}
