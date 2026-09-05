# Availability Sync

Availability Sync is a small, local-only macOS utility that copies busy time from multiple EventKit calendars into one target calendar. It is built with SwiftUI and EventKit for macOS 14 or later.

The app has no server component, external calendar API, login flow, analytics, or telemetry. Calendar data stays in EventKit on your Mac and in the calendar accounts already configured in macOS.

## Features

- Detects every event calendar available through EventKit
- Excludes the selected target calendar from the source list
- Supports `Show Title`, `Busy Only`, and `Ignore` rules for each source calendar
- Syncs from now, 2 days, 1 week, or 1 month in the past through 1, 2, 4, 6, or 12 months in the future
- Runs automatically every 1, 3, 5, 10, 15, 30, or 60 minutes while the app is open
- Can register itself as a macOS login item
- Expands recurring EventKit events into occurrences in the selected range
- Skips canceled events and events explicitly marked as free
- Updates or removes stale managed events on later syncs
- Optionally merges exact-time duplicates
- Stores settings in `UserDefaults`

## Build and run

1. Open `Availability Sync.xcodeproj` in Xcode 26.4 or later.
2. Select the `Availability Sync` scheme and `My Mac` as the run destination.
3. Press **Run** or use **Product → Build**.
4. Grant Full Calendar Access when macOS asks.
5. Select a writable target calendar.
6. Review every source calendar rule, then click **Sync Now**.

The project uses local ad-hoc signing by default, so it can build without a paid Apple Developer account. If your Xcode setup requires a team, select the app target, open **Signing & Capabilities**, and choose your personal team.

For a stable Launch at Login registration, archive or copy the built app to `/Applications`, launch that copy, and enable **Launch at Login**. macOS may ask you to approve it in **System Settings → General → Login Items**.

## Calendar permission

The app requests full EventKit access because it must read source events and create, update, and delete its own events in the target calendar.

If access was denied or limited to write-only access:

1. Open **System Settings → Privacy & Security → Calendars**.
2. Enable full access for the app.
3. Return to the app and click **Check Again**.

The sandbox Calendar entitlement and permission usage descriptions are included in the Xcode project.

## Usage

Choose a target calendar first. It must be writable. The target is removed from the source list and is always excluded by the sync engine, even if settings data is edited outside the app.

Each newly detected source calendar starts in `Busy Only` mode as a privacy-safe default:

- **Show Title** copies the source event title. Empty titles become `Busy`.
- **Busy Only** creates an event titled `Busy` and copies only its start time, end time, and all-day state.
- **Ignore** excludes the calendar and removes previously synced events that are no longer desired during the next sync.

Settings changes take effect on the next manual or automatic sync. Closing the window leaves a normal macOS app running; quitting the app stops its timer. Launch at Login opens the app again at the next login.

## Sync and deduplication behavior

EventKit expands recurring series into concrete occurrences in the requested date range. The target contains standalone managed occurrences, which allows a changed or deleted occurrence to be reconciled on the next sync.

When duplicate merging is enabled, source events with the same start, end, and all-day value are grouped:

- Multiple `Busy Only` events become one `Busy` event.
- Repeated visible titles are collapsed case-insensitively.
- A visible-title event suppresses redundant `Busy` copies for the same exact interval.
- Different visible titles at the same exact interval remain separate.

When duplicate merging is disabled, each source occurrence produces its own target event.

The app writes an opaque managed marker into the notes field. It reconciles only events carrying its current or legacy marker. Unrelated events in the target calendar are never changed or deleted. If the target calendar is changed, managed events in previously selected targets are removed during the next sync while unrelated events remain untouched.

## Privacy behavior

`Busy Only` target events contain:

- Title: `Busy`
- Start and end dates
- All-day state
- Busy availability
- An opaque sync marker

They do not copy the original title, source calendar name, source/account name, notes, location, URL, alarms, attendees, organizer, or recurrence data. The marker contains no readable source metadata. All processing happens locally through EventKit.

## Tests

Run the included planner and privacy tests with:

```sh
xcodebuild test -project "Availability Sync.xcodeproj" -scheme "Availability Sync" -destination 'platform=macOS'
```

## Project structure

```text
AvailabilitySync/
├── App/          App entry point and coordination
├── Models/       Calendar rules and sync result models
├── Services/     EventKit access, planning, reconciliation, and login item support
├── Settings/     UserDefaults-backed settings
└── Views/        SwiftUI interface
```

## License

MIT. See [LICENSE](LICENSE).
