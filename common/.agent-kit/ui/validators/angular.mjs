import {
  hasCssPureNeutral,
  hasDefaultFont,
  hasQuotedPureNeutral,
  hasWebOvershootEasing,
  lineFindings,
  messages,
} from "./shared.mjs";

const ANGULAR_EXT = /\.(html|ts|css|scss|sass|less)$/i;
const ANGULAR_COMPONENT = /\.component\.(html|ts|css|scss|sass|less)$/i;
const ANGULAR_STYLE = /\.(css|scss|sass|less)$/i;

export const angularValidator = {
  id: "angular",
  extensions: ANGULAR_EXT,
  matches: ({ file, text }) => {
    if (!ANGULAR_EXT.test(file)) return false;
    return ANGULAR_COMPONENT.test(file) || /@angular\//.test(text) || /(^|\/)angular(\/|$)/i.test(file);
  },
  validate: (ctx) => {
    const checks = [
      {
        id: "pure-neutral",
        msg: messages.pureNeutral,
        test: (line, file) =>
          ANGULAR_STYLE.test(file) || /\.html$/i.test(file)
            ? hasCssPureNeutral(line) || hasQuotedPureNeutral(line)
            : hasQuotedPureNeutral(line),
      },
      { id: "default-font", msg: messages.defaultFont, test: hasDefaultFont },
      { id: "overshoot-easing", msg: messages.overshootEasing, test: hasWebOvershootEasing },
    ];
    return lineFindings(ctx, "angular", checks);
  },
};
