# Built-in sounds

Sounds that come with the app, so a game plays sound without uploading any.
A game's own choices in the Music & sounds dialog win over these. Every file
here must be listed in `CREDITS.md` with its source and licence (a test checks
this), and the in-app list in `lib/features/settings/sound_credits.dart`
must match.

## Where your own files go

| Your file | Put it here | Then |
|---|---|---|
| basic quiz music (loop) | `music/quiz_theme.mp3` | becomes the default board music |
| chill music (loop) | `music/chill.mp3` | default calm music |
| exciting music (loop) | `music/thrilling.mp3` | default thrilling music |
| answer correct | `effects/right_answer/<name>.mp3` | one more right-answer choice |
| answer wrong | `effects/wrong_answer/<name>.mp3` | one more wrong-answer choice |
| answer correct, expanded (fanfare) | `effects/fanfare/<name>.mp3` | one more fanfare choice |
| buzzer badass | `buzzers/power.mp3` | team buzzer choice "Power" |
| buzzer fun | `buzzers/funny.mp3` | team buzzer choice "Funny" |

Any name works inside an effects folder; tell Claude which file should be the
default for its moment. Add the source and licence of each to `CREDITS.md`.
Music folders are listed in `pubspec.yaml`; a new effects folder needs a line
there too.

## What plays when

| Folder | Moment | Default |
|---|---|---|
| `effects/right_answer/` | a team answers right | Ding ding |
| `effects/wrong_answer/` | a team answers wrong | Bwomp |
| `effects/reveal/` | a reveal step, Feud answer, Connections group | Pluck |
| `effects/question_open/` | a question opens | Brass stab |
| `effects/lock_in/` | a team locks its answer in | Pop |
| `effects/next_item/` | the next Fragenhagel item | Woodblock |
| `effects/countdown/` | the last 10 seconds of a timer of 20 s or more | Ticking clock |
| `effects/times_up/` | a timer runs out | Game-show buzzer |
| `effects/steal/` | Feud: the third strike | Riser |
| `effects/fanfare/` | a question fully solved | Fanfare |
| `effects/applause/`, `drumroll/`, `joke/`, `announcer/` | by hand, from the Effects sheet | |
| `buzzers/` | a team's buzzer, chosen on the Buzzers page | Classic (`assets/buzzer.mp3`) |
| `ambience/` | keeps the speakers awake when nothing plays | Soft noise |

Generated sounds come from `tool/make_noise.js`, `tool/make_effects*.js` and
`tool/synth.js`.
