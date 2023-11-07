//
//  CentralChattingListView.swift
//  BlueToothSample
//
//  Created by gx_piggy on 11/7/23.
//

import SwiftUI
import CoreBluetooth
import OSLog


struct CentralChattingListView: View {
    @StateObject var centralUseCase: CentralUseCase = .init()
    @State private var showConnectAlert: Bool = false
    @State private var selectedPeripheral: CBPeripheral?
    @State private var showBlueToothAuthAlert: Bool = false
    @State private var goToChattingRoom: Bool = false

    var body: some View {
        List {
            ForEach(centralUseCase.peripheralList) { peripheral in
                Button(peripheral.name ?? "알수 없는 기기") {
                    self.showConnectAlert = true
                    self.selectedPeripheral = peripheral
                }
            }
        }
        .alert("채팅방에 입장하시겠습니까?", isPresented: $showConnectAlert) {
            Button("취소", role: .cancel) { }
            Button("확인") { self.goToChattingRoom = true }
        }
        .background {
            NavigationLink(isActive: $goToChattingRoom) {
                LazyView {
                    CentralChattingView(centralUseCase)
                    // TODO: 연결 안되면 에러처리
                        .onAppear {
                            if let selectedPeripheral {
                                centralUseCase.connect(selectedPeripheral)
                            }
                        }
                }
            } label: {
                EmptyView()
            }
        }
        .alert("블루투스 권한이 필요합니다", isPresented: $showBlueToothAuthAlert, actions: {
            Button("취소", role: .cancel) {
                self.showBlueToothAuthAlert = false
            }
            Button("설정") {
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(url)
                }
            }
        })
        .onChange(of: centralUseCase.blueToothStatus, perform: { value in
            switch value {
            case .denied, .restricted:
                self.showBlueToothAuthAlert = true
            default:
                blueToothLog(deviceType: .central, "Unexpected authorization")
            }
        })
    }
}

