# Privacy Policy changes — invitation release draft

Not yet published. Apply these changes to the public policy only when releasing the invitation-enabled build; do not describe them as behavior of the already published 1.0.1 / existing TestFlight13.

## Profile details

The invitation-enabled version asks for a first name, last name and username during setup. These details are stored on your device. If you sign in, they are also sent to our backend for your profile and invitation functionality. Your own name is not automatically added to quiz answer options.

## Invitations and Messages

You may invite one friend at a time using the system Messages composition window. You choose the recipient, can edit the message, and decide whether to send it. Flyprox does not send an SMS on your behalf through an SMS provider. Your mobile carrier's charges and Apple's messaging terms may apply. Flyprox records the composition result reported by the system, but does not receive delivery or read receipts. Copying an invitation writes its link and code to your clipboard. Reading an invitation code from the clipboard occurs only when you tap Paste.

Each invitation has a short code and link connected to the inviter's account. We store creation and observed opening events, composition results, account attribution on registration, and wait-pass grants/use. A website request can be a link preview rather than a person opening it. We do not independently observe App Store installs, read your messages, use IDFA, or fingerprint visitors by IP to connect an install to an invitation.

Optional selected-number matching: if you choose one contact for an invitation, that selected phone number is sent securely to our backend to calculate an HMAC-SHA256 value using a server-held key. The selected raw number is not stored or logged by this feature. The hash is retained with the invitation so we can match a newly verified account to it. Your entire address book is never uploaded. This optional invitation processing is separate from the existing game-contact matching flow, which sends confirmed names and client-generated hashes.

If you apply an invitation, or a selected-number invitation is matched during registration, the inviter can see that a friend registered, receives your first name in the invitation status/notification, and earns a wait pass. You receive a pass too. This is explained in setup. Invitation codes can be entered within seven days of account creation and invitations expire after 30 days. Expiry prevents new claims; it does not itself delete the account's invitation records.

We retain invitation attribution/events and pass records with the account to provide balances, support and abuse prevention. Expired rate-limit slots are periodically removed. Account deletion removes associated invitation attribution and names, selected-number hashes, your events and pass records. Another participant may retain an already-earned pass without your deleted name/attribution. We cannot recall an already-delivered notification or a message you sent through Messages. Deletion does not claim to erase independent provider records, backups or Apple purchases.

## App Privacy review

Reassess Phone Number (including hashed numbers), Contacts, Name, User ID and Product Interaction for functionality/analytics, reflecting actual implementation and linked-to-account use. Hashing is pseudonymisation, not anonymity. App Privacy must be reviewed in App Store Connect UI; no declaration is changed by this draft. Existing Firebase, Cloudflare, Apple and Superwall processing still applies; no new paid attribution or SMS delivery service is introduced.
