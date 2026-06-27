//
//  ContentView.swift
//  PapaDrivingTime
//
//  Created by Fernando De Leon on 27/6/2026.
//

import SwiftUI

struct ContentView: View {
    var body: some View {
        NavigationStack {
            DrivingTimesView()
                .toolbar {
                    ToolbarItem(placement: .topBarLeading) {
                        NavigationLink {
                            SettingsView()
                        } label: {
                            Image(systemName: "gear")
                        }
                    }
                }
        }
    }
}
