import AppKit
import SwiftUI
import OpenNekoKit

/// Window for editing routines. The view edits a local copy and hands the
/// whole list back on Save; scheduling decisions live in OpenNekoKit
/// (`RoutineScheduler`).
final class RoutinesWindowController {
    private var window: NSWindow?
    private let languageCode: () -> String
    private let routines: () -> [Routine]
    private let save: ([Routine]) -> Void
    private let runNow: (Routine) -> Void

    init(
        languageCode: @escaping () -> String,
        routines: @escaping () -> [Routine],
        save: @escaping ([Routine]) -> Void,
        runNow: @escaping (Routine) -> Void
    ) {
        self.languageCode = languageCode
        self.routines = routines
        self.save = save
        self.runNow = runNow
    }

    func show() {
        let language = languageCode()
        let view = RoutinesView(
            languageCode: language,
            initial: routines(),
            save: { [weak self] edited in self?.save(edited) },
            runNow: { [weak self] routine in self?.runNow(routine) },
            close: { [weak self] in self?.window?.performClose(nil) }
        )
        if let window {
            (window.contentViewController as? NSHostingController<RoutinesView>)?.rootView = view
            window.title = RoutineCopy.text(.windowTitle, languageCode: language)
            window.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }
        let hosting = NSHostingController(rootView: view)
        let window = NSWindow(contentViewController: hosting)
        window.title = RoutineCopy.text(.windowTitle, languageCode: language)
        window.styleMask = [.titled, .closable, .resizable]
        window.isReleasedWhenClosed = false
        window.setContentSize(NSSize(width: 520, height: 560))
        window.center()
        self.window = window
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
}

struct RoutinesView: View {
    let languageCode: String
    let save: ([Routine]) -> Void
    let runNow: (Routine) -> Void
    let close: () -> Void

    @State private var routines: [Routine]
    @State private var status = ""

    init(
        languageCode: String,
        initial: [Routine],
        save: @escaping ([Routine]) -> Void,
        runNow: @escaping (Routine) -> Void,
        close: @escaping () -> Void
    ) {
        self.languageCode = languageCode
        self.save = save
        self.runNow = runNow
        self.close = close
        _routines = State(initialValue: initial)
    }

    private func copy(_ key: RoutineCopy.Key) -> String {
        RoutineCopy.text(key, languageCode: languageCode)
    }

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    if routines.isEmpty {
                        Text(copy(.empty))
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity, alignment: .center)
                            .padding(.vertical, 40)
                    }
                    ForEach($routines) { $routine in
                        RoutineCard(
                            routine: $routine,
                            languageCode: languageCode,
                            runNow: { runNow(routine.normalized()) },
                            delete: { routines.removeAll { $0.id == routine.id } }
                        )
                    }
                }
                .padding(16)
            }

            Divider()

            HStack {
                Menu(copy(.add)) {
                    ForEach(RoutineTemplate.allCases, id: \.self) { template in
                        Button(RoutineCopy.templateTitle(template, languageCode: languageCode)) {
                            add(template.routine(id: UUID().uuidString, languageCode: languageCode))
                        }
                    }
                    Divider()
                    Button(copy(.blank)) {
                        add(Routine(id: UUID().uuidString, title: "", prompt: "", hour: 9, minute: 0))
                    }
                }
                .fixedSize()
                .disabled(routines.count >= RoutineScheduler.maxRoutines)

                Text(status)
                    .font(.callout)
                    .foregroundStyle(.secondary)

                Spacer()

                Button(copy(.close), action: close)
                Button(copy(.save)) {
                    save(routines)
                    status = copy(.saved)
                }
                .keyboardShortcut(.defaultAction)
            }
            .padding(12)
        }
        .frame(minWidth: 480, minHeight: 420)
    }

    private func add(_ routine: Routine) {
        guard routines.count < RoutineScheduler.maxRoutines else {
            status = copy(.limitReached)
            return
        }
        routines.append(routine)
        status = ""
    }
}

