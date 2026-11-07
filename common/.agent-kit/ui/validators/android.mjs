import { lineFindings, messages } from "./shared.mjs";

const ANDROID_EXT = /\.(kt|kts|java|xml)$/i;
const ANDROID_HINT =
  /(^|\/)(android|app\/src\/main|src\/main\/res|res\/values|res\/drawable|res\/layout)(\/|$)|AndroidManifest\.xml$|androidx\.compose|android\.(view|widget|graphics|content|os)\b|com\.android\./i;

export const androidValidator = {
  id: "android",
  extensions: ANDROID_EXT,
  matches: ({ file, text }) => ANDROID_EXT.test(file) && ANDROID_HINT.test(`${file}\n${text}`),
  validate: (ctx) => {
    const checks = [
      {
        id: "pure-neutral",
        msg: messages.pureNeutral,
        test: (line, file) => {
          if (/\.xml$/i.test(file)) return /"#(ff)?(000000|ffffff)"/i.test(line);
          if (/\.(kt|kts)$/i.test(file)) {
            return (
              /Color\(\s*0x(FF)?(000000|FFFFFF)\s*\)/i.test(line) ||
              /\bColor\.(Black|White)\b/.test(line)
            );
          }
          return false;
        },
      },
      {
        id: "default-font",
        msg: messages.defaultFont,
        test: (line, file) => /\.(kt|kts)$/i.test(file) && /FontFamily\(/i.test(line) && /\b(Inter|Arial)\b/i.test(line),
      },
      {
        id: "overshoot-easing",
        msg: messages.overshootEasing,
        test: (line) => /(Bounce|Overshoot|Anticipate)Interpolator/.test(line),
      },
    ];
    return lineFindings(ctx, "android", checks);
  },
};
