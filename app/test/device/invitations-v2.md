# Invitation v2 — physical iPhone/iPad acceptance (not run)

- [ ] US/CA opens Messages; GB/NZ/SG/HK opens WhatsApp. A selected local number is normalized with the correct country. One selected number only; raw number/name stays off backend requests.
- [ ] Messages sent activates one round; cancel/failed does not. Ten distinct recipients bank ten unlocks, minus any one already used for an active wait. Activated total remains10; no registration grant is added.
- [ ] Same recipient in another format/channel is rejected before composing after its round was activated. Cancelling permits a later real attempt.
- [ ] WhatsApp: opening without backgrounding grants nothing; exactly4s grants nothing; >4s qualifies. First5 distinct recipients per UTC day activate immediately;6th waits for confirmation.
- [ ] A preview/GET grants nothing. Recipient taps Continue to Flyprox; the sender sees1 round activated after refresh/poll. Repeated taps never double award. No install is required.
- [ ] Messages unavailable or WhatsApp absent opens Share Sheet. Sharing/cancelling it does not directly award; explicit link confirmation is required.
- [ ] Offline callback survives restart and retry. Account switch does not send callbacks or clear a timer for the other account. Cold/warm resume never repeats a grant.
- [ ]49→50 completed rounds is allowed;51st is blocked until UTC reset. Unused unlocks remain in the bank, and a pass is not spent at the limit. Age/campus gates still apply.
- [ ] Native Messages and WhatsApp UI are checked on real devices. .sent/return/link confirmation are not proof of delivery or recipient identity; do not report them as such.
