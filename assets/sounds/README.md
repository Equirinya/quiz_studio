# Built-in sounds

Sounds that come with the app, so a game plays sound without uploading any.
A game's own choices in the Music & sounds dialog win over these. Every file
here must be listed in `CREDITS.md` with its source and licence (a test checks
this), and the in-app list in `lib/features/settings/sound_credits.dart`
must match.

## Your own files

Jacob's music and sounds are in: `music/quiz_theme.mp3` (board), `music/chill.mp3`
(calm), `music/thrilling.mp3` (thrilling), `effects/right_answer/right_answer.mp3`,
`effects/fanfare/fanfare.mp3`, `buzzers/power.mp3`, `buzzers/light.mp3`. They are
the defaults for their slot or moment. More files go into the folder of their
moment (any name), get a line in `CREDITS.md`, and an entry in
`builtinSounds` (lib/game/content.dart). A new folder needs a line in
`pubspec.yaml`.

## What plays when

| Folder | Moment | Default |
|---|---|---|
| `effects/right_answer/` | a team answers right | Right answer (Jacob) |
| `effects/wrong_answer/` | a team answers wrong | Bwomp |
| `effects/reveal/` | a reveal step, Feud answer, Connections group | Pluck |
| `effects/question_open/` | a question opens | Brass stab |
| `effects/lock_in/` | a team locks its answer in | Pop |
| `effects/next_item/` | the next Fragenhagel item | Woodblock |
| `effects/countdown/` | the last 10 seconds of a timer of 20 s or more | Ticking clock |
| `effects/times_up/` | a timer runs out | Game-show buzzer |
| `effects/steal/` | Feud: the third strike | Riser |
| `effects/fanfare/` | a question fully solved | Fanfare (Jacob) |
| `effects/applause/`, `drumroll/`, `joke/`, `announcer/` | by hand, from the Effects sheet | |
| `buzzers/` | a team's buzzer, chosen on the Buzzers page: Classic (`assets/buzzer.mp3`), Power, Light, Buzzer, Soft | Classic |
| `music/` | Board, Calm and Thrilling music when the game has none of its own | |
| `ambience/` | keeps the speakers awake when nothing plays | Soft noise |

Generated sounds come from `tool/make_noise.js`, `tool/make_effects*.js` and
`tool/synth.js`.
