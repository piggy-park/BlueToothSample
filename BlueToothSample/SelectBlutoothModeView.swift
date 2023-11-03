//
//  ContentView.swift
//  BlueToothSample
//
//  Created by gx_piggy on 10/30/23.
//

import SwiftUI
import CoreBluetooth
import os

struct SelectBlutoothModeView: View {
    var body: some View {
        NavigationView {
            VStack {
                NavigationLink {
                    CentralView()
                } label: {
                    Text("Central")
                }
                .padding()

                NavigationLink {
                    PeripheralView()
                } label: {
                    Text("Peripheral")
                }
                .padding()
            }
        }

    }
}
