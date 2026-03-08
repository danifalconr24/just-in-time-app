//
//  MyAppWidgetBundle.swift
//  MyAppWidget
//
//  Created by Daniel Falcon Ruiz on 8/3/26.
//

import WidgetKit
import SwiftUI

@main
struct MyAppWidgetBundle: WidgetBundle {
    var body: some Widget {
        MyAppWidget()
        MyAppWidgetControl()
        MyAppWidgetLiveActivity()
    }
}
