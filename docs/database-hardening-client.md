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
- Campus voting has a separate server gate; activation and installed-client
  compatibility are recorded in the backend runtime status. Five-person threshold
  is for school rounds, not campus recommendations.
- Actual purchase/restore/expiry on an App Store Sandbox device is separate from
  fake-provider backend tests. No cloud build/TestFlight upload was started.

Current running commit, effective gates, applied migrations and acceptance evidence
are maintained only in the backend [runtime status](backend-reference.md).
This client contract does not assert that the source is installed on a device.

Invitation v2 and daily50-round limit: [backend contract](../../../projects/flyprox_backend/docs/invitations-v2.md). One eligible recipient unlocks one12-question round; source readiness does not assert production activation or a new installed build.
