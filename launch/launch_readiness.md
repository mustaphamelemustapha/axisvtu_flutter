# AxisVTU Launch Readiness

## What is complete
- Premium fintech UI for dashboard, wallet, buy data, history, receipt, profile, and notifications.
- Wallet funding via dedicated virtual account display and share/copy actions.
- Transaction PIN backend and Flutter integration for setup, verify, change, and reset flows.
- Receipt/success flow and share/export receipt support.
- Transaction history and transaction detail screens.
- In-app notification center.
- Retry/idempotency hardening for transaction requests.
- Profile actions are wired intentionally instead of dead-tapping.

## What is still manual
- Store asset export and final screenshot capture.
- Play Store / App Store metadata entry.
- Backend Render deployment confirmation after any future backend change.
- Legal review for privacy policy and terms.
- Real biometric unlock support if we choose to ship it later.

## Known release blockers
- None blocking in the current codebase.
- Biometric unlock and session management are intentionally surfaced as future updates rather than fake live features.

## Final QA checklist
- Auth login / register / logout.
- Forgot password email-link flow.
- Wallet funding and balance refresh.
- Buy data purchase with PIN verification.
- Wallet debit retry and timeout handling.
- Receipt view / share / export.
- History and transaction detail consistency.
- Notifications unread/read behavior.
- Profile actions: security, verification, help, preferences.
- Light mode and dark mode readability.
- Release build sanity on Android and iOS targets.

## Store submission checklist
- Confirm app title and package identifiers.
- Verify version and build number.
- Add privacy policy URL.
- Add terms URL.
- Add support contact email.
- Capture store screenshots.
- Fill in release notes.
- Verify signing / release config.
- Run final release build before submission.
