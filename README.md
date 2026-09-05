# Availability Sync

Availability Sync is a macOS utility for sharing your availability with coworkers. It copies busy time from personal calendars into the work calendar connected to your work email account, so your team can see when you are unavailable without seeing private event details.

The app works with calendar accounts already added to macOS. All processing happens locally through EventKit. There is no server, account login, analytics, or telemetry.

## Features

- Sync multiple source calendars into one target calendar
- Choose `Title`, `Busy`, or `Ignore` for each source calendar
- Add a 5, 10, 15, or 30 minute buffer to selected calendars
- Configure past and future sync ranges
- Sync automatically while the app is running
- Handle recurring, updated, and deleted events
- Merge duplicate events and launch at login

## Usage

1. Grant Full Calendar Access.
2. Choose your work calendar as the target.
3. Configure each source calendar:
   - `Title` keeps event names.
   - `Busy` replaces event names with `Busy`.
   - `Ignore` excludes the calendar.
4. Enable Buffer for calendars that need extra time before and after events.
5. Click `Sync Now`.

The target calendar is never used as a source. Availability Sync only updates events it created and leaves unrelated target events untouched.

## Privacy

`Busy` events include only the start time, end time, availability, and an opaque sync marker. They never copy the original title, calendar name, account name, notes, location, URL, attendees, organizer, or alarms.

Calendar data stays in EventKit and in the calendar accounts already configured on your Mac.

## Build

1. Open `Availability Sync.xcodeproj` in Xcode 26.4 or later.
2. Select the `Availability Sync` scheme and `My Mac`.
3. Press Run.

If Calendar access was previously denied, enable it in **System Settings → Privacy & Security → Calendars**.

## License

MIT. See [LICENSE](LICENSE).
