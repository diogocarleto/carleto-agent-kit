## UI Hardening

Hardening makes an interface survive realistic bad inputs, bad networks, and bad device conditions.

### Required scenarios

- Long names, long words, multiline labels, translated strings, and large numbers
- Empty arrays, null fields, partial records, deleted references, and stale cached data
- Loading, retrying, submitting, optimistic updates, slow network, failed network, and offline mode
- Authentication expired, permission denied, unavailable feature, and read-only mode
- Dark mode, high contrast, reduced motion, font scaling, zoom, and screen reader usage
- Small phones, tablets, desktop, orientation changes, split screen, safe areas, and keyboard overlap
- Missing images, slow images, broken icons, and media with unexpected aspect ratios

### Implementation guidance

- Do not hide errors behind generic fallbacks when the platform/app has structured error handling.
- Reserve space for async media and dynamic text to avoid layout shift.
- Prefer truncation only when full content remains reachable through details, tooltip, expansion, or navigation.
- Make disabled and loading states explain why action is unavailable when the reason is not obvious.

