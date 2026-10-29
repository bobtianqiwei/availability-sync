# Availability Sync

Availability Sync is a macOS utility for sharing your availability with coworkers. It copies busy time from personal calendars into the work calendar connected to your work email account, so your team can see when you are unavailable without seeing private event details.

The app works with calendar accounts already added to macOS. All processing happens locally through EventKit. There is no server, account login, analytics, or telemetry.

## Download

[Download Availability Sync for macOS](https://github.com/bobtianqiwei/availability-sync/releases/latest/download/Availability-Sync.zip)

Unzip the download, then drag `Availability Sync.app` into Applications.

## Features

- Sync multiple source calendars into one target calendar
- Choose `Title`, `Busy`, or `Ignore` for each source calendar
- Add a 5, 10, 15, or 30 minute buffer to selected calendars
- Configure past and future sync ranges
- Sync automatically while the app is running
- Check for, download, and install app updates automatically
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

`Busy` events include only the start time, end time, availability, and a public note explaining that Availability Sync created the event. They never copy the original title, calendar name, account name, source notes, location, URL, attendees, organizer, or alarms. Sync matching information stays local to the app.

Calendar data stays in EventKit and in the calendar accounts already configured on your Mac.

## iCloud settings

Enable `Sync settings with iCloud` on Macs using the same Apple Account. It shares sync ranges, interval, buffer time, all-day blocked words, duplicate merging, and the option to delete older synced events. When enabled, existing iCloud values take priority; later changes sync automatically and may take time to arrive.

Calendar choices, per-calendar rules, event mappings, last sync time, login startup, and icon preferences stay on each Mac. No event data is uploaded to iCloud by this feature. Keep only one Mac syncing events to a given target calendar to avoid conflicting changes. Turning off settings sync keeps local settings and leaves the iCloud copy available to other Macs.

## Build

1. Open `Availability Sync.xcodeproj` in Xcode 26.4 or later.
2. Select the `Availability Sync` scheme and `My Mac`.
3. Press Run.

For iCloud settings sync, select your paid Apple Developer team and enable **iCloud → Key-value storage** in Signing & Capabilities for this app's identifier. Regenerate the provisioning profile if needed. All builds must use the same team and iCloud key-value store identifier. Unsigned builds can test local behavior, but cannot verify real iCloud delivery.

If Calendar access was previously denied, enable it in **System Settings → Privacy & Security → Calendars**.

## License

MIT. See [LICENSE](LICENSE).
