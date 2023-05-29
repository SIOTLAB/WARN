//
//  ContentView.swift
//  userApp
//
//  Created by Jaden Ngo on 1/23/23.
//

import SwiftUI
import UserNotifications

// ********  Colors ********
struct CustomColor {
    static let naviColor = Color("navigationBar")
    static let lightBlue = Color("lightBlue")
    static let darkBlue = Color("darkBlue")
    static let lightGray = Color("lightGray")
    static let green = Color("green")
    static let lightGreen = Color("lightGreen")
}

/*
 Active Tab Key:
    Devices: 1
    Network: 2
    Attacks: 3
 */

// *** Content View ***
struct ContentView: View {
    @State var activeTab = 1
    
    @EnvironmentObject var selTab: SelectedTab
    @StateObject var user = UserObject()
    @StateObject var deviceInfo = DeviceObject()
    @StateObject var attackInfo = AttackObject()
    
    var body: some View {
        TabView (selection: $selTab.id){
            DevicePageView().tag(1)
                .tabItem {
                    Image(systemName: "iphone.gen3.radiowaves.left.and.right")
                    Text("Devices")
                }.environmentObject(selTab)
            
            NetworkView().tag(2)
                .tabItem {
                    Image(systemName: "shield.lefthalf.filled")
                    Text("Home")
                }
            
            AttackPageView().tag(3)
                .tabItem {
                     Image(systemName: "exclamationmark.triangle")
                     Text("Attacks")
                }
        }
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
            .environmentObject(SelectedTab())
            .environmentObject(AttackObject())
            .environmentObject(UserObject())
            .environmentObject(DeviceObject())
    }
}
