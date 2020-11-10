//
//  DataService.swift
//  deepday
//
//  Created by Jon Ator on 10/9/20.
//

import EventKit

protocol DataProviderDelegate {
    func receive(events: [EKEvent])
    func receive(reminders: [EKReminder])
    func receive(error: Error)
}

class DataService {
    enum Fetch {
        case nextMonthEvents
        case incompleteReminders
    }

    enum FetchError: Error {
        case fallBackError(String)
        case deniedAccess
    }
    
    var store = EKEventStore()
    var delegate: DataProviderDelegate
    
    init(for delegate: DataProviderDelegate) {
        self.delegate = delegate
        NotificationCenter.default.addObserver(self, selector: #selector(storeChanged), name: .EKEventStoreChanged, object: store)
    }
        
    public func request(data fetch: Fetch) {
        DispatchQueue.main.async {
            switch fetch {
            case .nextMonthEvents:
                self.authorizedFetch(EKEntityType.event) {
                    let events = self.store.events(matching: self.nextMonthEventsPredicate())
                                           .filter { !$0.isAllDay && $0.startSeconds >= sixAM && $0.endSeconds <= tenPM }
                    self.delegate.receive(events: events)
                }
                
            case .incompleteReminders:
                self.authorizedFetch(EKEntityType.reminder) {
                    _ = self.store.fetchReminders(matching: self.incompleteRemindersPredicate()) { ekReminders in
                        if let reminders = ekReminders {
                            self.delegate.receive(reminders: reminders)
                        } else {
                            self.delegate.receive(error: FetchError.fallBackError("No reminders returned"))
                        }
                    }
                }
            }
        }
    }
    
    private func authorizedFetch(_ entity: EKEntityType, perform fetch: @escaping (() -> ())) {
        if EKEventStore.authorizationStatus(for: entity) == .authorized {
            fetch()
        } else {
            store.requestAccess(to: entity) { isGranted, error in
                self.handleAccessResult(isGranted, error) {
                    fetch()
                }
            }
        }
    }
    
    private func handleAccessResult(_ isGranted: Bool, _ error: Error?, onSuccess: @escaping (() -> ())) {
        if isGranted { onSuccess() } else {
            if let e = error { delegate.receive(error: e) } else {
                delegate.receive(error: FetchError.deniedAccess)
            }
        }
    }
    
    @objc
    func storeChanged(_ notification: Notification) {
        request(data: .nextMonthEvents)
        request(data: .incompleteReminders)
    }
    
    private func nextMonthEventsPredicate() -> NSPredicate {
        var calendar = Calendar.current
        calendar.timeZone = NSTimeZone.local
        let thisMorning = calendar.startOfDay(for: Date())
        
        let nextMonth = calendar.date(byAdding: .month, value: 1, to: thisMorning)!
        return store.predicateForEvents(withStart: thisMorning, end: nextMonth, calendars: nil)
    }
    
    private func incompleteRemindersPredicate() -> NSPredicate {
        return self.store.predicateForIncompleteReminders(withDueDateStarting: nil,
                                                          ending: nil,
                                                          calendars: nil)
    }
    
    // MARK: - changing the store
    
    @discardableResult
    public func createEvent(titled title: String, from reminder: EKReminder, startDate: Date, endDate: Date) -> Bool {
        do {
            let newEvent = EKEvent(for: store, from: reminder, start: startDate, end: endDate, title: title)
            try store.save(newEvent, span: .thisEvent)
            return true
        }
        catch {
            return false
        }
    }
}
