//
//  CalendarView.swift
//  DeepDay
//
//  Created by Jon Ator on 11/10/20.
//

import SwiftUI

struct CalendarView<DateView>: View where DateView: View {
    @Environment(\.calendar) var calendar

    let interval: DateInterval
    let onTapDay: (Date) -> ()
    let content: (Date) -> DateView

    init(interval: DateInterval,
         onTapDay: @escaping (Date) -> (),
         @ViewBuilder content: @escaping (Date) -> DateView) {
        self.interval = interval
        self.onTapDay = onTapDay
        self.content = content
    }

    private var months: [Date] {
        calendar.generateDates(
            inside: interval,
            matching: DateComponents(day: 1, hour: 0, minute: 0, second: 0)
        )
    }

    var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack {
                ForEach(months, id: \.self) { month in
                    MonthView(month: month, onTapDay: onTapDay, content: self.content)
                }
            }
        }
    }
}

fileprivate struct MonthView<DateView>: View where DateView: View {
    @Environment(\.calendar) var calendar

    let month: Date
    let onTapDay: (Date) -> ()
    let content: (Date) -> DateView

    init(
        month: Date,
        onTapDay: @escaping (Date) -> (),
        @ViewBuilder content: @escaping (Date) -> DateView
    ) {
        self.month = month
        self.onTapDay = onTapDay
        self.content = content
    }

    private var weeks: [Date] {
        guard
            let monthInterval = calendar.dateInterval(of: .month, for: month)
            else { return [] }
        return calendar.generateDates(
            inside: monthInterval,
            matching: DateComponents(hour: 0, minute: 0, second: 0, weekday: calendar.firstWeekday)
        )
    }

    private var header: some View {
        let component = calendar.component(.month, from: month)
        let formatter = component == 1 ? DateFormatter.monthAndYear : .month
        return Text(formatter.string(from: month))
            .font(.largeTitle)
            .padding()
    }

    var body: some View {
        VStack {
            header
            ForEach(weeks, id: \.self) { week in
                WeekView(week: week, onTapDay: onTapDay, content: self.content)
            }
        }
        .padding(1)
    }
}

fileprivate struct WeekView<DateView>: View where DateView: View {
    @Environment(\.calendar) var calendar

    let week: Date
    let onTapDay: (Date) -> ()
    let content: (Date) -> DateView

    init(week: Date,
         onTapDay: @escaping (Date) -> (),
         @ViewBuilder content: @escaping (Date) -> DateView) {
        self.week = week
        self.onTapDay = onTapDay
        self.content = content
    }

    private var days: [Date] {
        guard
            let weekInterval = calendar.dateInterval(of: .weekOfYear, for: week)
            else { return [] }
        return calendar.generateDates(
            inside: weekInterval,
            matching: DateComponents(hour: 0, minute: 0, second: 0)
        )
    }

    var body: some View {
        HStack {
            ForEach(days, id: \.self) { date in
                HStack {
                    if self.calendar.isDate(self.week, equalTo: date, toGranularity: .month) {
                        self.content(date)
                            .onTapGesture {
                                onTapDay(date)
                            }
                    } else {
                        self.content(date).hidden()
                    }
                }
            }
        }
    }
}
