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
