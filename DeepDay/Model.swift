//
//  Model.swift
//  deepday
//
//  Created by Jon Ator on 10/9/20.
//

import EventKit
import Foundation

class Model: ObservableObject {
    var dataService: DataService?
    var userCalendar: Calendar {
        var calendar = Calendar.current
        calendar.timeZone = NSTimeZone.local
        return calendar
    }
    @Published private var todos: [String: EKReminder] = [:]
    @Published private var events: [String: EKEvent] = [:] {
        didSet {
            getMaxEventCount()
        }
    }
    var maxDayEventsCount: Int = 0
    
    // MARK: - todos
    
    func hasToDo(of id: String) -> Bool {
        return todos.contains(where: { todoID, _ in todoID == id })
    }
    
    func getToDos() -> [EKReminder] {
        return todos.values.sorted(by: { (l: EKReminder, r: EKReminder) in l.id < r.id })
    }
    
    func getToDo(by id: String) -> EKReminder? {
        return todos[id]
    }
    
    // MARK: - events
    
    func events(on day: Date) -> [EKEvent] {
        let dayInterval = userCalendar.dateInterval(of: .day, for: day)
        
        return
            [EKEvent](events.filter { _, event in dayInterval?.contains(event.date) ?? false }.values)
                .sorted(by: { $0.startSeconds == $1.startSeconds ? $0.duration < $1.duration : $0.startSeconds < $1.startSeconds })
    }
    
    func getEvent(by id: String) -> EKEvent? {
        return events[id]
    }
    
    func eventRatio(on day: Date) -> Double {
        let daysEvents = events(on: day)
        return maxDayEventsCount > 0 ? Double(daysEvents.count) / Double(maxDayEventsCount) : 0
    }
    
    private func getMaxEventCount() {
        var dayCountsDict = [Int : Int]()
        for e in events.values {
            let key = e.userCalendar.component(.day, from: e.date)
            if let existingCount = dayCountsDict[key] {
                let newValue = existingCount + 1
                dayCountsDict[key] = newValue
            } else {
                dayCountsDict[key] = 1
            }
        }
        var max = 0
        for day in dayCountsDict.values {
            if day > max {
                max = day
            }
        }
        maxDayEventsCount = max
    }
    
    // MARK: - scheduling
    
    func scheduleEvent(on date: Date, fromToDo id: String, from start: Int, to end: Int) {
        if let todo = getToDo(by: id), let dp = dataService {
            let start = date.dateFromSecondsIntoDay(seconds: start)
            let end = date.dateFromSecondsIntoDay(seconds: end)
            dp.createEvent(titled: todo.title, from: todo, startDate: start, endDate: end)
        }
    }
    
    // MARK: - init
    
    class func fromUserEventData() -> Model {
        let emptyModel = Model()
        let service = DataService(for: emptyModel)
        
        service.request(data: .nextMonthEvents)
        service.request(data: .incompleteReminders)
        
        emptyModel.dataService = service
        return emptyModel
    }
}

extension Model: DataServiceDelegate {
    func receive(events: [EKEvent]) {
        self.events = Dictionary(zip(events.map(\.id), events), uniquingKeysWith: { a, _ in a })
    }
    
    func receive(reminders: [EKReminder]) {
        reminders.forEach { $0.ensureScheduledInto(events: Array(self.events.values)) }
        self.todos = Dictionary(zip(reminders.map(\.id), reminders), uniquingKeysWith: { a, _ in a })
    }
    
    func receive(error: Error) {
        print(error)
    }
}
