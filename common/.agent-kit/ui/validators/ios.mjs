import { lineFindings, messages } from "./shared.mjs";

export const iosValidator = {
  id: "ios",
  extensions: /\.swift$/i,
  matches: ({ file }) => /\.swift$/i.test(file),
  validate: (ctx) => {
    const checks = [
      {
        id: "pure-neutral",
        msg: messages.pureNeutral,
        test: (line) =>
          /\b(Color|UIColor)\.(black|white)\b/i.test(line) ||
          /\b(foregroundColor|background|fill|tint|accentColor|backgroundColor|borderColor)\(\s*\.(black|white)\b/.test(
            line
          ),
      },
      {
        id: "default-font",
        msg: messages.defaultFont,
        test: (line) => /\.custom\(\s*['"](Inter|Arial)\b/i.test(line),
      },
    ];
    return lineFindings(ctx, "ios", checks);
  },
};
