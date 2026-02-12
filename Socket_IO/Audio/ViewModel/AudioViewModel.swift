//
//  AudioViewModel.swift
//  Socket_IO
//
//  Created by Satyam Sharma Chingari on 10/02/26.
//

import Foundation
import Combine
import WebRTC
import AVFoundation
import SwiftUI
class AudioViewModel: ObservableObject {
  
    

    private let socket: SocketManagerClient
    private let rtc: WebRTCManager
    private var currentRoomId: String = ""
    
    @Published var remoteAudioTrack: RTCAudioTrack?
    
    
    @Published var connectionState: String = "Connecting..."
    @Published var isMuted: Bool = false
    @Published var isSpeakerOn: Bool = true
    @Published var isCallActive: Bool = false
    
    
    init(socketManager: SocketManagerClient){
        self.socket = socketManager
        self.rtc = WebRTCManager()
        self.socket.delegate = self
        self.rtc.delegate = self
        self.configureAudioSession()

      
    }
    
    func configureAudioSession() {
        let audioSession = AVAudioSession.sharedInstance()
        do {

            try audioSession.setCategory(.playAndRecord,
                                       mode: .voiceChat,
                                       options: [.defaultToSpeaker, .allowBluetooth])
            try audioSession.setActive(true)
            print(" Audio Session is Active and Mic is ON")
        } catch {
            print(" couldn't set audio session: \(error)")
        }
    }
    
    func startLocalAudioCapture(){
        rtc.startAudioOnly()
    }
    func startCall(roomId: String) {
        self.currentRoomId = roomId
        
      
        self.startLocalAudioCapture()
        
    
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            self.rtc.offer { [weak self] (sdp) in
                guard let self = self else { return }
                self.socket.sendOffer(sdp: sdp, usename: "user1", roomId: roomId)
            }
        }
    }

    func toggleMute() {
        isMuted.toggle()
        // WebRTCManager ke pas local audio track ka access hona chahiye
        // Agar rtc.localAudioTrack public hai toh:
        rtc.localAudioTrack?.isEnabled = !isMuted
        print(isMuted ? "🔇 Mic Muted" : "🎙️ Mic Unmuted")
    }
    func toggleSpeaker() {
        isSpeakerOn.toggle()
        let session = RTCAudioSession.sharedInstance()
        session.lockForConfiguration()
        do {
            // .speaker means loudspeaker, .none/default means earpiece
            try session.overrideOutputAudioPort(isSpeakerOn ? .speaker : .none)
            print("🔊 Speaker is now \(isSpeakerOn ? "ON" : "OFF (Earpiece)")")
        } catch {
            print("❌ Error toggling speaker: \(error)")
        }
        session.unlockForConfiguration()
    }
    
    func hangup() {
        guard !currentRoomId.isEmpty else { return }
        rtc.closeConnection()
        socket.endCall(roomId: currentRoomId)
        
        DispatchQueue.main.async {
            self.isCallActive = false // Reset state inside VM
            self.remoteAudioTrack = nil
        }
    }



    func checkPermissions() {
        let audioStatus = AVCaptureDevice.authorizationStatus(for: .audio)
        
        switch audioStatus {
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .audio) { granted in
                if granted {
                    print("Mic access granted")
                    DispatchQueue.main.async {
                        self.startLocalAudioCapture()
                    }
                }
            }
        case .authorized:
            print("Audio already authorized")
            self.startLocalAudioCapture()
        case .denied, .restricted:
            print("Audio access denied by user. They must enable it in Settings.")
        @unknown default:
            break
        }
    }
    
}







extension AudioViewModel: SocketManagerClientProtocol, WebRTCClientDelegate {
    func SocketManagerClientProtocol(_ client: SocketManagerClient, didReceiveRemoteOffer: String, username: String, roomId: String) {
        self.currentRoomId = roomId
        DispatchQueue.main.async {
                self.isCallActive = true // Phone Icon automatic Red (Down) ho jayega
            }
  
        self.startLocalAudioCapture()
        
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            self.rtc.setRemoteDiscriptionForOffer(remoteSdp: didReceiveRemoteOffer)
            self.rtc.answer { [weak self] answer in
                guard let self = self else { return }
                self.socket.sendAnswer(sdp: answer, usename: "user2", roomId: roomId)
            }
        }
    }
    
    func SocketManagerClientProtocol(_ client: SocketManagerClient, didReceiveRemoteAnswer: String, username: String, roomId: String) {
        rtc.setRemoteDiscriptionForAnswer(remoteSdp: didReceiveRemoteAnswer)
//        rtc.answer { [weak self ] answer in
//            guard let self = self else { return }
//            self.socket.sendAnswer(sdp: answer, usename: username, roomId: roomId)
//            print("received remote answer, room id: \(roomId)")
//        }
    }
    
    func SocketManagerClientProtocol(_ client: SocketManagerClient, didReceiveRemoteICECandidate candidate: [String : Any], roomId: String) {
        guard let sdp = candidate["candidate"] as? String,
              let sdpMid = candidate["sdpMid"] as? String,
              let sdpMLineIndex = candidate["sdpMLineIndex"] as? Int32,
              let roomId = candidate["roomId"] as? String else { return }
        let iceCandidate = RTCIceCandidate(sdp: sdp, sdpMLineIndex: sdpMLineIndex, sdpMid: sdpMid)
        rtc.set(remoteCandidate: iceCandidate)
    }
    

    

    
    func webRTCClient(_ client: WebRTCManager, didDiscoverLocalCandidate candidate: RTCIceCandidate) {
        let candidateDict: [String: Any] = [
            "candidate": candidate.sdp,
            "sdpMid": candidate.sdpMid ?? "",
            "sdpMLineIndex": candidate.sdpMLineIndex,
            "roomId": currentRoomId
        ]
        socket.sendCandidate(candidate: candidateDict)
        
    }
    
    func webRTCClient(_ client: WebRTCManager, didChangeConnectionState state: RTCIceConnectionState) {
        DispatchQueue.main.async {
            switch state {
            case .connected: self.connectionState = "Connected"
            case .failed: self.connectionState = "Failed"
            case .disconnected: self.connectionState = "Disconnected"
            default: break
            }
        }
    }
    
    func webRTCClient(_ client: WebRTCManager, didReceiveRemoteAudioTrack track: RTCAudioTrack) {
        
          DispatchQueue.main.async {
              self.remoteAudioTrack = track
              self.remoteAudioTrack?.isEnabled = true
              let rtcSession = RTCAudioSession.sharedInstance()
                      rtcSession.lockForConfiguration()
                      try? rtcSession.overrideOutputAudioPort(.speaker)
                      try? rtcSession.setActive(true)
                      rtcSession.unlockForConfiguration()
          }
    }
    
    func SocketManagerClientProtocol(_ client: SocketManagerClient, didReceiveRemoteOffer: String, username: String) {
        rtc.setRemoteDiscriptionForOffer(remoteSdp: didReceiveRemoteOffer)
        rtc.answer { [weak self ] answer in
            guard let self else {return}
            self.socket.sendAnswer(sdp: answer, usename: username,roomId: currentRoomId)
            
        }
        
    }
    
  
 
}
