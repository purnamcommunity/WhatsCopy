# Contributing To WhatsCopy

Thanks for helping improve WhatsCopy.

## Local Setup

Requirements:

- macOS 13 or newer
- Xcode with Swift 5.9 or newer

Build:

```sh
swift build
```

Test:

```sh
swift test
```

Run:

```sh
swift run WhatsCopy
```

## Guidelines

- Keep the app privacy-first and narrow in scope.
- Do not add analytics, telemetry, tracking, or network calls.
- Do not read WhatsApp databases, files, private storage, or chat history.
- Prefer small, testable changes.
- Add or update tests for pure logic changes.
- Keep user-facing copy clear about Accessibility permission and limitations.

## Manual Testing

For changes touching copy behavior, manually verify:

- Command-C in WhatsApp copies selected text when exposed through Accessibility.
- Command-C in non-WhatsApp apps passes through normally.
- Empty or unavailable selections pass through normally.
- The menu-bar `Enabled` toggle works.
