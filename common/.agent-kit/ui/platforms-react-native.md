## Platform: React Native

Use for Expo or bare React Native apps.

### React Native rules

- Respect safe areas, keyboard avoidance, status/navigation bars, and platform-specific insets.
- Use platform-appropriate navigation: tabs, stacks, sheets, modals, and native gestures.
- Use `Pressable`/platform controls with clear pressed, disabled, and loading states.
- Set `accessibilityRole`, `accessibilityLabel`, `accessibilityHint`, and state where native inference is insufficient.
- Support font scaling unless the product has a documented exception.
- Use `FlatList`/virtualization for long lists. Avoid rendering large scroll collections eagerly.
- Test both iOS and Android behavior when the change touches navigation, permissions, gestures, input, or layout.

### React Native verification

- Run available TypeScript, lint, unit, or component checks.
- Use simulator/emulator or screenshot tooling when available.
- Verify small devices, large devices, keyboard overlap, dark mode, and long text.
- Report when device-level verification was not available.

