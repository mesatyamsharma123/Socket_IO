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
            // .defaultToSpeaker options add karein taaki awaaz speaker se aaye
            try audioSession.setCategory(.playAndRecord,
                                       mode: .voiceChat,
                                       options: [.defaultToSpeaker, .allowBluetooth])
            try audioSession.setActive(true)
            print("✅ Audio Session is Active and Mic is ON")
        } catch {
            print("❌ couldn't set audio session: \(error)")
        }
    }
    
    func startLocalAudioCapture(){
        rtc.startAudioOnly()
    }
    func startCall(roomId: String){
        self.currentRoomId = roomId
        print("yeh room",currentRoomId)
        print("yeh origanal romm id: \(roomId)")
        rtc.offer { [weak self] (sdp) in
            guard let self else {return}
            self.socket.sendOffer(sdp: sdp, usename: "user1",roomId: roomId)
            
        }
        print("Start the call")
        print("roomId: \(roomId)")
            
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
        rtc.setRemoteDiscriptionForOffer(remoteSdp: didReceiveRemoteOffer)
        rtc.answer { [weak self ] answer in
            guard let self else {return}
            self.socket.sendAnswer(sdp: answer, usename: username,roomId: roomId)
            
        }
    
    }
    
    func SocketManagerClientProtocol(_ client: SocketManagerClient, didReceiveRemoteAnswer: String, username: String, roomId: String) {
        rtc.setRemoteDiscriptionForAnswer(remoteSdp: didReceiveRemoteAnswer)
        rtc.answer { [weak self ] answer in
            guard let self = self else { return }
            self.socket.sendAnswer(sdp: answer, usename: username, roomId: roomId)
        }
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
        print(state)
    }
    
    func webRTCClient(_ client: WebRTCManager, didReceiveRemoteAudioTrack track: RTCAudioTrack) {
        
          DispatchQueue.main.async {
              self.remoteAudioTrack = track
          }
    }
    
    func SocketManagerClientProtocol(_ client: SocketManagerClient, didReceiveRemoteOffer: String, username: String) {
        rtc.setRemoteDiscriptionForOffer(remoteSdp: didReceiveRemoteOffer)
        rtc.answer { [weak self ] answer in
            guard let self else {return}
            self.socket.sendAnswer(sdp: answer, usename: username,roomId: currentRoomId)
            
        }
        
    }
    
    func SocketManagerClientProtocol(_ client: SocketManagerClient, didReceiveRemoteAnswer: String, username: String) {
        
    }
    
    func SocketManagerClientProtocol(_ client: SocketManagerClient, didReceiveRemoteICECandidate candidate: [String : Any]) {
        guard let sdp = candidate["candidate"] as? String,
              let sdpMid = candidate["sdpMid"] as? String,
              let sdpMLineIndex = candidate["sdpMLineIndex"] as? Int32 else { return }
        let iceCandidate = RTCIceCandidate(sdp: sdp, sdpMLineIndex: sdpMLineIndex, sdpMid: sdpMid)
        rtc.set(remoteCandidate: iceCandidate)
    }
}
