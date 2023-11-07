//
//  ContentView.swift
//  BlueToothSample
//
//  Created by gx_piggy on 10/30/23.
//

import SwiftUI

struct SelectBluetoothModeView: View {
    var body: some View {
        NavigationView {
            VStack {
                NavigationLink {
                    LazyView { CentralChattingListView() }
                } label: {
                    Text("Central")
                }
                .padding()

                NavigationLink {
                    LazyView { PeripheralChatSettingView() }
                } label: {
                    Text("Peripheral")
                }
                .padding()
            }
        }

    }
}
