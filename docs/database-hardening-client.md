# Database hardening client contract

Backend schema and detailed24-table plan are canonical in:
/Users/amanyessen/projects/flyprox_backend/docs/database-hardening-plan.md
and its generated docs/database-schema.md. Do not copy field lists here.

Client source is prepared and tested, not an installed TestFlight build.

- Home, Profile and Collection use authenticated profile.starsCount; guests use
  local stars. Confirmed balance cache is keyed by a hash of the session token,
  not a shared guest/account balance. Stale success/401 or invalid/negative values
  cannot display another session's balance. No guest total is uploaded to award
  server stars. Successful online draft completion does not award guest stars.
- Online rounds are local editable drafts until whole-round submit. Persist exact
  question/candidate IDs, owner/session identity and sealed answers for retries.
  Identical retries are acknowledged without a second reward by the backend.
  Account changes are checked before/after submission, and same-account token
  renewal requires verifying the current server account ID.
- Contact sync sends hashes only; labels remain local. contactHash from the owned
  candidate set maps the stored label even if registered names differ. Unmatched
  or ambiguous labels do not authorize a vote for a stranger.
- Campus voting remains separately gated in production until a compatible build.
  Five-person threshold is for school rounds, not campus recommendations.
- Actual purchase/restore/expiry on an App Store Sandbox device is separate from
  fake-provider backend tests. No cloud build/TestFlight upload was started.

Server ee4f8bc and15-index migration are active; outbox/retention/contacts/verified
subscription logic passed backend real acceptance. Actor migration was approved/applied, its flag is1 and real indexed erasure QA
passed; the24-table live schema now matches with0differences. CONTACT_LABELS_LOCAL_ENABLED remains0 until the compatible
client is available, preserving installed-client matching.
