// ContentView.swift developed by Bob Tianqi Wei

import AppKit
import SwiftUI
import UniformTypeIdentifiers

struct ContentView: View {
  @ObservedObject var model: AppModel
  @ObservedObject var settings: SettingsStore
  @Binding var showMenuBarIcon: Bool
  @Binding var showDockIcon: Bool
  @State private var calendarDropPosition: CalendarDropPosition?
  @State private var isDraggingCalendar = false

  var body: some View {
    Group {
      if model.eventKit.permissionStatus.canReadEvents {
        settingsContent
      } else {
        permissionContent
      }
    }
    .background(Color(nsColor: .windowBackgroundColor))
    .onChange(of: showDockIcon) { _, isVisible in
      NSApplication.shared.setActivationPolicy(isVisible ? .regular : .accessory)
    }
  }

  private var settingsContent: some View {
    VStack(spacing: 0) {
      TabView {
        Form {
          targetSection
          sourceSection
        }
        .formStyle(.grouped)
        .tabItem { Label("Calendars", systemImage: "calendar") }

        rulesContent
          .tabItem { Label("Sync Rules", systemImage: "slider.horizontal.3") }
        generalContent
          .tabItem { Label("General", systemImage: "gearshape") }
      }
      .padding(.top, 12)
      Divider()
      syncFooter.padding(16)
    }
  }

  private var targetSection: some View {
    Section("Destination") {
      Picker(
        "Target Calendar",
        selection: Binding(
          get: { settings.targetCalendarIdentifier },
          set: { model.setTargetCalendar($0) }
        )
      ) {
        Text("Choose a calendar…").tag("")
        ForEach(model.writableCalendars) { calendar in
          Label {
            Text(calendar.displayName)
          } icon: {
            Image(systemName: "circle.fill")
              .foregroundStyle(calendar.color)
          }
          .tag(calendar.id)
        }
      }

    }
  }

  private var sourceSection: some View {
    Section {
      if model.sourceCalendars.isEmpty {
        Text("No source calendars are available.")
          .foregroundStyle(.secondary)
          .frame(maxWidth: .infinity, minHeight: 80)
      } else {
        VStack(spacing: 0) {
        HStack(spacing: 10) {
          Text("Calendar").frame(maxWidth: .infinity, alignment: .leading)
          Text("Buffer").frame(width: 52)
          Text("Sync options").frame(width: 180)
        }
        .font(.caption)
        .foregroundStyle(.secondary)
        .padding(.vertical, 3)
        ForEach(model.sourceCalendars) { calendar in
          Divider()
          CalendarRuleRow(
            calendar: calendar,
            mode: Binding(
              get: { settings.mode(for: calendar.id) },
              set: { settings.setMode($0, for: calendar.id) }
            ),
            bufferEnabled: Binding(
              get: { settings.isBufferEnabled(for: calendar.id) },
              set: { settings.setBufferEnabled($0, for: calendar.id) }
            ),
            dropPosition: $calendarDropPosition,
            isDragging: $isDraggingCalendar,
            move: { identifier, after in
              withAnimation(.easeInOut(duration: 0.2)) {
                settings.moveCalendar(identifier, to: calendar.id, after: after, in: model.sourceCalendars)
              }
            }
          )
        }
        .animation(.easeInOut(duration: 0.2), value: model.sourceCalendars.map(\.id))
        .onDisappear {
          calendarDropPosition = nil
          isDraggingCalendar = false
        }
        }
      }
    } header: {
      Text("Source Calendars")
    } footer: {
      Text("Title keeps event names. Busy shows events as “Busy”. Ignore excludes the calendar.")
    }
  }

