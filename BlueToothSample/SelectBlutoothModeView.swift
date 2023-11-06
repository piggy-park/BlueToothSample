//
//  ContentView.swift
//  BlueToothSample
//
//  Created by gx_piggy on 10/30/23.
//

import SwiftUI

struct SelectBlutoothModeView: View {
    var body: some View {
        NavigationView {
            VStack {
                NavigationLink {
                    LazyView { CentralView() }
                } label: {
                    Text("Central")
                }
                .padding()

                NavigationLink {
                    LazyView { PeripheralView() }
                } label: {
                    Text("Peripheral")
                }
                .padding()
            }
        }

    }
}
