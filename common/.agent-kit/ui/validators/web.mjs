import {
  hasCssPureNeutral,
  hasDefaultFont,
  hasQuotedPureNeutral,
  hasWebOvershootEasing,
  lineFindings,
  messages,
} from "./shared.mjs";

const WEB_STYLE = /\.(css|scss|sass|less|styl)$/i;
const WEB_MARKUP = /\.(html|vue)$/i;
const WEB_SCRIPT = /\.(js|ts|mjs)$/i;

export const webValidator = {
  id: "web",
  extensions: /\.(css|scss|sass|less|styl|html|vue|js|ts|mjs)$/i,
  matches: ({ file, text }) => {
    if (/\.(svelte|jsx|tsx)$/i.test(file)) return false;
    if (/\.component\.(html|css|scss|sass|less|ts)$/i.test(file)) return false;
    if (WEB_STYLE.test(file) || WEB_MARKUP.test(file)) return true;
    return WEB_SCRIPT.test(file) && /\b(document|window|HTMLElement|customElements)\b/.test(text);
  },
  validate: (ctx) => {
    const checks = [
      {
        id: "pure-neutral",
        msg: messages.pureNeutral,
        test: (line, file) =>
          WEB_STYLE.test(file) || WEB_MARKUP.test(file)
            ? hasCssPureNeutral(line) || hasQuotedPureNeutral(line)
            : hasQuotedPureNeutral(line),
      },
      { id: "default-font", msg: messages.defaultFont, test: hasDefaultFont },
      { id: "overshoot-easing", msg: messages.overshootEasing, test: hasWebOvershootEasing },
    ];
    return lineFindings(ctx, "web", checks);
  },
};
