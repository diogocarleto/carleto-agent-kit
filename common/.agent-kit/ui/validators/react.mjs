import { hasDefaultFont, hasQuotedPureNeutral, hasWebOvershootEasing, lineFindings, messages } from "./shared.mjs";

const REACT_EXT = /\.(jsx|tsx|js|ts|mjs)$/i;
const RN_HINT = /from\s+['"]react-native['"]|require\(['"]react-native['"]\)|from\s+['"]expo\b|(^|\/)(mobile|react-native|expo)(\/|$)/i;

export const reactValidator = {
  id: "react",
  extensions: REACT_EXT,
  matches: ({ file, text }) => {
    if (!REACT_EXT.test(file)) return false;
    if (RN_HINT.test(`${file}\n${text}`)) return false;
    return /\.(jsx|tsx)$/i.test(file) || /from\s+['"]react['"]|require\(['"]react['"]\)/.test(text);
  },
  validate: (ctx) => {
    const checks = [
      { id: "pure-neutral", msg: messages.pureNeutral, test: hasQuotedPureNeutral },
      { id: "default-font", msg: messages.defaultFont, test: hasDefaultFont },
      { id: "overshoot-easing", msg: messages.overshootEasing, test: hasWebOvershootEasing },
    ];
    return lineFindings(ctx, "react", checks);
  },
};