  private var rulesContent: some View {
    Form {
      Section("Schedule") {
        LabeledContent("Sync range") {
          HStack(spacing: 10) {
            Text("Past")
              .foregroundStyle(.secondary)
            Picker("Past", selection: $settings.pastRange) {
              ForEach(PastRange.allCases) { range in
                Text(range.label).tag(range)
              }
            }
            .labelsHidden()
            .fixedSize()
            .frame(width: 100, alignment: .trailing)

            Text("Future")
              .foregroundStyle(.secondary)
            Picker("Future", selection: $settings.rangeMonths) {
              ForEach([1, 2, 4, 6, 12], id: \.self) { months in
                Text("\(months) \(months == 1 ? "month" : "months")").tag(months)
              }
            }
            .labelsHidden()
            .fixedSize()
            .frame(width: 105, alignment: .trailing)
          }
        }

        LabeledContent("Automatic sync") {
          Picker("Automatic sync", selection: $settings.syncIntervalMinutes) {
            ForEach([1, 3, 5, 10, 15, 30, 60], id: \.self) { minutes in
              Text("Every \(minutes) min").tag(minutes)
            }
          }
          .labelsHidden()
          .fixedSize()
          .frame(width: 140, alignment: .trailing)
        }
      }

      Section("Event Processing") {
        VStack(alignment: .leading, spacing: 6) {
          LabeledContent("Buffer time") {
            Picker("Buffer time", selection: $settings.bufferMinutes) {
              ForEach([5, 10, 15, 30], id: \.self) { minutes in
                Text("\(minutes) min").tag(minutes)
              }
            }
            .labelsHidden()
            .fixedSize()
            .frame(width: 140, alignment: .trailing)
          }

          Text("Adds this time before and after events from calendars with Buffer enabled.")
            .font(.caption)
            .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)

        Toggle("Merge duplicate events", isOn: $settings.mergeDuplicates)
        VStack(alignment: .leading, spacing: 6) {
          KeywordTagsField(value: $settings.allDayBlockedWords)
          Text("Skip all-day events with these words in their titles.")
            .font(.caption)
            .foregroundStyle(.secondary)
        }
      }

      Section("Cleanup") {
        VStack(alignment: .leading, spacing: 6) {
          Toggle(
            "Delete synced events before range",
            isOn: $settings.deleteEventsBeforeSyncRange
          )
          Text("When enabled, removes synced events before the selected Past range.")
            .font(.caption)
            .foregroundStyle(.secondary)
        }
      }
    }
    .formStyle(.grouped)
  }

  private var generalContent: some View {
    Form {
      Section("iCloud") {
        VStack(alignment: .leading, spacing: 6) {
          Toggle("Sync settings with iCloud", isOn: $settings.iCloudSyncEnabled)
          if settings.iCloudSyncEnabled {
            Text(settings.iCloudStatus)
              .font(.caption)
              .foregroundStyle(.secondary)
          }
          Text(
            "Shares sync rules and calendar order. Calendar choices stay on this Mac. Use one Mac to sync events to each target calendar."
          )
          .font(.caption)
          .foregroundStyle(.secondary)
        }
      }
      Section("App") {
        Toggle(
          "Show Menu Bar Icon",
          isOn: Binding(
            get: { showMenuBarIcon },
            set: { isVisible in
              showMenuBarIcon = isVisible
              if !isVisible {
                showDockIcon = true
              }
            }
          ))
        Toggle(
          "Show Dock Icon",
          isOn: Binding(
            get: { showDockIcon },
            set: { isVisible in
              showDockIcon = isVisible
              if !isVisible {
                showMenuBarIcon = true
              }
            }
          ))
        Toggle(
          "Launch at Login",
          isOn: Binding(
            get: { settings.launchAtLogin },
            set: { model.setLaunchAtLogin($0) }
          ))
      }
      Section("About") {
        Link(
          "GitHub: bobtianqiwei/availability-sync",
          destination: URL(string: "https://github.com/bobtianqiwei/availability-sync")!)
      }
    }
    .formStyle(.grouped)
  }

