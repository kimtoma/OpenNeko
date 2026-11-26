import EventKit
import Foundation
import OpenNekoKit

/// Reads today's calendar events and open reminders from EventKit and keeps
/// a small cache of titles and times. Nothing else (notes, attendees,
/// locations) is copied. What to do with them lives in `DayContext`.
final class DayContextProvider {
    private let store = EKEventStore()
    private(set) var events: [DayEvent] = []
    private(set) var reminders: [DayReminder] = []
    private var refreshTimer: Timer?
    private var changeObserver: NSObjectProtocol?

    var isAuthorized: Bool {
        EKEventStore.authorizationStatus(for: .event) == .fullAccess
    }

    /// Asks for calendar access (and reminders, which may be declined on
    /// their own). Calls back on the main queue with calendar access.
    func requestAccess(completion: @escaping (Bool) -> Void) {
        store.requestFullAccessToEvents { [weak self] granted, _ in
            self?.store.requestFullAccessToReminders { _, _ in
                DispatchQueue.main.async { completion(granted) }
            }
        }
    }

    /// Starts refreshing every five minutes and when the calendar changes.
    func start() {
        stop()
        refresh()
        let timer = Timer(timeInterval: 300, repeats: true) { [weak self] _ in
            self?.refresh()
        }
        RunLoop.main.add(timer, forMode: .common)
        refreshTimer = timer
        changeObserver = NotificationCenter.default.addObserver(
            forName: .EKEventStoreChanged,
            object: store,
            queue: .main
        ) { [weak self] _ in
            self?.refresh()
        }
    }

    func stop() {
        refreshTimer?.invalidate()
        refreshTimer = nil
        if let changeObserver {
            NotificationCenter.default.removeObserver(changeObserver)
        }
        changeObserver = nil
        events = []
        reminders = []
    }

    func refresh() {
        guard isAuthorized else {
            events = []
            reminders = []
            return
        }
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: Date())
        guard let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay) else { return }

        let predicate = store.predicateForEvents(withStart: startOfDay, end: endOfDay, calendars: nil)
        events = store.events(matching: predicate).map { event in
            DayEvent(
                title: event.title ?? "",
                start: event.startDate,
                end: event.endDate,
                isAllDay: event.isAllDay
            )
        }

        guard EKEventStore.authorizationStatus(for: .reminder) == .fullAccess else {
            reminders = []
            return
        }
        let reminderPredicate = store.predicateForIncompleteReminders(
            withDueDateStarting: nil,
            ending: endOfDay,
            calendars: nil
        )
        store.fetchReminders(matching: reminderPredicate) { [weak self] found in
            let items = (found ?? []).map { reminder in
                DayReminder(
                    title: reminder.title ?? "",
                    due: reminder.dueDateComponents.flatMap { calendar.date(from: $0) }
                )
            }
            DispatchQueue.main.async {
                self?.reminders = items
            }
        }
    }
}
