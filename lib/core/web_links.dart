/// Links that leave the app (QR codes, copied invites) are web links: a phone's
/// camera app opens those, while it ignores the app's own `quiz-studio://`
/// scheme. The page behind them (docs/open.html on GitHub Pages) hands the
/// same path to the app. Everything after the `#` stays in the browser, so a
/// session token never reaches a server.
library;

const String appLinkScheme = 'quiz-studio://';
const String webLinkBase = 'https://equirinya.github.io/quiz_studio/open.html#';

/// [appLink] (`quiz-studio://…`) as a web link.
String toWebLink(String appLink) =>
    appLink.startsWith(appLinkScheme) ? '$webLinkBase${appLink.substring(appLinkScheme.length)}' : appLink;

/// [input] in the app's own form: a web link becomes a `quiz-studio://` one,
/// anything else is returned trimmed.
String toAppLink(String input) {
  final text = input.trim();
  return text.startsWith(webLinkBase) ? '$appLinkScheme${text.substring(webLinkBase.length)}' : text;
}
