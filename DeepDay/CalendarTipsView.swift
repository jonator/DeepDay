//
//  CalendarTipsView.swift
//  DeepDay
//
//  Created by Jon Ator on 11/17/20.
//

import SwiftUI
import EventKit

struct CalendarTipsView: View {
    let todosCount: Int
    let events: [EKEvent]
    let availableTime: [ViewModel.AvailableTime]
    let workCalendarID: String
    
    let sixHrsSecs: Double = 60 * 60 * 6
    let fourHrsSecs: Double = 60 * 60 * 4
    let eightHrsSecs: Double = 60 * 60 * 8
    let fiveThirty = 63000
    
    var tooShallowTip: CalendarTip.Tip? {
        let shallowSecs = cumulativeTimeIn(.shallow)
        if shallowSecs > sixHrsSecs {
            return CalendarTip.Tip(title: "Too shallow", description: "More than 6 hours of shallow work is scheduled")
        }
        return nil
    }
    
    var tooDeepTip: CalendarTip.Tip? {
        let deepSecs = cumulativeTimeIn(.deep)
        if deepSecs > fourHrsSecs {
            return CalendarTip.Tip(title: "Too dep", description: "More than 4 hours of deep work scheudled")
        }
        return nil
    }
    
    var workingLateTip: CalendarTip.Tip? {
        if let lastEvent = events.last {
            if lastEvent.id == workCalendarID && lastEvent.endSeconds > fiveThirty {
                return CalendarTip.Tip(title: "Working late", description: "You've scheduled work past 5:30")
            }
        }
        return nil
    }
    
    var workOnWeekends: CalendarTip.Tip? {
        if let workEvent = events.first(where: { $0.activityType == .deep && $0.calendar.id == workCalendarID }) {
            if workEvent.userCalendar.isDateInWeekend(workEvent.date) {
                return CalendarTip.Tip(title: "Working on weekends", description: "You've scheduled work on the weekend. Work is best reserved for the week days")
            }
        }
        return nil
    }
    
    var interruptedFlowTip: CalendarTip.Tip? {
        if events.filter({ $0.activityType == .deep }).count > 3 {
            return CalendarTip.Tip(title: "Interrupted flow state", description: "Deep work events are intermittent")
        }
        return nil
    }
    
    var unfocusedTip: CalendarTip.Tip? {
        let availTimeSecs = availableTime.reduce(0, { acc, at in acc + Double(at.endSeconds - at.startSeconds)})
        if todosCount > 3 && availTimeSecs > sixHrsSecs {
            return CalendarTip.Tip(title: "Unfocused", description: "More than 6 hours of available time with incomplete ToDos")
        }
        return nil
    }
    
    var workingTooMuchTip: CalendarTip.Tip? {
        if let lastEvent = events.last {
            if lastEvent.endSeconds < fiveThirty {
                let eventsTimeSecs = events.reduce(0, { acc, e in acc + Double(e.endSeconds - e.startSeconds)})
                if eventsTimeSecs > eightHrsSecs {
                    return CalendarTip.Tip(title: "Working too much", description: "You have  events before 5:30 that span over 8 hours")
                }
            }
        }
        return nil
    }
    
    var tips: [CalendarTip.Tip] {
        [ tooShallowTip,
          tooDeepTip,
          workingLateTip,
          interruptedFlowTip,
          unfocusedTip,
          workingTooMuchTip
        ]
        .compactMap { $0 }
    }
    
    var body: some View {
        ForEach(tips) { tip in
            CalendarTip(tip: tip)
                .padding(.top)
        }
    }
    
    private func cumulativeTimeIn(_ activityType: ActivityType) -> TimeInterval {
        let filteredEvents = events.filter { $0.activityType == activityType }
        return TimeInterval(filteredEvents.reduce(0, { acc, e in acc + (e.endSeconds - e.startSeconds)}))
    }
}

struct CalendarTip: View {
    struct Tip: Identifiable {
        let id = UUID()
        let title: String
        let description: String
    }
    
    @EnvironmentObject var viewModel: ViewModel
    let tip: Tip
    
    var body: some View {
        VStack(alignment: .leading) {
            Text(tip.title)
                .font(.headline)
                .fontWeight(.bold)
                .foregroundColor(Color.black)
                .padding()
                .padding(.bottom, -5)
            Text(tip.description)
                .lineLimit(4)
                .foregroundColor(Color.black)
                .padding([.leading, .trailing, .bottom])
        }
        .frame(width: (viewModel.timelineRect?.width ?? 350) - 25, alignment: .leading)
        .background(DesignPalette.Colors.secondary)
        .cornerRadius(10)
    }
}

struct CalendarTipsView_Previews: PreviewProvider {
    static var previews: some View {
        CalendarTip(tip: CalendarTip.Tip(title: "Working late", description: "This is a fake tip with a long description, I made this even longer to test"))
    }
}