  private var syncFooter: some View {
    HStack(alignment: .center) {
      VStack(alignment: .leading, spacing: 4) {
        if let lastSyncDate = settings.lastSyncDate {
          Text("Last sync: \(lastSyncDate.formatted(date: .abbreviated, time: .shortened))")
            .font(.subheadline.weight(.medium))
        } else {
          Text("Not synced yet")
            .font(.subheadline.weight(.medium))
        }

        if let detail = model.syncState.detail {
          Text(detail)
            .font(.caption)
            .foregroundStyle(model.syncState.isFailure ? .red : .secondary)
        } else {
          Text("Automatic sync continues while the app is running.")
            .font(.caption)
            .foregroundStyle(.secondary)
        }
      }

      Spacer()
      Button {
        Task { await model.syncNow() }
      } label: {
        HStack(spacing: 7) {
          if model.syncState == .syncing {
            ProgressView().controlSize(.small)
          } else {
            Image(systemName: "arrow.triangle.2.circlepath")
          }
          Text(model.syncState == .syncing ? "Syncing…" : "Sync Now")
        }
        .frame(minWidth: 100)
      }
      .buttonStyle(.borderedProminent)
      .controlSize(.large)
      .disabled(!model.canSync)
    }
    .padding(.top, 2)
  }

  private var permissionContent: some View {
    VStack(spacing: 16) {
      Spacer()
      Image(systemName: "calendar.badge.exclamationmark")
        .font(.system(size: 46, weight: .light))
        .foregroundStyle(.secondary)
      Text("Calendar Access Required")
        .font(.title2.weight(.semibold))
      Text(permissionMessage)
        .multilineTextAlignment(.center)
        .foregroundStyle(.secondary)
        .frame(maxWidth: 430)

      HStack {
        if model.eventKit.permissionStatus == .notDetermined {
          Button("Grant Calendar Access") {
            Task { await model.requestCalendarAccess() }
          }
          .buttonStyle(.borderedProminent)
        } else {
          Button("Open Privacy Settings") {
            model.eventKit.openCalendarPrivacySettings()
          }
          .buttonStyle(.borderedProminent)
          Button("Check Again") {
            model.eventKit.refreshCalendars()
          }
        }
      }
      Spacer()
    }
    .padding(32)
    .frame(maxWidth: .infinity, maxHeight: .infinity)
  }

  private var permissionMessage: String {
    switch model.eventKit.permissionStatus {
    case .notDetermined:
      "Availability Sync needs full Calendar access to read source events and update your chosen target calendar."
    case .writeOnly:
      "Write-only access cannot read source calendars. Allow Full Access in System Settings."
    case .denied, .restricted:
      "Allow Full Calendar Access in System Settings → Privacy & Security → Calendars."
    case .fullAccess:
      ""
    }
  }
}

private struct KeywordTagsField: View {
  @Binding var value: String
  @State private var draft = ""
  @FocusState private var isFocused: Bool

  private var words: [String] {
    var seen = Set<String>()
    return value.components(separatedBy: CharacterSet(charactersIn: ",，\n"))
      .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
      .filter { !$0.isEmpty && seen.insert($0.lowercased()).inserted }
  }

