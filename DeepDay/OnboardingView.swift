//
//  OnboardingView.swift
//  DeepDay
//
//  Created by Jon Ator on 11/19/20.
//

import SwiftUI
import EventKit

struct OnboardingView: View {
    @Binding var isOnboarded: Bool
    
    var body: some View {
        TabView {
            PrioritizeTime()
            ScheduleTime()
            PickWorkCalendar(isOnboarded: $isOnboarded)
        }
        .tabViewStyle(PageTabViewStyle(indexDisplayMode: .never))
    }
}

fileprivate struct PrioritizeTime: View {
    var body: some View {
        VStack {
            HeaderText(text: "Find time for your priorities")
            AVLoopPlayerView(url: Bundle.main.url(forResource: "PrioritizeTime", withExtension: "mov")!)
        }
    }
}

fileprivate struct ScheduleTime: View {
    var body: some View {
        VStack {
            HeaderText(text: "Schedule with intelligence")
            AVLoopPlayerView(url: Bundle.main.url(forResource: "IntelligentScheduling", withExtension: "mov")!)
        }
    }
}

fileprivate struct PickWorkCalendar: View {
    @Binding var isOnboarded: Bool
    @EnvironmentObject var viewModel: ViewModel
    @State private var selectedCalendarID: String = ""
    
    var body: some View {
        VStack {
            HeaderText(text: "Choose your work account")
            List(viewModel.calendars) { calendar in
                Button(action: { selectedCalendarID = calendar.id }) {
                    HStack {
                        Text(calendar.title)
                            .font(.headline)
                        Text(calendar.source.title)
                        if selectedCalendarID == calendar.id {
                            Spacer()
                            Text("✓")
                                .font(.title)
                                .foregroundColor(Color.blue)
                        }
                    }
                }
            }
            Button(action: {
                DispatchQueue.main.async {
                    viewModel.workCalendarID = selectedCalendarID
                    withAnimation { isOnboarded = true }
                }
            }) {
                Text("Finish")
                    .font(.title)
            }
        }
        .onAppear {
            if let workCal = viewModel.calendars.first(where: { $0.title.lowercased().trimmingCharacters(in: [" "]) == "work" }) {
                DispatchQueue.main.async {
                    selectedCalendarID = workCal.id
                }
            }
        }
    }
}

fileprivate struct HeaderText: View {
    let text: String
    
    var body: some View {
        Text(text)
            .font(.system(size: 40))
            .fontWeight(.bold)
            .padding()
            .frame(alignment: .leading)
    }
}

struct OnboardingView_Previews: PreviewProvider {
    static var previews: some View {
        OnboardingView(isOnboarded: .constant(false))
    }
}
