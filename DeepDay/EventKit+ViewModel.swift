//
//  ModelObjects.swift
//  DeepDay
//
//  Created by Jon Ator on 10/12/20.
//

import EventKit
import Foundation

let halfHour = 1800
let sixAM = 60 * 60 * 6
let tenPM = 60 * 60 * 22

enum ActivityType {
    case shallow
    case deep
}

extension EKCalendarItem: Identifiable {
    public var id: String { calendarItemIdentifier + calendarItemExternalIdentifier }
}

extension EKReminder {
    var activityType: ActivityType {
        get {
            return .shallow
        }
        set {}
    }
}

extension EKEvent {
    var date: Date { startDate }

    var startSeconds: Int { startDate.secondsIntoDay }

    var endSeconds: Int { endDate.secondsIntoDay }
    
    var timeInterval: TimeInterval { TimeInterval(endSeconds - startSeconds) }

    var content: String? { notes }

    var activityType: ActivityType { // TODO: get from core data
        get {
            return .shallow
        }
        set {}
    }
}

#if DEBUG
// struct MockCalendar {
//    static let todos = [
//        MockToDo(text: "Follow up with Mike"),
//        MockToDo(text: "Make progress on sprint"),
//        MockToDo(text: "Schedule report demo"),
//        MockToDo(text: "Work on novel"),
//        MockToDo(text: "Repaint siding"),
//        MockToDo(text: "Volunteer"),
//        MockToDo(text: "Plan vacation")
//    ]
//
//    static let events = [
//        MockEvent(startSeconds: 60 * 60 * 6, endSeconds: 60 * 60 * 6 + (60 * 25), title: "Team Meeting", activityType: .shallow),
//        MockEvent(startSeconds: 60 * 60 * 10 + (60 * 10), endSeconds: 60 * 60 * 11, title: "Customer Interview", activityType: .shallow),
//        MockEvent(startSeconds: 60 * 60 * 11 + (60 * 10), endSeconds: 60 * 60 * 12 + (60 * 25)),
//        MockEvent(startSeconds: 60 * 60 * 14, endSeconds: 60 * 60 * 14 + (60 * 55), title: "Shareholder Meeting", activityType: .shallow),
//        MockEvent(startSeconds: 60 * 60 * 17 + (60 * 5), endSeconds: 60 * 60 * 17 + (60 * 55), title: "Bill 1-1", activityType: .shallow),
//        MockEvent(startSeconds: 60 * 60 * 19, endSeconds: 60 * 60 * 21 + (60 * 40), title: "Visit grandparents", activityType: .shallow)
//    ]
// }
//
// struct MockToDo: ToDo {
//    var id = UUID()
//    var text: String
//    var activityType: ActivityType = .shallow
// }
//
// struct MockEvent: Event {
//    var id = UUID()
//    var date = Date()
//    var startSeconds: Int
//    var endSeconds: Int
//    var title: String?
//    var content: String?
//    var activityType: ActivityType = .deep
// }

#endif