  var body: some View {
    VStack(alignment: .leading, spacing: 8) {
      Text("All-day blocked words")
      if !words.isEmpty {
        KeywordTagLayout {
          ForEach(words, id: \.self) { word in
            HStack(spacing: 5) {
              Text(word).lineLimit(1).help(word)
              Button {
                value = words.filter { $0 != word }.joined(separator: ", ")
              } label: {
                Image(systemName: "xmark").font(.caption2)
              }
              .buttonStyle(.plain)
              .accessibilityLabel("Remove \(word)")
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(.quaternary, in: Capsule())
          }
        }
      }
      HStack(alignment: .center, spacing: 8) {
        TextField("Add a word…", text: $draft)
          .labelsHidden()
          .textFieldStyle(.plain)
          .padding(.horizontal, 8)
          .frame(height: 28)
          .background(.background, in: RoundedRectangle(cornerRadius: 6))
          .overlay {
            RoundedRectangle(cornerRadius: 6)
              .stroke(isFocused ? Color.accentColor : Color(nsColor: .separatorColor), lineWidth: 1)
          }
          .focused($isFocused)
          .onSubmit(addWords)
        Button(action: addWords) {
          Text("Add")
            .frame(width: 52, height: 28)
            .background(.quaternary, in: RoundedRectangle(cornerRadius: 6))
            .contentShape(RoundedRectangle(cornerRadius: 6))
        }
        .buttonStyle(.plain)
        .disabled(draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
      }
    }
    .onChange(of: isFocused) { _, focused in
      if !focused { addWords() }
    }
    .onDisappear(perform: addWords)
  }

  private func addWords() {
    let additions = draft.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !additions.isEmpty else { return }
    value = (words + [additions]).joined(separator: ", ")
    draft = ""
  }
}

private struct KeywordTagLayout: Layout {
  private let spacing: CGFloat = 4

  func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
    arrange(subviews, width: proposal.width ?? .infinity).size
  }

  func placeSubviews(
    in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()
  ) {
    let arrangement = arrange(subviews, width: bounds.width)
    for (index, subview) in subviews.enumerated() {
      let point = arrangement.positions[index]
      subview.place(
        at: CGPoint(x: bounds.minX + point.x, y: bounds.minY + point.y),
        proposal: ProposedViewSize(
          width: min(subview.sizeThatFits(.unspecified).width, bounds.width), height: nil))
    }
  }

  private func arrange(_ subviews: Subviews, width: CGFloat) -> (size: CGSize, positions: [CGPoint])
  {
    var positions: [CGPoint] = []
    var x: CGFloat = 0
    var y: CGFloat = 0
    var rowHeight: CGFloat = 0
    var usedWidth: CGFloat = 0
    for subview in subviews {
      let size = subview.sizeThatFits(ProposedViewSize(width: width, height: nil))
      if x > 0 && x + size.width > width {
        x = 0
        y += rowHeight + spacing
        rowHeight = 0
      }
      positions.append(CGPoint(x: x, y: y))
      usedWidth = max(usedWidth, x + size.width)
      x += size.width + spacing
      rowHeight = max(rowHeight, size.height)
    }
    return (CGSize(width: usedWidth, height: y + rowHeight), positions)
  }
}

private struct CalendarDropPosition: Equatable {
  let calendarIdentifier: String
  let after: Bool
}

private struct CalendarRuleRow: View {
  let calendar: CalendarInfo
  @Binding var mode: CalendarMode
  @Binding var bufferEnabled: Bool
  @Binding var dropPosition: CalendarDropPosition?
  @Binding var isDragging: Bool
  let move: (String, Bool) -> Bool
  @State private var rowHeight: CGFloat = 40

  private var insertionAfter: Bool? {
    isDragging && dropPosition?.calendarIdentifier == calendar.id ? dropPosition?.after : nil
  }

  var body: some View {
    HStack(spacing: 10) {
      HStack(spacing: 10) {
        Circle()
          .fill(calendar.color)
          .frame(width: 10, height: 10)
        VStack(alignment: .leading, spacing: 1) {
          Text(calendar.title)
            .lineLimit(1)
            .help(calendar.title)
          Text(calendar.sourceTitle)
            .font(.caption)
            .foregroundStyle(.secondary)
            .lineLimit(1)
        }
      }
      .frame(maxWidth: .infinity, alignment: .leading)
      .contentShape(Rectangle())
      .overlay {
        CalendarDragSource(identifier: calendar.id, title: calendar.title) { active in
          isDragging = active
          dropPosition = nil
        }
      }

      Toggle("Buffer", isOn: $bufferEnabled)
        .labelsHidden()
        .toggleStyle(.checkbox)
        .frame(width: 52)
        .disabled(mode == .ignore)

      Picker("Mode", selection: $mode) {
        ForEach(CalendarMode.allCases) { mode in
          Text(mode.label).tag(mode)
        }
      }
      .labelsHidden()
      .pickerStyle(.segmented)
      .frame(width: 180)
    }
    .padding(.vertical, 3)
    .background {
      GeometryReader { geometry in
        Color.clear
          .onAppear { rowHeight = geometry.size.height }
          .onChange(of: geometry.size.height) { _, height in rowHeight = height }
      }
    }
    .overlay {
      GeometryReader { geometry in
        if let after = insertionAfter {
          Capsule().fill(Color.accentColor).frame(height: 2)
            .offset(y: after ? max(0, geometry.size.height - 2) : 0)
            .transition(.identity)
        }
      }
      .allowsHitTesting(false)
      .transaction {
        $0.animation = nil
        $0.disablesAnimations = true
      }
    }
    .onDrop(of: [UTType.text], delegate: CalendarReorderDropDelegate(
      calendarIdentifier: calendar.id, rowHeight: rowHeight, dropPosition: $dropPosition,
      isDragging: $isDragging, move: move
    ))
  }
}

private struct CalendarReorderDropDelegate: DropDelegate {
  let calendarIdentifier: String
  let rowHeight: CGFloat
  @Binding var dropPosition: CalendarDropPosition?
  @Binding var isDragging: Bool
  let move: (String, Bool) -> Bool

