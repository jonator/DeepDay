//
//  ContentView.swift
//  DeepDay
//
//  Created by Jon Ator on 10/9/20.
//

import SwiftUI

struct ContentView: View {
    @AppStorage("isOnboarded") var isOnboarded: Bool = false
    
    var body: some View {
        if isOnboarded {
            SchedulerView()
        } else {
            OnboardingView(isOnboarded: $isOnboarded)
        }
    }
}


struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
