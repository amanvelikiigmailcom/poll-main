# Browser acceptance

`reviewer_qa.dart` is an explicit QA entrypoint, never imported by `lib/main.dart`.
It requires `FLYPROX_BROWSER_QA=true` and a loopback `API_BASE_URL`.

The production widgets, router, API client and account services run unchanged.
Native phone, contacts and push handoffs use test drivers. The owner-authorized
acceptance used real Firebase-verified ID tokens through a private loopback bridge
and the deployed API. Browser contact selection supplied six synthetic contacts;
no SMS or invitations were sent. Credentials and bridge state stay outside Git.

Coverage: clean reviewer login, age gate, contacts/examples, existing username,
12-question submission and receipt, server waiting state, blank profile, first
name/gender editing, campus-less Search and returning login in a fresh browser
profile. A separate fresh browser profile restored the ordinary account without
repeating profile/campus/contact forms. Likes pagination and current invitation
were checked against the real account. Reviewer fixtures were cleared afterward.

This proves browser/application/backend behavior, not native iPhone Contacts
permission, Firebase SMS UI, APNs delivery or StoreKit purchase flows. A new native
build is required for client changes; this entrypoint is not a release binary.
