# Flyprox startup video

The bundled video is `app/assets/animations/flyprox-intro.mp4`: 4 seconds, 1080 × 1920, H.264/yuv420p at 30 fps, AAC stereo at 44.1 kHz, approximately 228 KiB.
The existing animations asset directory includes it automatically. Fully restart Flutter when replacing the file.

## Export

- MP4 container, H.264 video, yuv420p, 1080 × 1920 portrait (9:16).
- 4 seconds, 30 fps, no loop; target under 5 MB.
- Music embedded as AAC, 44.1 or 48 kHz; gentle fade in/out, no speech.
- Keep important artwork within the central 70%; top-right is reserved for Skip and sound controls.
- Use music and visuals licensed for commercial app distribution.
- First and last frame: blue #4B6EF5. Do not bake controls or text into the video.
- The player fits the whole video on screen; wider devices can show blue borders.
- Web autoplay starts muted. Native audio and system silent-mode behavior need verification on an iPhone.

## AI video prompt

Create a premium 4-second vertical startup animation for Flyprox, a playful name-based quiz game. Use the supplied Flyprox logo as the exact visual reference. Solid electric blue background #4B6EF5, clean flat graphic style matching a mobile app. Start with the logo centered and still for 0.4 seconds. Three rounded quiz cards emerge smoothly from behind it, briefly fan out, then fold back into the logo. Small warm yellow stars appear with restrained, soft motion. Finish with the original logo centered and completely still for the final 0.7 seconds, against the same blue background. Fixed camera, crisp edges, smooth easing, polished and friendly, no flashing. Keep all key artwork in the central 70 percent of the frame and leave the top-right corner empty. No people, no faces, no extra logos, no written words, no interface controls, no watermarks. 9:16, 1080x1920, 30 fps, four seconds. Add a short original upbeat electronic musical sting with a soft pluck melody, gentle percussion and a clean warm finish. No vocals, no loud impact, no abrupt ending.

If the generator does not produce music, generate a separate four-second original musical sting using the last three sentences, then combine it with the video before export.
