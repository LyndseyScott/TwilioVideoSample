//
//  ViewController.swift
//  TwilioVideoSample
//
//  Created by Lyndsey Scott on 6/17/20.
//  Copyright © 2020 Lyndsey Scott LLC. All rights reserved.
//

import UIKit

import TwilioVideo

class ViewController: UIViewController {

    // MARK:- View Controller Members
    
    // Video SDK components
    var room: Room?
    var remoteParticipant: RemoteParticipant?
    let apiClient = APIClient()
    let baseURL = "[INSERT YOUR SERVER URL HERE]"
    
    // Create a Capturer to provide content for the video track
    lazy var localVideoTrack: LocalVideoTrack? = {
        // Create a video track with the capturer.
        if let camera = camera {
            return LocalVideoTrack(source: camera, enabled: true, name: "Camera")
        }
        return nil
    }()
    
    // Create an audio track
    var localAudioTrack = LocalAudioTrack(options: nil, enabled: true, name: "Microphone")

    lazy var camera: CameraSource? = {
        let options = CameraSourceOptions.init { (builder) in
            if let windowScene = UIApplication.shared.windows.filter({$0.isKeyWindow}).first?.windowScene {
                builder.orientationTracker = UserInterfaceTracker(scene: windowScene)
            }
        }
        let camera = CameraSource(options: options, delegate: self)
        return camera
    }()
    
    // MARK:- UI Element Outlets and handles
    
    // `VideoView` created from a storyboard
    @IBOutlet weak var remoteView: VideoView!
    @IBOutlet weak var previewView: VideoView!
    @IBOutlet weak var connectButton: UIButton!
    @IBOutlet weak var disconnectButton: UIButton!
    
    // Constants to determine room creation settings
    let username = "[UNIQUE USERNAME]"
    let roomName = "[ROOM NAME]"
    let recordRoom = true
    
    // MARK:- UIViewController
    override func viewDidLoad() {
        super.viewDidLoad()
        UIApplication.shared.isIdleTimerDisabled = true
    }
    
    override func viewDidAppear(_ animated: Bool) {
        // Preview our local camera track in the local video preview view.
        super.viewDidAppear(animated)
        startPreview()
    }
    
    // MARK:- Room Setup
    func startPreview() {
        // Confirm the front camera exists and store it as an AVCaptureDevice
        if let frontCamera = CameraSource.captureDevice(position: .front),
            let camera = camera {
            // Preview our local camera track in the local video preview view.
            localVideoTrack = LocalVideoTrack(source: camera, enabled: true, name: "Camera")
            localVideoTrack?.addRenderer(previewView)
            camera.startCapture(device: frontCamera) { (captureDevice, videoFormat, error) in
                if let error = error {
                    print("Capture failed with error.\ncode = \((error as NSError).code) error = \(error.localizedDescription)")
                } else {
                    self.previewView.shouldMirror = (captureDevice.position == .front)
                }
            }
        }
    }
    
    @IBAction func connect(sender: AnyObject) {
        createRoom(recordRoom, roomName, username) { (token) in
            self.room = self.joinRoom(with: token)
        }
    }

    func createRoom(_ recordRoom: Bool, _ roomName: String, _ userName: String, _ completion: ((_ token: String) -> Void)? = nil) {
        if let url = URL(string: "\(baseURL)/token") {
            // Get token for rehearsal room
            apiClient.perform("GET", url: url, query: ["identity": userName, "room": roomName], body: nil, header: nil) { (result, error) in
                if let error = error {
                    print("Token creation error: \(error.localizedDescription)")
                } else if let token = result as? String, let url = URL(string: "\(self.baseURL)/create_room") {
                    // Create rehearsal room if it doesn't exist yet
                    self.apiClient.perform("POST", url: url, query: ["room_name": roomName, "record_room": recordRoom ? "true":"false"], body: nil, header: nil) { (result, error) in
                        if let error = error {
                            print("Room creation error: \(error.localizedDescription)")
                        } else if let resultData = (result as? String)?.data(using: .utf8) {
                            do {
                                let resultDictionary = try JSONSerialization.jsonObject(with: resultData, options: JSONSerialization.ReadingOptions.allowFragments) as? [String:Any]
                                print(resultDictionary as Any)
                            } catch {
                                print("JSON Error: \(error as Any)")
                            }
                        }
                        print("Room Token: \(token)")
                        completion?(token)
                    }
                }
            }
        }
    }
    
