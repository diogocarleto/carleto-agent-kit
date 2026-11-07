import {
  hasCssPureNeutral,
  hasDefaultFont,
  hasQuotedPureNeutral,
  hasWebOvershootEasing,
  lineFindings,
  messages,
} from "./shared.mjs";

export const svelteValidator = {
  id: "svelte",
  extensions: /\.svelte$/i,
  matches: ({ file }) => /\.svelte$/i.test(file),
  validate: (ctx) => {
    const checks = [
      {
        id: "pure-neutral",
        msg: messages.pureNeutral,
        test: (line) => hasCssPureNeutral(line) || hasQuotedPureNeutral(line),
      },
      { id: "default-font", msg: messages.defaultFont, test: hasDefaultFont },
      { id: "overshoot-easing", msg: messages.overshootEasing, test: hasWebOvershootEasing },
    ];
    return lineFindings(ctx, "svelte", checks);
  },
};
