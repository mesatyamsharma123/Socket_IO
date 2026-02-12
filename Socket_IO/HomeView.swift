//
//  HomeView.swift
//  Socket_IO
//
//  Created by Satyam Sharma Chingari on 10/02/26.
//

import Foundation
import SwiftUI

struct HomeView: View {
    // Shared state yahan declare hogi
    @StateObject private var socketManager = SocketManagerClient()
    @State private var roomId: String = ""
    @State private var selectedTab: Int = 0

    var body: some View {
        TabView (selection: $selectedTab){
            NavigationStack {
                // 'roomID' ka name exact wahi hona chahiye jo ContentView mein hai
                ContentView(socketManager: socketManager, roomID: $roomId)
            }
            .tabItem { Label("Chats", systemImage: "message.fill") }
            .tag(0)
            NavigationStack {
                // AudioChatView ka init humne upar define kiya tha
                AudioChatView(roomId: $roomId, socketManager: socketManager,selectedTab: $selectedTab)
            }
            .tabItem { Label("Audio", systemImage: "phone.fill") }
            .tag(1)
            
            NavigationStack {
                VideoChatView()
            }
            .tabItem { Label("Video", systemImage: "video.fill") }
            .tag(2)
        }
    }
}
