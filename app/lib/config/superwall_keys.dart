// Superwall iOS Public API key (publishable, shipped in the app).
// Committed as an EMPTY placeholder so clean checkouts (Xcode Cloud)
// always compile. Billing stays disabled until the real key is present.
//
// Local dev: paste your key here. This file is skip-worktree:
//   git update-index --skip-worktree app/lib/config/superwall_keys.dart
// Never commit the real value; TestFlight uploads come from local Xcode.
const String superwallIosApiKey = '';
