# Profile update

- Preserve bottom navigation unchanged.
- White rounded profile card, fixed 🙂, English UI, canonical name and @username.
- Current campus and graduation year from onboarding; existing one-campus-change
  policy stays in place. No new three-month editing restriction.
- Friends, Likes, incoming Requests use server data; Stars remains a separate balance.
- Five accepted friends and See all. Show server-projected first + last name and
  @username; missing names fall back to handle. No mutual-friend annotation.
- Reuse existing friends/Received request screens and actual `/people/:id`.
- Collection is a separate stars/boosts card and reward-screen action, per the
  updated owner request. Received votes still belong to Likes.
- Likes now requests a private paginated received-vote feed with historical server
  count. Never return voter identity. Loading/error/empty are different states.
- Share profile copies `https://api.flyprox.com/p/@username`, with toast and
  two-second Copied state. Resolve exact handle behind authentication, campus and
  block checks. iOS universal-link association adds `/p/*`; web fallback offers
  handle search without exposing profile existence.
- Defer incoming profile links while age/onboarding/round flows are active.
- Other-person destinations use `PersonProfileScreen`; see [person-profile.md](person-profile.md).
- Full Flutter and backend checks required. No push, deployment or native/cloud
  build is authorized by this plan. Real universal-link device QA remains separate.

Backend contract: `flyprox_backend/docs/profile-social-contract.md`.
