# App Store Review Blockers & Offline Feature Ideas

## Review Blockers (Criticality 1-10)

1. **Silent Redirects for Missing Routes (Criticality: 8/10) - FIXED**
   - The app previously redirected to `/#/names` silently when a requested route was not found (e.g., `/premium`, `/faq`, etc.). This could lead to a confusing user experience and Apple reviewers might flag the app for broken navigation/buttons.
   - *Fix applied:* Added missing routes to `app_router.dart` so they resolve properly instead of defaulting back to names entry.

2. **Premium / In-App Purchase Flow (Criticality: 9/10)**
   - Apple requires a fully functioning in-app purchase flow using StoreKit if you mention "Premium" features.
   - Currently, `/premium` is implemented but might lack the proper backend verification and full StoreKit integration.
   - *Recommendation:* If IAP is not fully working, either remove the "Premium" buttons/screens before submission or submit it with a fully working mock for the reviewer if backend is truly absent.

3. **Privacy Policy and Terms of Service Links (Criticality: 10/10)**
   - Must be clearly accessible. Currently available under `/privacy` and `/terms`, which is good. Ensure the links actually open standard web pages or clear text within the app.

4. **User Generated Content (UGC) Reporting (Criticality: 9/10)**
   - Since users can create names/profiles (even locally), Apple requires a way to report/block users for UGC.
   - *Status:* `/safety-center` and blocking options exist in settings, which covers this.

---

## 30 Offline / No-Backend Feature Ideas (To pass review & increase engagement)

Since the goal is to pass the App Store review and build a strong local prototype without a backend, here are 30 feature ideas that can be implemented completely offline:

### Core Gameplay & Polls
1. **Local Achievements/Badges:** Unlock badges based on the number of polls completed or stars earned.
2. **Daily Streaks:** Track how many consecutive days the user has opened the app and completed a poll.
3. **Custom Poll Categories:** Let users create their own poll questions locally that get mixed into the main deck.
4. **Offline AI Bots:** Simulate friend activity by having local "bots" that randomly vote for the user, generating stars and activity.
5. **Unlockable Themes:** Use earned stars to unlock new app color themes or card styles.
6. **Time-Attack Mode:** A fast-paced poll mode where you have to answer 12 questions in under 30 seconds for bonus stars.
7. **Mystery Cards:** Occasional blank cards that the user can fill in with a friend's name on the spot.
8. **Poll History:** A local log of all past questions answered and who was chosen.
9. **"Guess Who" Mini-Game:** A local game where the app shows a previous answer and you have to remember who you picked.
10. **Daily Spin Wheel:** A daily reward wheel to earn extra stars or reduce the timer.

### Social Simulation & Activity
11. **Simulated Inbox:** A fake inbox where the user receives "messages" or "hints" about who voted for them (driven by local random logic).
12. **Friend Relationship Levels:** The more you pick a specific friend, the higher your "bond level" with them grows locally.
13. **Activity Feed Simulator:** Generate a fake feed of "X from your school just got a star" to make the app feel alive.
14. **School Leaderboard (Simulated):** A local leaderboard showing fake students and the user's rank based on stars.
15. **Crush Mode:** Pin a specific friend as a "crush"; the app will slightly increase their appearance rate in sympathy questions.

### Customization & Profile
16. **Avatar Builder:** A local character creator (using basic shapes or emoji combinations) instead of just initials.
17. **Profile Banners:** Unlockable header images for the local profile page.
18. **Custom App Icons:** Allow users to change the home screen app icon (using `flutter_dynamic_icon`).
19. **Sound Packs:** Different sound effects for voting, unlockable via stars.
20. **Haptic Feedback Settings:** Granular control over vibration intensity for different actions.

### Utilities & Tools
21. **Name Import from Contacts:** (Requires permission) Allow picking names from the local device contacts to populate the friend list faster, without uploading them anywhere.
22. **QR Code Generator:** Generate a local QR code with the user's display name, ready for when multiplayer is added.
23. **Export Poll Results:** Generate a cool graphic of "My Top Traits" based on local poll answers to share on Instagram Stories.
24. **Local Backup/Restore:** Export local `SharedPreferences` data to a JSON file and import it, acting as a manual save system.
25. **Dark Mode:** A complete dark theme implementation.

### Content & Onboarding
26. **Interactive Tutorial:** A guided, playable tutorial poll during onboarding instead of static text.
27. **"Did you know?" Trivia:** Show fun facts about psychology and friendships on the timer screen.
28. **Easter Eggs:** Hidden interactions (e.g., tapping the logo 5 times opens a secret minigame).
29. **Language Sandbox:** Let users switch between English and a joke language (like Pirate or Gen-Z slang) locally.
30. **Mental Health Reminders:** Occasional positive affirmations displayed after completing a poll session.
