//
//  AudioCallViewController.swift
//  RydeTimeRider
//
//  Created by Nilesh Fasate on 24/08/16.
//  Copyright © 2016 Grays Communications LLC. All rights reserved.
//

import UIKit
import GLKit
import AVFoundation
import CoreTelephony
import WebRTC

protocol endAudioCallDelegates {
    func EndAudioCall()
}

class AudioCallViewController: ParentViewController, ARDAppClientDelegate,RTCEAGLVideoViewDelegate
{
    //MARK: IBOutlets variables    
    /// Mic button object
    @IBOutlet var micButton: UIButton!
    
    /// End call button object.
    @IBOutlet var callHangUpButton: UIButton!
    
    /// speakerOnOffButton button object toggle between loud speaker ON / OFF.
    @IBOutlet var speakerOnOffButton: UIButton!
    
    //MARK:- Variables    
    /// Main ARDAppClient Object - Performs the connection to the AppRTC Server and joins the call.
    var client           : ARDAppClient?
    /// RTCVideoTrack Object to store video track of local feed
    var localVideoTrack  : RTCVideoTrack?
    /// RTCVideoTrack Object to store video track of remote feed
    var remoteVideoTrack : RTCVideoTrack?
    
    var isRemoteConnected : Bool = false
    
    /*!
     Variables from Audio View controller
     */
    /// Object to store meeting url - Type String
    var meetingURLString:String!
    
    /// Object to store host ulr for WebRTC call
    var hostUrlString: String!
    
    var delegate : endAudioCallDelegates!
    
    //MARK:- Default Override Functions    
    override func viewDidLoad()
    {
        super.viewDidLoad()
        
        if UIApplication.shared.isIdleTimerDisabled == false
        {
            UIApplication.shared.isIdleTimerDisabled = true
        }
        
        Singleton.sharedInstance.delay(35) {
            if self.isRemoteConnected == false {
                self.disconnect()
            }
        }
    }
    
    override func viewWillAppear(_ animated: Bool)
    {
        super.viewWillAppear(animated)
        if Macros.Constants.webRTC_MeetingUrl != ""
        {
            meetingURLString = Macros.Constants.webRTC_MeetingUrl
        }
        
        if Macros.Constants.webRTC_HostUrl != ""
        {
            
            hostUrlString = Macros.Constants.webRTC_HostUrl
        }
    }
    
    override func viewDidAppear(_ animated: Bool)
    {
        super.viewDidAppear(animated)
        connectToAudioChatRoom()
    }
    
    override func didMove(toParentViewController parent: UIViewController?) {
        
    }
    
    //MARK:- Custom Functions    
    /**
     This function will be called accordingly ,If user pressed accept status will be 1 , if presses reject 2, if presses ended status will be 3
     
     - parameter status: Status is a integer value betweem 0-4
     */
    func notifyCallerPubNub(_ status1: Int, repeatCounter : Int)
    {
        Macros.Constants.webRTC_AcceptRejectStatus = status1
        
        if clientPubNub != nil
        {
            clientPubNub.publish("Audio call ended -  \(MPUserDefaults.sharedInstance.getUserName())", toChannel: "\(Macros.Constants.webRTC_CallerId)", mobilePushPayload: Singleton.sharedInstance.getPayloadPubNubAcceptRejectCall("Audio call ended -  \(MPUserDefaults.sharedInstance.getUserName())"), withMetadata: Singleton.sharedInstance.getPayloadPubNubAcceptRejectCall("Audio call ended -  \(MPUserDefaults.sharedInstance.getUserName())"), completion: { (status) in
                //print(status)
                if status.isError == false
                {
                    if status1 == 1
                    {
                        AlertView.showToastAt(UIScreen.main.bounds.size.height - 200, viewHeight: 45.0, viewWidth: self.view.frame.size.width, bgColor: Macros.Colors.yellowColor, shadowColor: UIColor.darkGray, txtColor: UIColor.white, onScreenTime: 1.5, title: NSLocalizedString("Connecting", comment: ""), view: nil)
                    }else
                    {
                        AlertView.showToastAt(UIScreen.main.bounds.size.height - 200, viewHeight: 45.0, viewWidth: self.view.frame.size.width, bgColor: Macros.Colors.yellowColor, shadowColor: UIColor.darkGray, txtColor: UIColor.white, onScreenTime: 1.5, title: NSLocalizedString("Ended", comment: ""), view: nil)
                    }
                }else
                {
                    if repeatCounter < 3
                    {
                        let newVAL =  repeatCounter + 1
                        self.notifyCallerPubNub(3, repeatCounter: newVAL)
                    }
                }
            })
        }else {
            if Macros.Constants.autoLogin == true
            {
                MPUserDefaults.sharedInstance.setUserOnlineForPubNub()
                Singleton.sharedInstance.delay(1.5, closure: {
                    self.notifyCallerPubNub(status1, repeatCounter: 1)
                })
            }
        }
    }
    
