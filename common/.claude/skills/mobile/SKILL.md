---
name: mobile
description: Load mobile conventions for the current stack. Use when working on mobile app files — screens, navigation, native modules, platform services, state, or device/permission handling. Companion to /ui-design, which covers the visual craft; this skill carries the layer's code rules.
---

Load all mobile conventions into context for this task.

Read every `*.md` file directly under `.agent-kit/common/conventions/mobile/` — glob that directory and read each file.

Also read every `*.md` under `.agent-kit/common/process/authoring/` — glob that directory; it sets the budget every doc comment you write must clear.

A stack with **no** mobile layer ships no such directory. That is expected, not an error: say so plainly and fall back to the project's own neighbouring code rather than inventing conventions, exactly as `/frontend` does on a backend-only stack.

Apply all rules from the loaded documents to the current task. Use neighboring files under the mobile `src_globs` declared in `.agent-kit-local/structure.yml` as the first structural reference. For the visual and interaction half — screens, navigation patterns, platform idioms, accessibility — compose with `/ui-design`, which carries the iOS, Android and React Native platform references. Do not ask for confirmation — proceed with the work.
