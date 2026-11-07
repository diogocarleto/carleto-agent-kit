export const messages = {
  pureNeutral:
    "pure black/white or untinted neutral in a component - tint toward a brand hue (token files are exempt)",
  defaultFont: "default/overused typeface as a design choice (Inter/Arial/system-ui)",
  overshootEasing: "bounce/elastic/overshoot easing - reads as dated; use ease-out/ease-in",
};

const ANIM_CTX = /(transition|animation|animate|easing|interpolator|curve|timing-function|withAnimation)/i;

export function lineFindings({ file, lines }, platform, checks) {
  const findings = [];
  lines.forEach((line, i) => {
    for (const check of checks) {
      if (check.test(line, file)) {
        findings.push({ file, line: i + 1, rule: check.id, platform, msg: check.msg });
      }
    }
  });
  return findings;
}

export function hasCssPureNeutral(line) {
  return /(color|background|background-color|border|outline|box-shadow|tint)\s*:\s*[^;{]*#(000|000000|fff|ffffff)\b/i.test(
    line
  );
}

export function hasQuotedPureNeutral(line) {
  return (
    /['"]#(000|000000|fff|ffffff)['"]/i.test(line) &&
    !/\b(fill|stroke|stop-color|flood-color|lighting-color)\s*=\s*['"]#/i.test(line)
  );
}

export function hasDefaultFont(line) {
  return (
    /(font-family|fontFamily|FontFamily|fontName)\s*[:=(]/i.test(line) &&
    /\b(Inter|Arial|system-ui)\b/i.test(line)
  );
}

export function hasWebOvershootEasing(line) {
  return (
    (ANIM_CTX.test(line) && /\b(bounce|elastic|overshoot|anticipate)\b/i.test(line)) ||
    /cubic-bezier\(\s*[^)]*(-0?\.\d|1\.[1-9]|[2-9]\.\d)/i.test(line)
  );
}

export function extension(file, exts) {
  return new RegExp(`\\.(${exts.join("|")})$`, "i").test(file);
}
