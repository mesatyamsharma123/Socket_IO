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
    private var remoteCandidatesQueue: [RTCIceCandidate] = []
    var localAudioTrack: RTCAudioTrack?

    
   override init() {

        RTCInitializeSSL()

        let encoderFactory = RTCDefaultVideoEncoderFactory()
        let decoderFactory = RTCDefaultVideoDecoderFactory()


        self.factory = RTCPeerConnectionFactory(encoderFactory: encoderFactory,
                                                decoderFactory: decoderFactory)
       super.init( )
       setupConfiguration()
    }
    
    func setupConfiguration() {
        // Purani connection agar hai toh cleanup karein
        if peerConnection != nil {
            peerConnection.close()
        }
        
        let config = RTCConfiguration()
        config.iceServers = [RTCIceServer(urlStrings: ["stun:stun.l.google.com:19302"])]
        config.sdpSemantics = .unifiedPlan
        
        let constraints = RTCMediaConstraints(mandatoryConstraints: mediaConstrains, optionalConstraints: nil)
        
        // Naya object assign karein
        self.peerConnection = factory.peerConnection(with: config, constraints: constraints, delegate: self)
        print("✅ New PeerConnection Created")
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
        self.localAudioTrack = audioTrack
        

        peerConnection.add(audioTrack, streamIds: ["stream0"])
        
        print(" Audio track added to PeerConnection")
    }
    
    func offer(completion: @escaping (String) -> Void) {
        // Agar connection close ho chuki hai, toh dobara setup karein
        if peerConnection.signalingState == .closed {
            setupConfiguration()
            startAudioOnly() // Tracks dobara add karein
        }

        let constraints = RTCMediaConstraints(mandatoryConstraints: mediaConstrains, optionalConstraints: nil)
        peerConnection.offer(for: constraints) { [weak self] (sdp, error) in
            guard let self = self, let sdp = sdp else {
                print("❌ Offer Error: \(error?.localizedDescription ?? "Unknown")")
                return
            }
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
            let sdp = RTCSessionDescription(type: .offer, sdp: remoteSdp)
            peerConnection.setRemoteDescription(sdp) { [weak self] error in
                if error == nil {
                    self?.drainRemoteCandidatesQueue() 
                }
            }
        }
    func setRemoteDiscriptionForAnswer(remoteSdp: String) {
            let sdp = RTCSessionDescription(type: .answer, sdp: remoteSdp)
            peerConnection.setRemoteDescription(sdp) { [weak self] error in
                if error == nil {
                    self?.drainRemoteCandidatesQueue()
                }
            }
        }
    
    func set(remoteCandidate: RTCIceCandidate) {
            if peerConnection.remoteDescription != nil {
                peerConnection.add(remoteCandidate)
                print("❄️ ICE Candidate added immediately")
            } else {
                // Queue mein daal dein agar description abhi set nahi hua
                remoteCandidatesQueue.append(remoteCandidate)
                print("⏳ Candidate queued. Waiting for remote description...")
            }
        }
    
    private func drainRemoteCandidatesQueue() {
            guard peerConnection.remoteDescription != nil else { return }
            for candidate in remoteCandidatesQueue {
                peerConnection.add(candidate)
            }
            print("✅ Drained \(remoteCandidatesQueue.count) queued candidates")
            remoteCandidatesQueue.removeAll()
        }
    func closeConnection() {
        // 1. Tracks hatao
        peerConnection.senders.forEach { peerConnection.removeTrack($0) }
        
        // 2. Connection close karo
        peerConnection.close()
        
        // 3. Audio Session cleanup
        let rtcSession = RTCAudioSession.sharedInstance()
        rtcSession.lockForConfiguration()
        try? rtcSession.setActive(false)
        rtcSession.unlockForConfiguration()

        // 4. 🔥 CRITICAL: Naya object banane se pehle ensure karein queue clear ho
        remoteCandidatesQueue.removeAll()
        
        // 5. Naya connection setup karein for next call
        setupConfiguration()
        print("🔄 WebRTC Reset: Ready for next call")
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
