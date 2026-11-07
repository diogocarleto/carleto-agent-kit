## Platform: iOS

Use for SwiftUI and UIKit apps.

### iOS rules

- Follow Apple platform conventions for navigation, sheets, lists, forms, destructive actions, and confirmation.
- Respect safe areas, Dynamic Type, VoiceOver, Reduce Motion, Dark Mode, and system color behavior.
- Prefer native controls and SF Symbols unless the project has a design-system reason not to.
- Keep primary actions reachable and destructive actions clearly distinguished.
- Handle permission prompts, denied permissions, unavailable hardware, offline data, and background/foreground transitions.

### iOS verification

- Run available `xcodebuild` tests, Swift tests, or project-specific checks.
- Use previews, simulator screenshots, or UI tests when available.
- Check Dynamic Type, VoiceOver labels, dark mode, safe areas, and keyboard overlap.
- Report device/simulator coverage honestly.