    func joinRoom(with accessToken: String) -> Room {
        let connectOptions = ConnectOptions(token: accessToken) { (builder) in
            builder.roomName = self.roomName
            if let audioTrack = self.localAudioTrack {
                builder.audioTracks = [ audioTrack ]
            }
            if let videoTrack = self.localVideoTrack {
                builder.videoTracks = [ videoTrack ]
            }
        }
        return TwilioVideoSDK.connect(options: connectOptions, delegate: self)
    }
    
    @IBAction func disconnect(sender: AnyObject) {
        room?.disconnect()
        if recordRoom {
            createComposition()
        }
        room = nil
        remoteParticipant = nil
        
        connectButton.isHidden = false
        disconnectButton.isHidden = true
    }
    
    func createComposition() {
        guard let room = self.room,
            let participantId = room.localParticipant?.sid else {
            return
        }
        if let createCompositionURL = URL(string: "\(baseURL)/create_composition") {
            // Create composition
            // Pass in whatever parameters you'd like associated with the callback, ex. an email address you'd like to message after the composition finishes processing
            apiClient.perform("POST", url: createCompositionURL, query: ["room_id": room.sid, "participant_id": participantId, "email" : ""], body: nil, header: nil) { (result, error) in
                if let error = error {
                    print(error.localizedDescription)
                } else if let compositionId = result as? String {
                    print("Composition ID: \(compositionId)")
                }
            }
        }
    }
}

// MARK:- RoomDelegate
extension ViewController : RoomDelegate {
    
    func roomDidConnect(room: Room) {
        print("Connected to room \(room.name) as \(room.localParticipant?.identity ?? "")")
        remoteParticipant = room.remoteParticipants.first
        remoteParticipant?.delegate = self
        
        connectButton.isHidden = true
        disconnectButton.isHidden = false
    }

    func participantDidConnect(room: Room, participant: RemoteParticipant) {
        print("Participant \(participant.identity) connected with \(participant.remoteAudioTracks.count) audio and \(participant.remoteVideoTracks.count) video tracks")
        remoteParticipant = participant
        remoteParticipant?.delegate = self
    }
    
    
    // For this sample app, the remaining methods in the delegate simply print room/participant status updates
    
    func roomDidDisconnect(room: Room, error: Error?) {
        print("Disconnected from room \(room.name), error = \(String(describing: error))")
    }

    func roomDidFailToConnect(room: Room, error: Error) {
        print("Failed to connect to room with error = \(String(describing: error))")
    }

    func roomIsReconnecting(room: Room, error: Error) {
        print("Reconnecting to room \(room.name), error = \(String(describing: error))")
    }

    func roomDidReconnect(room: Room) {
        print("Reconnected to room \(room.name)")
    }

    func participantDidDisconnect(room: Room, participant: RemoteParticipant) {
        print("Room \(room.name), Participant \(participant.identity) disconnected")
    }
}

// MARK:- RemoteParticipantDelegate
extension ViewController : RemoteParticipantDelegate {

    func didSubscribeToVideoTrack(videoTrack: RemoteVideoTrack, publication: RemoteVideoTrackPublication, participant: RemoteParticipant) {
        // The LocalParticipant is subscribed to the RemoteParticipant's video Track. Frames will begin to arrive now.
        print("Subscribed to \(publication.trackName) video track for Participant \(participant.identity)")
        videoTrack.addRenderer(remoteView)
    }
    
    
    // For this sample app, the remaining methods in the delegate simply print track subscription and publishing status updates
    
