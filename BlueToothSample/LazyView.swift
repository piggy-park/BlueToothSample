//
//  LazyView.swift
//  BlueToothSample
//
//  Created by gx_piggy on 11/6/23.
//

import SwiftUI

struct LazyView<Content: View>: View {
    var content: () -> Content
    var body: some View {
        self.content()
    }
}
