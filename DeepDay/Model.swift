//
//  Model.swift
//  deepday
//
//  Created by Jon Ator on 10/9/20.
//

import EventKit
import Foundation

class Model: ObservableObject {
    var dataProvider: DataService?
    @Published private var todos: [String: EKReminder] = [:]
    @Published private var events: [String: EKEvent] = [:]
    
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
        let calendar = Calendar.current
        let dayInterval = calendar.dateInterval(of: .day, for: day)
        
        return
            [EKEvent](events.filter { _, event in dayInterval?.contains(event.date) ?? false }.values)
                .sorted(by: { $0.startSeconds == $1.startSeconds ? $0.duration < $1.duration : $0.startSeconds < $1.startSeconds })
    }
    
    func getEvent(by id: String) -> EKEvent? {
        return events[id]
    }
    
    // MARK: - scheduling
    
    func scheduleEvent(fromToDo id: String, from start: Int, to end: Int) {
        if let todo = getToDo(by: id), let dp = dataProvider {
            let now = Date()
            let start = now.dateFromSecondsIntoToday(seconds: start)
            let end = now.dateFromSecondsIntoToday(seconds: end)
            dp.createEvent(titled: todo.title, from: todo, startDate: start, endDate: end)
        }
    }
    
    // MARK: - init
    
    class func fromUserEventData() -> Model {
        let emptyModel = Model()
        let provider = DataService(for: emptyModel)
        
        provider.request(data: .nextMonthEvents)
        provider.request(data: .incompleteReminders)
        
        emptyModel.dataProvider = provider
        return emptyModel
    }
}

extension Model: DataProviderDelegate {
    func receive(events: [EKEvent]) {
        self.events = Dictionary(zip(events.map(\.id), events), uniquingKeysWith: { a, _ in a })
    }
    
    func receive(reminders: [EKReminder]) {
        todos = Dictionary(zip(reminders.map(\.id), reminders), uniquingKeysWith: { a, _ in a })
    }
    
    func receive(error: Error) {
        print(error)
    }
}
