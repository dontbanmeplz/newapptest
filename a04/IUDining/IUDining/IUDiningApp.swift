//
//  IUDiningApp.swift
//  IUDining
//
//  Created by Christopher Sawicz on 4/16/26.
//

import SwiftUI

/// Main entry point for the IU Dining application.
///
/// Configures a single window group containing the root `ContentView`
/// which manages the tab-based navigation interface.
@main
struct IUDiningApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}