    /*End Video View controller functions*/
    /*
     -Initializes the ARDAppClient with the delegate assignment
     -RTCEAGLVideoViewDelegate provides notifications on video frame dimensions
     */
    func inititaliseAppRTCForAudioCall()
    {
        self.client = ARDAppClient (delegate: self)
        
        micButton.tag = 61
        speakerOnOffButton.tag = 71
        
        if isHeadSetConnected() == true
        {
            DispatchQueue.main.async {
                if self.client != nil
                {
                    self.speakerOnOffButton.isEnabled = true
                    //self.client?.isSpeakerEnabled = false
                    self.speakerOnOffButton.setImage(UIImage(named: "speakerCross"), for: UIControlState())
                    self.speakerOnOffButton.tag = 70
                    return
                }
            }
        }
        
        if UIDevice.current.userInterfaceIdiom == .pad
        {
            speakerOnOffButton.isEnabled = false
            NotificationCenter.default.addObserver(self, selector: #selector(handleRouteChange(_:)), name: NSNotification.Name.AVAudioSessionRouteChange, object: nil)
        }
    }
    
    /**
     To connect webRTC Audio call Room.
     */
    func connectToAudioChatRoom()
    {
        inititaliseAppRTCForAudioCall()
        sleep(2)
        //self.client?.serverHostUrl = self.hostUrlString
        let settingsModel = ARDSettingsModel()
        client!.connectToRoom(withId: self.meetingURLString, settings: settingsModel, isLoopback: false, isAudioOnly: false, shouldMakeAecDump: false, shouldUseLevelControl: false)
        
        //self.client?.connectToRoom(withId: self.meetingURLString, options: nil)
    }
    
    /**
     Called when audio call get disconnected or ended.
     */
    func remoteDisconnect()
    {
        if (self.remoteVideoTrack != nil)
        {
            self.remoteVideoTrack = nil
        }
        self.isRemoteConnected = true
        
        if self.client != nil
        {
            if self.remoteVideoTrack != nil
            {
                self.remoteVideoTrack = nil
            }
            
            
            if Macros.Constants.blurViewForDragAudCallView != nil
            {
                Macros.Constants.blurViewForDragAudCallView.removeFromSuperview()
            }
            
            Macros.Constants.isUserOnWebRTC_Call = false
            isGotCall = true
            self.view.removeFromSuperview()
        }
    }
    
    /*!
     To disconnect the call and remove the participant from the server so that room not gets full uselessly.
     */
    func disconnect()
    {
        self.isRemoteConnected = true
        
        if self.client != nil
        {
            self.client?.disconnect()
            
            if Macros.Constants.blurViewForDragAudCallView != nil
            {
                Macros.Constants.blurViewForDragAudCallView.removeFromSuperview()
            }
            
            Macros.Constants.isUserOnWebRTC_Call = false
            isGotCall = true
            if self.remoteVideoTrack != nil
            {
                self.remoteVideoTrack = nil
                notifyCallerPubNub(3, repeatCounter: 1)
            }
            self.view.removeFromSuperview()
        }
    }
    
    /**
     Called when user end the call or disconnect the call.
     */
    func hangUpCall()
    {
        if Macros.Constants.blurViewForDragAudCallView != nil {
            Macros.Constants.blurViewForDragAudCallView.removeFromSuperview()
        }
        disconnect()
    }
    
    //MARK: Headphone detection functions
    /// To check whether headphone connected or not
    func isHeadSetConnected() -> Bool
    {
        let route = AVAudioSession.sharedInstance().currentRoute;
        for desc in route.outputs
        {
            let portType = desc.portType
            if (portType == AVAudioSessionPortHeadphones)
            {
                return true
            }
        }
        
        return false
    }
    
    /// This method called when audio output route cahenge, like headset/line plugged in/out, audio category changed etc.
    func handleRouteChange(_ notification: Notification)
    {
        DispatchQueue.main.async {
            guard
                let userInfo = notification.userInfo,
                let reasonRaw = userInfo[AVAudioSessionRouteChangeReasonKey] as? NSNumber,
                let reason = AVAudioSessionRouteChangeReason(rawValue: reasonRaw.uintValue)
                else { fatalError("Strange... could not get routeChange") }
            switch reason {
            case .oldDeviceUnavailable:
                //print("oldDeviceUnavailable")
                self.speakerOnOffButton.isEnabled = false
                self.client?.enableSpeaker()
                self.speakerOnOffButton.setImage(UIImage(named: "speaker_on"), for: UIControlState())
                self.speakerOnOffButton.tag = 71
            case .newDeviceAvailable:
                //print("headset/line plugged in")
                self.speakerOnOffButton.isEnabled = true
                //self.client?.disableSpeaker()
                self.speakerOnOffButton.setImage(UIImage(named: "speakerCross"), for: UIControlState())
                self.speakerOnOffButton.tag = 70
            case .routeConfigurationChange:
                print("headset pulled out")
            //speakerOnOffButton.isEnabled = false
            case .categoryChange:
                print("Just category change")
            //speakerOnOffButton.isEnabled = false
            case .override:
                print("route change")
            default:
                print("not handling reason")
                //speakerOnOffButton.isEnabled = false
            }
        }
    }
    
    //MARK:- IBAction Functions    
    /*
     Mic button to toggle between mute and un mute.
     
     - parameter sender: AnyObject
     */
    @IBAction func micButtonPressed(_ sender: AnyObject)
    {
        if self.client != nil && isRemoteConnected == true
        {
            if micButton.tag == 61
            {
                self.client?.toggleAudioMute()
                
                micButton .setImage(UIImage(named: "micCross"), for: UIControlState())
                
                micButton.tag = 60
            }else
            {
                self.client?.toggleAudioMute()
                
                micButton .setImage(UIImage(named: "mic_on"), for: UIControlState())
                
                micButton.tag = 61
            }
        }
    }
    
    @IBAction func speakerOnOffButtonPressed(_ sender: AnyObject)
    {
        if self.client != nil && isRemoteConnected == true
        {
            if speakerOnOffButton.tag == 71
            {
                self.client?.disableSpeaker()
                speakerOnOffButton.setImage(UIImage(named: "speakerCross"), for: UIControlState())
                speakerOnOffButton.tag = 70
                
                if UIDevice.current.userInterfaceIdiom == .pad, isHeadSetConnected() == false
                {
                    speakerOnOffButton.isEnabled = false
                    self.client?.enableSpeaker()
                    speakerOnOffButton.setImage(UIImage(named: "speaker_on"), for: UIControlState())
                    speakerOnOffButton.tag = 71
                }
            }else
            {
                self.client?.enableSpeaker()
                speakerOnOffButton.setImage(UIImage(named: "speaker_on"), for: UIControlState())
                speakerOnOffButton.tag = 71
            }
        }
    }
    
    /*
     End call button , to end and ongoing call.
     
     - parameter sender: AnyObject
     */
    @IBAction func hangUpCallButtonPressed(_ sender: AnyObject)
    {
        hangUpCall()
    }
    
    //MARK:- ARDAppClient Delegate methods    
    /*!
     When state of a video feed changes this delegate will be called.
     
     - parameter client: ARDAppClient
     - parameter state:  ARDAppClientState
     */
    func appClient(_ client: ARDAppClient!, didChange state: ARDAppClientState)
    {
        switch state
        {
        case .connected:
            AlertView.showToastAt(UIScreen.main.bounds.size.height - 200, viewHeight: 45.0, viewWidth: self.view.frame.size.width, bgColor: Macros.Colors.yellowColor, shadowColor: UIColor.darkGray, txtColor: UIColor.white, onScreenTime: 1.5, title: NSLocalizedString("Connected", comment: ""), view: nil)
            self.isRemoteConnected = true
            //print("Connected")
            break
        case .connecting:
            AlertView.showToastAt(UIScreen.main.bounds.size.height - 200, viewHeight: 45.0, viewWidth: self.view.frame.size.width, bgColor: Macros.Colors.yellowColor, shadowColor: UIColor.darkGray, txtColor: UIColor.white, onScreenTime: 1.5, title: NSLocalizedString("Connecting", comment: ""), view: nil)
            //print("Connecting...")
            break
        case .disconnected:
            //print("Disconnected!")
            AlertView.showToastAt(UIScreen.main.bounds.size.height - 200, viewHeight: 45.0, viewWidth: self.view.frame.size.width, bgColor: Macros.Colors.yellowColor, shadowColor: UIColor.darkGray, txtColor: UIColor.white, onScreenTime: 1.5, title: NSLocalizedString("Disconnected", comment: ""), view: nil)
            isGotCall = true
            remoteDisconnect()
            break
        }
    }
    
    /*!
     This delegates fires as soon as we recieve an local video feed
     
     - parameter client:          ARDAppClient
     - parameter localVideoTrack: RTCVideoTrack
     */
    func appClient(_ client: ARDAppClient!, didReceiveLocalVideoTrack localVideoTrack: RTCVideoTrack!)
    {
        
    }
    
    /*!
     This delegates fires as soon as remote video feed is available,
     
     - parameter client:           ARDAppClient
     - parameter remoteVideoTrack: RTCVideoTrack
     */
    func appClient(_ client: ARDAppClient!, didReceiveRemoteVideoTrack remoteVideoTrack: RTCVideoTrack!)
    {
        self.remoteVideoTrack = remoteVideoTrack
        
        //localFeedView.hidden = false
        AlertView.showToastAt(UIScreen.main.bounds.size.height - 200, viewHeight: 45.0, viewWidth: self.view.frame.size.width, bgColor: Macros.Colors.yellowColor, shadowColor: UIColor.darkGray, txtColor: UIColor.white, onScreenTime: 1.5, title: NSLocalizedString("Feed_Received", comment: ""), view: nil)
        self.isRemoteConnected = true
    }
    
    func appClient(_ client: ARDAppClient!, didError error: Error!)
    {
        //print("Grays Error - \(error.localizedDescription)")
    }
    
    public func appClient(_ client: ARDAppClient!, didCreateLocalCapturer localCapturer: RTCCameraVideoCapturer!) {
    
    }
    
    func appclient(_ client: ARDAppClient!, didRotateWithLocal localVideoTrack: RTCVideoTrack!, remoteVideoTrack: RTCVideoTrack!) {
        
    }
    
    public func appClient(_ client: ARDAppClient!, didGetStats stats: [Any]!) {
        
    }
    
    public func appClient(_ client: ARDAppClient!, didChange state: RTCIceConnectionState) {
        
    }
    
    func videoView(_ videoView: RTCEAGLVideoView, didChangeVideoSize size: CGSize)
    {
        //print("Printed video size is - \(size)")
    }
    
    func peerConnection(_ peerConnection: RTCPeerConnection!, didCreateSessionDescription sdp: RTCSessionDescription!, error: NSError?)
    {
        
    }
    func peerConnection(_ peerConnection: RTCPeerConnection!, addedStream stream: RTCMediaStream!)
    {
        
    }
//    func peerConnection(_ peerConnnection: RTCPeerConnection!, iceConnectionChanged newState: RTCICEConnectionState)
//    {
//        
//    }
//    func peerConnection(_ peerConnnection: RTCPeerConnection!, iceGatheringChanged newState: RTCICEGatheringState)
//    {
//        
//    }
}
