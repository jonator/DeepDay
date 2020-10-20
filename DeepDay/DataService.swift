//
//  DataService.swift
//  deepday
//
//  Created by Jon Ator on 10/9/20.
//

import EventKit
import Foundation

protocol DataProviderDelegate {
    func receive(events: [EKEvent])
    func receive(reminders: [EKReminder])
    func receive(error: Error)
}

class DataService {
    enum Fetch {
        case pastMonthEvents
        case incompleteReminders
    }

    enum FetchError: Error {
        case fallBackError(String)
        case deniedAccess
    }
    
    var store = EKEventStore()
    var delegate: DataProviderDelegate
    
    var isAuthorizedForEvents: Bool {
        EKEventStore.authorizationStatus(for: EKEntityType.event) == .authorized
    }

    var isAuthorizedForReminders: Bool {
        EKEventStore.authorizationStatus(for: EKEntityType.reminder) == .authorized
    }
    
    init(for delegate: DataProviderDelegate) {
        self.delegate = delegate
    }
        
    public func request(data fetch: Fetch) {
        DispatchQueue.main.async {
            switch fetch {
            case .pastMonthEvents:
                let getEvents = {
                    let events = self.store.events(matching: self.nextMonthEventsPredicate()).filter { !$0.isAllDay && $0.startSeconds >= sixAM && $0.endSeconds <= tenPM }
                    self.delegate.receive(events: events)
                }
                if self.isAuthorizedForEvents {
                    getEvents()
                } else {
                    self.requestEventAccess { isGranted, error in self.handleAccessResult(isGranted, error, onSuccess: getEvents) }
                }
                
            case .incompleteReminders:
                let getReminders = {
                    let incompleteRemindersPredicate = self.store.predicateForIncompleteReminders(withDueDateStarting: nil,
                                                                                                  ending: nil,
                                                                                                  calendars: nil)
                    _ = self.store.fetchReminders(matching: incompleteRemindersPredicate) { ekReminders in
                        if let reminders = ekReminders {
                            self.delegate.receive(reminders: reminders)
                        } else {
                            self.delegate.receive(error: FetchError.fallBackError("No reminders returned"))
                        }
                    }
                }
                if self.isAuthorizedForReminders {
                    getReminders()
                } else {
                    self.requestReminderAccess { isGranted, error in self.handleAccessResult(isGranted, error, onSuccess: getReminders) }
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
    
    // MARK: - authorization
    
    private func requestReminderAccess(completion: @escaping EKEventStoreRequestAccessCompletionHandler) {
        store.requestAccess(to: EKEntityType.reminder, completion: completion)
    }
    
    private func requestEventAccess(completion: @escaping EKEventStoreRequestAccessCompletionHandler) {
        store.requestAccess(to: EKEntityType.event, completion: completion)
    }
    
    private func nextMonthEventsPredicate() -> NSPredicate {
        var calendar = Calendar.current
        calendar.timeZone = NSTimeZone.local
        let thisMorning = calendar.startOfDay(for: Date())
        
        let nextMonth = calendar.date(byAdding: .month, value: 1, to: thisMorning)!
        return store.predicateForEvents(withStart: thisMorning, end: nextMonth, calendars: nil)
    }
}
