## Platform: Android

Use for Jetpack Compose, Android Views/XML, and Kotlin/Java Android apps.

### Android rules

- Follow Material and Android platform conventions for navigation, back behavior, dialogs, sheets, lists, forms, and permissions.
- Respect density, font scale, TalkBack, high contrast, dark theme, reduced animations, system bars, and window insets.
- Prefer native/Material components unless the project's design system requires custom controls.
- Preserve state across recomposition, configuration changes, navigation, and process recreation when relevant.
- Keep destructive actions recoverable or clearly confirmed.

### Android verification

- Run available Gradle tests, lint, Compose checks, or project-specific checks.
- Use emulator/device screenshots or UI tests when available.
- Check small/large devices, font scale, TalkBack labels, dark theme, system insets, and back behavior.
- Report emulator/device coverage honestly.

