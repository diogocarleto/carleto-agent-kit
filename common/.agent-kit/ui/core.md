## UI Core

Use these rules for user-facing interface work across web, React Native, iOS, Android, and design systems.

### First classify

Before changing UI, classify:

- Mode: `shape`, `craft`, `audit`, `polish`, `harden`, `adapt`, or general UI help
- Register: product/tool, brand/marketing, content/editorial, game/immersive, native app
- Platform: web, React Native, iOS, Android
- Framework: Svelte, React, Next, Expo, SwiftUI, UIKit, Compose, XML, or unknown
- Scope: component, screen, flow, app shell, design system

### Universal quality bar

- Build the actual usable experience. Do not make a marketing page unless the user asks for one.
- Respect the local design system before inventing new components, spacing, colors, or motion. If the project has a design-language anchor (e.g. `modules/_root/ui.md`, theme tokens in `app.css`/`@theme`), treat it as the source of truth for palette, type, spacing, and motion.
- Make hierarchy obvious through information order, scale, weight, contrast, and whitespace.
- Keep product and tool screens quiet, dense, and scannable. Save expressive visuals for brand, editorial, game, or immersive surfaces.
- Prefer familiar controls: icon buttons for tools, segmented controls for modes, tabs for views, toggles for binary settings, menus for option sets, sliders/steppers/inputs for numbers.
- Keep dimensions stable for boards, grids, toolbars, counters, tiles, and media containers. Hover, loading, and dynamic content must not shift layout.
- Avoid nested cards, decorative blobs, one-note palettes, gratuitous gradients, and text that describes how to use obvious UI.
- Treat long text, empty data, loading, error, disabled, permission, offline, and slow-network states as part of the design, not follow-up polish.

### Recognizable AI tells (avoid)

These are the patterns that make generated UI look generated. Treat each as a defect unless the register explicitly calls for it:

- Pure `#000`/`#fff` and untinted grays — tint neutrals toward a brand hue. Never gray text on a colored background.
- Default/overused typefaces used as a "design" choice (Inter, Arial, system-ui) when the project has, or wants, a real type voice.
- Gratuitous gradients — especially purple→blue — plus decorative glows, dark glows behind cards, and heavy drop shadows.
- Card-in-card nesting, wrapping every block in a bordered card, and left-border/side-tab accents on panels.
- Bounce / elastic / overshoot easing and slow, showy transitions — reads as dated.
- Emoji standing in for icons, centered-everything layouts, and equal visual weight across the whole screen (no hierarchy).
- Microcopy that explains obvious UI ("Click the button below to…"), filler hero copy, and lorem-style placeholder left in.
- One-note palettes, evenly-spaced everything with no rhythm, and full-width unconstrained text lines.

A mechanical detector for the grep-able subset of these lives in `verification.md` → "Mechanical checks". Run it; it does not replace visual judgment.

### Mandatory checks

Every UI implementation, audit, polish, or hardening pass must consider:

- Contrast for text, icons, disabled states, focus, and overlays
- Overflow, clipping, wrapping, scrolling, and long unbroken strings
- Responsive behavior across small, medium, and large viewports or device classes
- Keyboard access, focus visibility, accessible names, and screen reader basics
- Touch target size, safe areas, platform insets, and reachable controls
- Empty, loading, error, disabled, success, stale, offline, and permission-denied states
- Dark mode, high-contrast mode, reduced motion, localization, and font scaling when the platform supports them
- Console/runtime errors, broken assets, missing icons/images, and layout shift

If a required check cannot be run in the current environment, say exactly what was not verified.

