//
//  PeripheralView.swift
//  BlueToothSample
//
//  Created by gx_piggy on 10/30/23.
//

import SwiftUI
import CoreBluetooth

struct PeripheralView: View {
    @ObservedObject var viewModel: PeripheralViewModel = .init()
    @State private var sendText: String = ""

    var body: some View {
        VStack {
            TextField("input text", text: $sendText)
                .textFieldStyle(.roundedBorder)
                .padding()

            Button("send text") {
                viewModel.start()
                viewModel.sendText = sendText
            }
        }
        .onAppear {
            viewModel.setPeripheralManager()
        }
        .onDisappear {
            viewModel.stop()
        }
        .padding()
    }
}
