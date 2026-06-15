# ModelServer Status Board

macOS menu bar dashboard for `code.cs.ac.cn` ModelServer usage.

## Run

```bash
CLANG_MODULE_CACHE_PATH=/private/tmp/modelserver-clang-cache swift run StatusBoardApp
```

The app appears in the macOS menu bar. Click the menu bar item, open the embedded login window, and authorize once. The app intercepts the callback URL before the website redirects away, so you do not need to copy the browser address bar. By default the login is session-only. Enable `记住登录` if you want to store the refresh token in macOS Keychain; access tokens stay in memory.

macOS may ask whether `StatusBoardApp` can access the saved Keychain item when `记住登录` is enabled or an older version already saved a token. Choosing "Always Allow" lets the app auto-login with the stored refresh token on future launches. Use `退出登录` to clear the app token and embedded WebKit website data; after that, the app should not be able to reuse old local credentials.

## Package

```bash
scripts/package_app.sh
```

The packaged app is written to `dist/ModelServer Status Board.app`. It is ad-hoc signed for local installation.

## Data Shown

- Total requests, tokens, credits, average daily requests
- API standard price, period paid, saved by plan
- 5h / 7d quota usage windows and reset times
- Daily request trend
- Usage by model
- Recent request metadata

The app only calls read-only dashboard endpoints and does not fetch API keys, prompts, traces, request bodies, or settings.

## Verify

```bash
CLANG_MODULE_CACHE_PATH=/private/tmp/modelserver-clang-cache swift run StatusBoardSelfTests
CLANG_MODULE_CACHE_PATH=/private/tmp/modelserver-clang-cache swift test
CLANG_MODULE_CACHE_PATH=/private/tmp/modelserver-clang-cache swift build
```

`StatusBoardSelfTests` contains the real test coverage for callback parsing, token refresh/retry, JSON normalization, quota math, and formatting. This local Command Line Tools installation exposes SwiftPM's test runner but not XCTest, so `swift test` is kept as a compile smoke check.
