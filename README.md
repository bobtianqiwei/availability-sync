# Availability Sync

A macOS utility for sharing availability with coworkers. Copy busy time from personal calendars into your work calendar while keeping private details private.

[Download for macOS 14+](https://github.com/bobtianqiwei/availability-sync/releases/latest/download/Availability-Sync.zip). Unzip and move Availability Sync.app to Applications.

## Use

Grant Full Calendar Access, choose a target, and select **Title**, **Busy**, or **Ignore** for each source calendar. Title keeps event names; Busy hides them. Click **Sync Now**, or sync automatically while the app is running.

- Set past and future ranges, sync intervals, and per-calendar buffers.
- Sync recurring and multi-day all-day events, merge duplicates, and filter all-day events by keywords.
- Keep older synced events by default, with optional cleanup.
- Use the menu bar, hide the Dock icon, and launch at login.
- Optionally share general settings through iCloud and install app updates automatically.

Calendar choices and per-calendar rules stay on each Mac. Use one Mac to sync events to each target calendar to avoid conflicts.

## Screenshots

<img src="docs/screenshots/calendars.png" alt="Calendars" width="32%"> <img src="docs/screenshots/sync-rules.png" alt="Sync Rules" width="32%"> <img src="docs/screenshots/general.png" alt="General" width="32%">

## Privacy

Calendar processing runs locally through EventKit using accounts already added to macOS. There is no app account, server, analytics, or telemetry. Busy events omit source titles, notes, locations, attendees, and account details. The target is excluded from sources; unrelated target events are left untouched.

Optional iCloud sync shares general settings, including blocked words, without uploading event data or event mappings.

## Build

Open `Availability Sync.xcodeproj` in Xcode, select Availability Sync and My Mac, then Run. For iCloud, select your Apple Developer team and enable **iCloud → Key-value storage** in Signing & Capabilities. Use the same team and key-value store identifier across builds.

## License

MIT. See [LICENSE](LICENSE).
