//
//  DeepDayApp.swift
//  DeepDay
//
//  Created by Jon Ator on 10/9/20.
//

import SwiftUI

@main
struct DeepDayApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView().environmentObject(ViewModel(dataModel: Model.fromUserEventData()))
        }
    }
}
