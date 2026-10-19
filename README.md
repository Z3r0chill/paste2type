# Paste2Type

A small macOS app for typing text into a website that blocks paste.
Paste into the app, click **Start Typing**, and it returns to the previous app
and sends keyboard events at roughly 50 characters per second.

## Use

1. Open `build/Paste2Type.app`.
2. Click **Enable Accessibility…** and allow Paste2Type in **System Settings →
   Privacy & Security → Accessibility**. Reopen Paste2Type if macOS still reports
   permission missing.
3. Click the destination field in your browser, leaving the cursor where you
   want the text inserted.
4. Switch back to Paste2Type and paste your text into its box.
5. Check the **Type into:** app name, then click **Start Typing**. Typing begins
   as soon as that app regains focus, with no countdown.

To stop, switch back to Paste2Type (or any other app), or hold **Esc**.
The **Stop** button also cancels. Pressing a modifier key during typing stops
the run. If the destination app exposes its focused field through Accessibility,
changing fields stops the run too. Cancellation does not undo text already sent.

The app restores the previous application; that application's existing field
focus and caret determine the insertion point. It does not remember a separate
cursor position for each tab. Leave the intended field focused before starting.

Text stays in memory and disappears when the app quits. There is no telemetry,
network service, clipboard polling, or automatic form submission. macOS requires
Accessibility permission because the app sends keystrokes to another app.

## Build and test

Requires macOS 13 or later and Xcode command-line tools. No package installation.

```sh
./scripts/build.sh
open build/Paste2Type.app
./scripts/test.sh
```

The build is for your Mac's architecture and uses an ad-hoc signature for local
use. This is not a notarized distribution build. Keep the app at a stable path;
after rebuilding or moving it, macOS may require removing and re-adding its
Accessibility entry.

Open `tests/paste-blocked.html` in your browser to check behavior with a field
that explicitly rejects paste. Confirm normal paste is blocked, then send the
sample through Paste2Type and compare the output. Also try multiline text, emoji,
switching apps during a long run, holding Esc, and clicking the second field.

## Compatibility

This uses macOS keyboard events, not browser DOM events or a clipboard paste.
It sends Unicode text, including newline and tab characters, without physical
Return/Tab keycodes so they do not intentionally submit forms or navigate fields.
Handling varies across apps, websites, and input methods; verify the result in
your destination before submitting. A completed run means the events were sent,
not that the destination accepted every character. Secure input and some custom
editors may reject generated events.

Apple documents that frameworks can ignore the Unicode payload and translate
the keycode themselves:
[Quartz keyboard Unicode strings](https://developer.apple.com/documentation/coregraphics/cgevent/keyboardsetunicodestring%28stringlength%3Aunicodestring%3A%29).
