# Final QA Checklist

## Auth
- Login works
- Register works
- Logout works
- Forgot password sends email link
- Reset password flow works

## Wallet funding
- Dedicated account displays correctly
- Copy account number works
- Share account details works
- Balance refresh works
- No duplicate credit on repeated refresh or webhook replay

## Transaction PIN
- PIN setup works
- PIN verify works before debit actions
- PIN change works
- PIN reset works
- Wrong PIN and lockout states are clean

## Buy Data / debit flows
- Buy data completes with PIN approval
- Airtime completes with PIN approval
- Bills flow completes with PIN approval
- Failed and pending states are visible and calm
- Duplicate submit does not double debit

## Receipt / history
- Receipt matches history and detail data
- Share receipt works
- Export receipt works
- Transaction detail actions open real destinations

## Notifications
- Notification list loads
- Unread state persists
- Tapping notifications routes correctly
- Empty and loading states behave correctly

## Profile / settings
- Security actions do something intentional
- Preferences persist
- Help actions open real support channels or clear coming-soon states
- No dead taps remain

## Theme / readability
- Light mode is readable
- Dark mode is readable
- Headers and safe areas are aligned
- Buttons and cards remain crisp on small phones

## Release build
- Android debug build passes
- Release build sanity check passes
- iOS build sanity check passes if available