private struct RoutineCard: View {
    @Binding var routine: Routine
    let languageCode: String
    let runNow: () -> Void
    let delete: () -> Void
    @State private var folderError = ""

    private func copy(_ key: RoutineCopy.Key) -> String {
        RoutineCopy.text(key, languageCode: languageCode)
    }

    private var timeBinding: Binding<Date> {
        Binding(
            get: {
                Calendar.current.date(bySettingHour: routine.hour, minute: routine.minute, second: 0, of: Date()) ?? Date()
            },
            set: { date in
                let parts = Calendar.current.dateComponents([.hour, .minute], from: date)
                routine.hour = parts.hour ?? routine.hour
                routine.minute = parts.minute ?? routine.minute
            }
        )
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Toggle("", isOn: $routine.enabled)
                    .toggleStyle(.switch)
                    .labelsHidden()
                TextField(copy(.name), text: $routine.title)
                    .textFieldStyle(.roundedBorder)
                DatePicker("", selection: timeBinding, displayedComponents: .hourAndMinute)
                    .labelsHidden()
                    .fixedSize()
            }

            Picker("", selection: $routine.days) {
                ForEach(RoutineDays.allCases, id: \.self) { days in
                    Text(RoutineCopy.days(days, languageCode: languageCode)).tag(days)
                }
            }
            .pickerStyle(.segmented)
            .labelsHidden()

            Text(copy(.prompt))
                .font(.caption)
                .foregroundStyle(.secondary)
            TextEditor(text: $routine.prompt)
                .font(.body)
                .frame(minHeight: 56, maxHeight: 90)
                .overlay(RoundedRectangle(cornerRadius: 6).stroke(.quaternary))

            HStack(spacing: 6) {
                Image(systemName: "folder")
                    .foregroundStyle(.secondary)
                Text(routine.folder ?? copy(.folderNone))
                    .font(.callout)
                    .lineLimit(1)
                    .truncationMode(.middle)
                    .foregroundStyle(routine.folder == nil ? .secondary : .primary)
                Spacer()
                Button(copy(.chooseFolder), action: chooseFolder)
                if routine.folder != nil {
                    Button(copy(.clearFolder)) { routine.folder = nil }
                }
            }
            Text(folderError.isEmpty ? copy(.folderHint) : folderError)
                .font(.caption)
                .foregroundStyle(folderError.isEmpty ? Color.secondary : Color.red)

            HStack {
                Text(RoutineCopy.nextRun(
                    RoutineScheduler.nextRun(for: routine.normalized(), after: Date(), calendar: .current),
                    languageCode: languageCode,
                    calendar: .current
                ))
                .font(.caption)
                .foregroundStyle(.secondary)
                Spacer()
                Button(copy(.runNow), action: runNow)
                    .disabled(routine.normalized().prompt.isEmpty)
                    .help(routine.normalized().prompt.isEmpty ? copy(.needsPrompt) : "")
                Button(role: .destructive, action: delete) {
                    Text(copy(.delete))
                }
            }
        }
        .padding(12)
        .background(RoundedRectangle(cornerRadius: 10).fill(.quaternary.opacity(0.4)))
    }

    private func chooseFolder() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = false
        panel.canCreateDirectories = false
        panel.message = AgentTaskCopy.text(.pickFolderMessage, languageCode: languageCode)
        panel.prompt = AgentTaskCopy.text(.pickFolderButton, languageCode: languageCode)
        guard panel.runModal() == .OK, let url = panel.url else { return }
        switch AgentTaskFolderPolicy.validate(url.path, homeDirectory: NSHomeDirectory()) {
        case let .success(folder):
            routine.folder = folder
            folderError = ""
        case let .failure(rejection):
            folderError = AgentTaskCopy.folderRejected(rejection.reason, languageCode: languageCode)
        }
    }
}