  func dropEntered(info: DropInfo) {
    guard isDragging else { dropPosition = nil; return }
    dropPosition = CalendarDropPosition(calendarIdentifier: calendarIdentifier, after: info.location.y > rowHeight / 2)
  }
  func dropUpdated(info: DropInfo) -> DropProposal? {
    guard isDragging else { return DropProposal(operation: .cancel) }
    dropEntered(info: info)
    return DropProposal(operation: .move)
  }
  func dropExited(info: DropInfo) {
    if dropPosition?.calendarIdentifier == calendarIdentifier { dropPosition = nil }
  }
  func performDrop(info: DropInfo) -> Bool {
    let after = info.location.y > rowHeight / 2
    dropPosition = nil
    guard isDragging else { return false }
    isDragging = false
    guard let provider = info.itemProviders(for: [UTType.text]).first,
          provider.canLoadObject(ofClass: NSString.self) else { return false }
    _ = provider.loadObject(ofClass: NSString.self) { value, _ in
      guard let identifier = value as? String else { return }
      Task { @MainActor in
        _ = move(identifier, after)
        dropPosition = nil
      }
    }
    return true
  }
}

private struct CalendarDragSource: NSViewRepresentable {
  let identifier: String
  let title: String
  let activityChanged: (Bool) -> Void

  func makeNSView(context: Context) -> CalendarDragView { CalendarDragView() }

  func updateNSView(_ view: CalendarDragView, context: Context) {
    view.calendarIdentifier = identifier
    view.title = title
    view.activityChanged = activityChanged
  }
}

private final class CalendarDragView: NSView, NSDraggingSource {
  var calendarIdentifier = ""
  var title = ""
  var activityChanged: ((Bool) -> Void)?
  private var mouseDownPoint: NSPoint?
  private var dragging = false

  override func mouseDown(with event: NSEvent) {
    mouseDownPoint = convert(event.locationInWindow, from: nil)
  }

  override func mouseUp(with event: NSEvent) { mouseDownPoint = nil }

  override func mouseDragged(with event: NSEvent) {
    guard !dragging, let start = mouseDownPoint else { return }
    let point = convert(event.locationInWindow, from: nil)
    guard hypot(point.x - start.x, point.y - start.y) >= 3 else { return }
    dragging = true
    mouseDownPoint = nil
    activityChanged?(true)
    let previewTitle = title
    let image = NSImage(size: bounds.size, flipped: false) { rect in
      (previewTitle as NSString).draw(in: rect.insetBy(dx: 6, dy: 4), withAttributes: [
        .font: NSFont.systemFont(ofSize: NSFont.systemFontSize),
        .foregroundColor: NSColor.labelColor
      ])
      return true
    }
    let item = NSDraggingItem(pasteboardWriter: calendarIdentifier as NSString)
    item.setDraggingFrame(bounds, contents: image)
    let session = beginDraggingSession(with: [item], event: event, source: self)
    session.animatesToStartingPositionsOnCancelOrFail = true
  }

  func draggingSession(_ session: NSDraggingSession, sourceOperationMaskFor context: NSDraggingContext) -> NSDragOperation {
    context == .withinApplication ? .move : []
  }

  func draggingSession(_ session: NSDraggingSession, endedAt screenPoint: NSPoint, operation: NSDragOperation) {
    dragging = false
    mouseDownPoint = nil
    activityChanged?(false)
  }

  func ignoreModifierKeys(for session: NSDraggingSession) -> Bool { true }
}

extension CalendarInfo {
  fileprivate var color: Color {
    Color(red: red, green: green, blue: blue)
  }
}

extension SyncState {
  fileprivate var isFailure: Bool {
    if case .failure = self { return true }
    return false
  }
}
