//
//  WebRTCManager.swift
//  Socket_IO
//
//  Created by Satyam Sharma Chingari on 10/02/26.
//

import Foundation
import Combine
import WebRTC


protocol WebRTCClientDelegate: AnyObject {
    func webRTCClient(_ client: WebRTCManager, didDiscoverLocalCandidate candidate: RTCIceCandidate)
    func webRTCClient(_ client: WebRTCManager, didChangeConnectionState state: RTCIceConnectionState)
    func webRTCClient(_ client: WebRTCManager, didReceiveRemoteAudioTrack track: RTCAudioTrack)
}

class WebRTCManager: NSObject, ObservableObject{
    
    
    weak var delegate: WebRTCClientDelegate?
    private let factory: RTCPeerConnectionFactory
    private var peerConnection: RTCPeerConnection!
    private let mediaConstrains = [kRTCMediaConstraintsOfferToReceiveAudio: kRTCMediaConstraintsValueTrue,
                                   kRTCMediaConstraintsOfferToReceiveVideo: kRTCMediaConstraintsValueTrue]

    
   override init() {

        RTCInitializeSSL()

        let encoderFactory = RTCDefaultVideoEncoderFactory()
        let decoderFactory = RTCDefaultVideoDecoderFactory()


        self.factory = RTCPeerConnectionFactory(encoderFactory: encoderFactory,
                                                decoderFactory: decoderFactory)
       super.init( )
       setupConfiguration()
    }
    
    func  setupConfiguration(){
        let config = RTCConfiguration()
        config.iceServers = [RTCIceServer(urlStrings: ["stun:stun.l.google.com:19302"])]
        config.sdpSemantics = .unifiedPlan
        
        let constraints = RTCMediaConstraints(mandatoryConstraints: mediaConstrains, optionalConstraints: nil)
        
        self.peerConnection = factory.peerConnection(with: config, constraints: constraints, delegate: self)
    }
    func startAudioOnly() {
 
        let rtcAudioSession = RTCAudioSession.sharedInstance()
        rtcAudioSession.lockForConfiguration()
        do {
            try rtcAudioSession.setCategory(AVAudioSession.Category.playAndRecord.rawValue)
            try rtcAudioSession.setMode(AVAudioSession.Mode.voiceChat.rawValue)
        } catch {
            print(" Audio Session Error: \(error)")
        }
        rtcAudioSession.unlockForConfiguration()

   
        let constraints = RTCMediaConstraints(mandatoryConstraints: nil, optionalConstraints: nil)
        let audioSource = factory.audioSource(with: constraints)

        
        let audioTrack = factory.audioTrack(with: audioSource, trackId: "audio0")
        

        peerConnection.add(audioTrack, streamIds: ["stream0"])
        
        print(" Audio track added to PeerConnection")
    }
    
    func offer(completion: @escaping (String) -> Void) {
        let constraints = RTCMediaConstraints(mandatoryConstraints: mediaConstrains, optionalConstraints: nil)
        peerConnection.offer(for: constraints) { [weak self] (sdp, error) in
            guard let self = self, let sdp = sdp else { return }
            self.peerConnection.setLocalDescription(sdp) { _ in
                completion(sdp.sdp)
            }
        }
    }
    
    func answer(completion: @escaping (String) -> Void) {
        let constraints = RTCMediaConstraints(mandatoryConstraints: mediaConstrains, optionalConstraints: nil)
        peerConnection.answer(for: constraints) { [weak self] (sdp, error) in
            guard let self = self, let sdp = sdp else { return }
            self.peerConnection.setLocalDescription(sdp) { _ in
                completion(sdp.sdp)
            }
        }
    }
    
    func setRemoteDiscriptionForOffer(remoteSdp: String) {
        let sdpType: RTCSdpType = .offer
        let sdp = RTCSessionDescription(type: sdpType, sdp: remoteSdp)
        
        peerConnection.setRemoteDescription(sdp) { error in
            if let error = error {
                print("Error setting remote description: \(error)")
            }
        }
    }
    func setRemoteDiscriptionForAnswer(remoteSdp: String) {
        let sdpType: RTCSdpType = .answer
        let sdp = RTCSessionDescription(type: sdpType, sdp: remoteSdp)
        
        peerConnection.setRemoteDescription(sdp) { error in
            if let error = error {
                print("Error setting remote description: \(error)")
            }
        }
    }
    
    func set(remoteCandidate: RTCIceCandidate) {
        peerConnection.add(remoteCandidate)
    }
    
    
    
}

extension WebRTCManager: RTCPeerConnectionDelegate {
    func peerConnection(_ peerConnection: RTCPeerConnection, didGenerate candidate: RTCIceCandidate) {
        delegate?.webRTCClient(self, didDiscoverLocalCandidate: candidate)
    
    }
    func peerConnection(_ peerConnection: RTCPeerConnection, didChange stateChanged: RTCSignalingState) {
        
    }
    
    func peerConnection(_ peerConnection: RTCPeerConnection, didAdd stream: RTCMediaStream) {
        if let track = stream.audioTracks.first {
            delegate?.webRTCClient(self, didReceiveRemoteAudioTrack: track)
            
        }
        
    }
    func peerConnection(_ peerConnection: RTCPeerConnection, didStartReceivingOn transceiver: RTCRtpTransceiver) {
        if let track = transceiver.receiver.track as? RTCAudioTrack  {
            delegate?.webRTCClient(self, didReceiveRemoteAudioTrack: track)
            
        }
    }
    
    func peerConnection(_ peerConnection: RTCPeerConnection, didRemove stream: RTCMediaStream) {
        
    }
    
    func peerConnectionShouldNegotiate(_ peerConnection: RTCPeerConnection) {
    
    }
    
    func peerConnection(_ peerConnection: RTCPeerConnection, didChange newState: RTCIceConnectionState) {
        delegate?.webRTCClient(self, didChangeConnectionState: newState)
    }
    
    func peerConnection(_ peerConnection: RTCPeerConnection, didChange newState: RTCIceGatheringState) {
    
    }
    
   
    
    func peerConnection(_ peerConnection: RTCPeerConnection, didRemove candidates: [RTCIceCandidate]) {
       
    }
    
    func peerConnection(_ peerConnection: RTCPeerConnection, didOpen dataChannel: RTCDataChannel) {
        
    }
}
