# tool/

Helpers for development. Nothing here ships with the app.

## Screens without a device (golden tests)

Each test draws screens with sample data into PNG files you can look at.
`--update-goldens` writes the pictures; without it the test compares against
the committed ones and puts the differences into `tool/failures/` (ignored by git).
Rendering differs slightly between Windows and Linux, so a plain run on the
other system reports small pixel differences; these are previews, not CI checks.

| Command | Writes |
| --- | --- |
| `flutter test tool/screenshot_test.dart --update-goldens` | `tool/screenshots/`: sessions, controller, presenter, editors, buzzers, account |
| `flutter test tool/rating_screenshot_test.dart --update-goldens` | `tool/screenshots/`: top answers and rating |
| `flutter test tool/store_screenshots_test.dart --update-goldens` | `screenshots/<store size>/` for the store listings and `docs/images/` for the README and the website |
| `flutter test tool/default_images_test.dart --update-goldens` | `assets/cards/`: the pictures that come with the app (then convert to JPEG, see the end of the file) |

`tool/store/showcase.dart` is the sample quiz the store screenshots show.

## Built-in sounds (`tool/sounds/`, Node.js, no packages needed)

| Command | Writes |
| --- | --- |
| `node tool/sounds/make_effects.js` | the effects in `assets/sounds/effects/` |
| `node tool/sounds/make_noise.js` | the noise loops in `assets/sounds/ambience/` |
| `node tool/sounds/make_effects2.js <folder>` / `make_effects3.js <folder>` | more variants into a folder of your choice, to pick from |

`synth.js` is the small synthesiser those scripts share. Which sounds came from
where is in `assets/sounds/CREDITS.md`.