    func didUnsubscribeFromVideoTrack(videoTrack: RemoteVideoTrack, publication: RemoteVideoTrackPublication, participant: RemoteParticipant) {
        // We are unsubscribed from the remote Participant's video Track. We will no longer receive the
        // remote Participant's video.
        print("Unsubscribed from \(publication.trackName) video track for Participant \(participant.identity)")
    }
    
    func remoteParticipantDidPublishVideoTrack(participant: RemoteParticipant, publication: RemoteVideoTrackPublication) {
        // Remote Participant has offered to share the video Track.
        print("Participant \(participant.identity) published \(publication.trackName) video track")
    }

    func remoteParticipantDidUnpublishVideoTrack(participant: RemoteParticipant, publication: RemoteVideoTrackPublication) {
        // Remote Participant has stopped sharing the video Track.
        print("Participant \(participant.identity) unpublished \(publication.trackName) video track")
    }

    func remoteParticipantDidPublishAudioTrack(participant: RemoteParticipant, publication: RemoteAudioTrackPublication) {
        // Remote Participant has offered to share the audio Track.
        print("Participant \(participant.identity) published \(publication.trackName) audio track")
    }

    func remoteParticipantDidUnpublishAudioTrack(participant: RemoteParticipant, publication: RemoteAudioTrackPublication) {
        // Remote Participant has stopped sharing the audio Track.
        print("Participant \(participant.identity) unpublished \(publication.trackName) audio track")
    }

    func didSubscribeToAudioTrack(audioTrack: RemoteAudioTrack, publication: RemoteAudioTrackPublication, participant: RemoteParticipant) {
        // We are subscribed to the remote Participant's audio Track. We will start receiving the
        // remote Participant's audio now.
        print("Subscribed to \(publication.trackName) audio track for Participant \(participant.identity)")
    }
    
    func didUnsubscribeFromAudioTrack(audioTrack: RemoteAudioTrack, publication: RemoteAudioTrackPublication, participant: RemoteParticipant) {
        // We are unsubscribed from the remote Participant's audio Track. We will no longer receive the
        // remote Participant's audio.
        print("Unsubscribed from \(publication.trackName) audio track for Participant \(participant.identity)")
    }

    func remoteParticipantDidEnableVideoTrack(participant: RemoteParticipant, publication: RemoteVideoTrackPublication) {
        print("Participant \(participant.identity) enabled \(publication.trackName) video track")
    }

    func remoteParticipantDidDisableVideoTrack(participant: RemoteParticipant, publication: RemoteVideoTrackPublication) {
        print("Participant \(participant.identity) disabled \(publication.trackName) video track")
    }

    func remoteParticipantDidEnableAudioTrack(participant: RemoteParticipant, publication: RemoteAudioTrackPublication) {
        print("Participant \(participant.identity) enabled \(publication.trackName) audio track")
    }

    func remoteParticipantDidDisableAudioTrack(participant: RemoteParticipant, publication: RemoteAudioTrackPublication) {
        print("Participant \(participant.identity) disabled \(publication.trackName) audio track")
    }

    func didFailToSubscribeToAudioTrack(publication: RemoteAudioTrackPublication, error: Error, participant: RemoteParticipant) {
        print("FailedToSubscribe \(publication.trackName) audio track, error = \(String(describing: error))")
    }

    func didFailToSubscribeToVideoTrack(publication: RemoteVideoTrackPublication, error: Error, participant: RemoteParticipant) {
        print("FailedToSubscribe \(publication.trackName) video track, error = \(String(describing: error))")
    }
}

// MARK: TVIVideoViewDelegate
extension ViewController : VideoViewDelegate {
    // Lastly, we can subscribe to important events on the VideoView
    func videoViewDimensionsDidChange(view: VideoView, dimensions: CMVideoDimensions) {
        print("The dimensions of the video track changed to: \(dimensions.width)x\(dimensions.height)")
        view.setNeedsLayout()
    }
}

extension ViewController : CameraSourceDelegate {
    func cameraSourceDidFail(source: CameraSource, error: Error) {
        print("Camera source failed with error: \(error.localizedDescription)")
    }
}
