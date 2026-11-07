import { hasDefaultFont, hasQuotedPureNeutral, lineFindings, messages } from "./shared.mjs";

const RN_EXT = /\.(jsx|tsx|js|ts|mjs)$/i;
const RN_HINT =
  /from\s+['"]react-native['"]|require\(['"]react-native['"]\)|from\s+['"]expo\b|(^|\/)(mobile|react-native|expo)(\/|$)/i;

export const reactNativeValidator = {
  id: "react-native",
  extensions: RN_EXT,
  matches: ({ file, text }) => RN_EXT.test(file) && RN_HINT.test(`${file}\n${text}`),
  validate: (ctx) => {
    const checks = [
      { id: "pure-neutral", msg: messages.pureNeutral, test: hasQuotedPureNeutral },
      { id: "default-font", msg: messages.defaultFont, test: hasDefaultFont },
      {
        id: "overshoot-easing",
        msg: messages.overshootEasing,
        test: (line) => /Easing\.(bounce|elastic|back)\b/.test(line),
      },
    ];
    return lineFindings(ctx, "react-native", checks);
  },
};
