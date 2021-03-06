//
//  ModelObjects.swift
//  DeepDay
//
//  Created by Jon Ator on 10/12/20.
//

import EventKit

let halfHour = 1800
let sixAM = 60 * 60 * 6
let tenPM = 60 * 60 * 22

enum ActivityType: String {
    case shallow = "shallow"
    case deep = "deep"
}

extension EKCalendar: Identifiable {
    public var id: String { calendarIdentifier }
}

extension EKCalendarItem {
    private var activityTypeKey: String { calendarItemIdentifier + "activityType" }
    
    var activityType: ActivityType {
        get
        {
            if let activityTypeRawValue = UserDefaults.standard.object(forKey: activityTypeKey) as? String {
                return ActivityType(rawValue: activityTypeRawValue)!
            }
            return .shallow
        }
        set
        {
            UserDefaults.standard.set(newValue.rawValue, forKey: activityTypeKey)
        }
    }
    
    var userCalendar: Calendar {
        var calendar = Calendar.current
        calendar.timeZone = timeZone ?? NSTimeZone.local
        return calendar
    }
}

extension EKReminder: Identifiable {
    public var id: String { calendarItemIdentifier }
    
    private var scheduledEventsKey: String { calendarItemIdentifier + "scheduledEvents" }
    
    var scheduledEventsID: [String] { UserDefaults.standard.stringArray(forKey: scheduledEventsKey) ?? [] }
    
    func addScheduledEvent(id: String) {
        if var existingEventIDs = UserDefaults.standard.stringArray(forKey: scheduledEventsKey) {
            existingEventIDs.append(id)
            UserDefaults.standard.setValue(existingEventIDs, forKey: scheduledEventsKey)
        } else {
            UserDefaults.standard.setValue([id], forKey: scheduledEventsKey)
        }
    }
    
    func ensureScheduledInto(events: [EKEvent]) {
        UserDefaults.standard.removeObject(forKey: scheduledEventsKey)
        for e in events {
            if e.title == title {
                addScheduledEvent(id: e.id)
            }
        }
    }
}

extension EKEvent: Identifiable {
    public var id: String {
        var cal = Calendar.current
        cal.timeZone = self.timeZone ?? NSTimeZone.local
        return calendarItemIdentifier + "\(cal.component(.month, from: self.date))\(cal.component(.day, from: date))"
    }
    
    var date: Date { startDate }

    var startSeconds: Int { startDate.secondsIntoDay }

    var endSeconds: Int { endDate.secondsIntoDay }
    
    var duration: TimeInterval { TimeInterval(endSeconds - startSeconds) }

    var content: String? { notes }
    
    convenience init(for store: EKEventStore, from reminder: EKReminder, start: Date, end: Date, title: String) {
        self.init(eventStore: store)
        calendar = store.defaultCalendarForNewEvents
        startDate = start
        endDate = end
        self.title = title
        notes = "Created by DeepDay"
        let back5minsSecs = -300
        let alarm = EKAlarm(relativeOffset: TimeInterval(back5minsSecs))
        addAlarm(alarm)
        reminder.addScheduledEvent(id: calendarItemIdentifier)
    }
}
