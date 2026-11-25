# Received Likes: context and sharing

Backend counterpart: `flyprox_backend` commit `e752b0b`, branch
`feature/likes-context-share-20261125`; contract in its
`docs/received-vote-sharing.md`. Both repositories need integration/release;
this link is not proof the API is deployed.

## Flow

Likes → Vote details → Share → received-Like preview → social editor/share menu.
Participant cards are informational and have no tap route. The obsolete
`/likes-person` screen is removed; `/likes-share` accepts a vote ID only.
No participant or local-user name is substituted for a received result.

Activity, Likes and details format backend `voterGender` and `graduationYear`
as `From a girl/boy/non-binary student · Class of YEAR`; missing values remain
`From a student` or omit the year. These fields describe the voter, not the winner.

Share preview fetches fresh authenticated `GET /api/social/likes/:id` and repeats
authorization immediately before capture. Session changes clear the image/data.
Failure, blocking or revoked access does not fall back to the route's old data.
The 9:16 image contains "Someone picked me", the question, coarse voter hints,
and the server's candidate snapshot labeled "In this poll". It never includes
voter identity, Premium reveal information, raw IDs or other app chrome.
Candidate names are intentionally included per the requested sharing design.

## iOS integration / configuration

`StoryShareBridge.swift` is explicitly included in Runner's Sources phase and
registered in AppDelegate (a Swift file alone is insufficient for this project).

- Instagram Stories: configure Xcode build setting `FLYPROX_META_APP_ID` with a
  real registered Meta App ID. `source_application` is required by Meta.
- Snapchat: configure `FLYPROX_SNAP_CLIENT_ID` with an approved Creative Kit app's
  Client ID for this bundle. Uses code-only Creative Kit preview, no SDK/tracking.
- Empty or unresolved IDs, absent apps and rejected handoffs fall back to the
  native image share menu. UI explicitly explains fallback; it does not pretend
  that a requested social app opened.
- TikTok currently uses the native image share menu. Direct Share Kit integration
  is **not implemented**: it needs registered Client Key, callback configuration
  and the iOS SDK, plus media permission/review. No undocumented deep link or
  automatic publication is used.
- Other platforms use the image share menu when the bridge is absent.

The user chooses an available destination and confirms posting inside that app.
Which destinations accept an image through the share menu is device/app-dependent.
`opened` only means editor handoff; it is not a publication receipt.

## Verification

Unit/widget tests cover public projection, unknowns, session changes, fresh
authorization, no participant navigation, PNG capture size, attached image,
three destination actions, cancellation, fallback, errors and long questions.

Before declaring native sharing functional, use a real iPhone:
1. Configure valid IDs and verify each installed Instagram/Snapchat editor
   opens with the image and no private identity.
2. Verify image arrival, edit/cancel/post controls and candidate/year text.
3. Repeat absent apps, missing IDs and rejected handoffs; verify share menu.
4. Check TikTok image acceptance if it appears in the share menu; do not promise
   a TikTok Story/feed target that the installed extension does not offer.
5. Verify 320px layouts, iPad share origin, long names and 12 participants.

No native build, upload, deployment or live fixture write is implied by this doc.

Sources reviewed:
- https://developers.facebook.com/docs/instagram-platform/sharing-to-stories/
- https://developers.snap.com/snap-kit/creative-kit/overview
- https://github.com/Snapchat/creative-kit
- https://github.com/tiktok/tiktok-opensdk-ios
