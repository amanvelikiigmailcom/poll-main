# Reward collection, campus waiting and country policy

Source implementation only. No backend deployment, native build or TestFlight upload
is implied. Companion backend source commit: `abb81ad`. Companion backend contract: `docs/campus-waiting-policy.md` in flyprox_backend.

## Reward receipt

Round submission still atomically credits the existing server reward (1000 or 2000).
The Collect button plays an original bundled coin chime, light/medium haptics and a
1250ms flight of 18 stars to the balance chip. It never calls a credit endpoint.
Double taps cannot start a second flight. Unknown balances remain unknown; no local
Premium flag or guessed delta changes an online balance. A session change hides the
previous account's receipt. Sound, haptics and Reduce Motion follow GameSettings and
system accessibility. iOS playback uses an ambient AVAudioSession, respecting silent
mode; other platforms fall back to the existing system click.

## Reviewer sessions

Backend grants `reviewerSkipsAllowed` after verifying the Firebase identity. Only the
existing reviewer phone receives it. Cached access is scoped to a hash of the exact
backend session token; the old `reviewer_seen_v1` is ignored. Intro Skip, guest exit,
example names and campus Skip require that capability and their existing remote flag.
Optional notification permission remains optional for everyone. Age and server game
gates are unchanged. Ordinary Firebase test phones receive no reviewer capability.

## Country and discovery

StoreKit `Storefront.current.countryCode` supplies an initial suggestion, with a
3-second deadline and phone-country fallback. The About you form confirms the country
of study. Unsupported storefronts require an explicit supported-country choice.
Storefront changes cannot replace a selected/waiting campus. Search adds
`includeUnavailable=true`: countries are exact, closed campuses remain visible with
`enrollmentAvailable=false`. An empty Canadian catalog is not filled with US campuses.
The UI says campus; existing school API/table identifiers are retained.

## Waiting

On a valid new selection the backend evaluates the real directory row against its
campus policy. A closed campus saves `status=waiting`, the requested campus and year,
without enrolling the profile. The client routes to the waiting screen and restores
that state after a new login. Home/vote navigation cannot override it. Support uses
the existing configured address and a mail draft; launch is not proof of sending.
Check availability must succeed online before showing Continue with your campus.
Only the original saved campus can resume, through a new server-validated save.
Correction of an erroneous request goes through support. Existing selected enrollments
retain the established compatibility behavior.

## Invitations

After Collect, Continue opens the timer. The timer and invitation composer use server policy; the reward receipt has no Share/invitation action. Default: US/CA Messages,
GB/NZ/SG/HK WhatsApp. `invitation_channel_policy` in backend content configuration can
select channel, enabled, buttonText, fallback (share/none), and a message template with
{url}/{code}. New channels still need native/client support. Existing invitation IDs
retain their original channel and reward facts. Offline configuration errors do not
create a new invitation grant.

## Validation and release

Run full checks in both repositories. Device acceptance remains necessary for native
Messages/WhatsApp, real storefronts, Mail, silent-mode sound and haptic feel. To release:
review both source diffs and compatibility first, then obtain the applicable separate
push/deployment/build authorization. No new database columns or migration are needed.
