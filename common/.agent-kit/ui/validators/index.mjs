import { angularValidator } from "./angular.mjs";
import { androidValidator } from "./android.mjs";
import { iosValidator } from "./ios.mjs";
import { reactValidator } from "./react.mjs";
import { reactNativeValidator } from "./react-native.mjs";
import { svelteValidator } from "./svelte.mjs";
import { webValidator } from "./web.mjs";

export const validators = [
  svelteValidator,
  reactNativeValidator,
  reactValidator,
  angularValidator,
  iosValidator,
  androidValidator,
  webValidator,
];

export function isScannableFile(file) {
  return validators.some((validator) => validator.extensions.test(file));
}

export function validateFile({ file, text }) {
  const ctx = { file, text, lines: text.split("\n") };
  return dedupeFindings(
    validators.flatMap((validator) => (validator.matches(ctx) ? validator.validate(ctx) : []))
  );
}

function dedupeFindings(findings) {
  const seen = new Set();
  return findings.filter((finding) => {
    const key = `${finding.file}:${finding.line}:${finding.rule}:${finding.msg}`;
    if (seen.has(key)) return false;
    seen.add(key);
    return true;
  });
}
