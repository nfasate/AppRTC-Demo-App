//
//  VideoCallViewController.swift
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

class VideoCallViewController: ParentViewController, ARDAppClientDelegate,RTCEAGLVideoViewDelegate
    
{
    //MARK: IBOutlets variables    
    @IBOutlet var controlsView: UIView!
    
    @IBOutlet var remoteFeedView: RTCEAGLVideoView!
    
    /// UIView object which will display the local video feed of the user.
    @IBOutlet var localFeedView: RTCEAGLVideoView!
    
    /// Mic button object
    @IBOutlet var micButton: UIButton!
    
    /// End call button object.
    @IBOutlet var callHangUpButton: UIButton!
    
    /// videoFeedServiceButton toggles between video service start and stop.
    @IBOutlet var videoFeedServiceButton: UIButton!
    
    /// videoCameraButton toggles between front and back cammera
    @IBOutlet var videoCameraButton: UIButton!
    
    /// speakerOnOffButton button object toggle between loud speaker ON / OFF.
    @IBOutlet var speakerOnOffButton: UIButton!
    
    @IBOutlet var videoFeedVerticleConstraint: NSLayoutConstraint!
    
    @IBOutlet var controlBaseViewConstraint: NSLayoutConstraint!
    
    //MARK:- Variables    
    /// Main ARDAppClient Object - Performs the connection to the AppRTC Server and joins the call.
    var client           : ARDAppClient?
    /// RTCVideoTrack Object to store video track of local feed
    var localVideoTrack  : RTCVideoTrack?
    /// RTCVideoTrack Object to store video track of remote feed
    var remoteVideoTrack : RTCVideoTrack?
    var isRemoteConnected : Bool = false
    /// Object to store meeting url - Type String
    var meetingURLString:String!
    /// Object to store host ulr for WebRTC call
    var hostUrlString: String!
    let stillImageOutput = AVCaptureStillImageOutput()
    
    var videoOutput = AVCaptureVideoDataOutput()
    let audioOutput = AVCaptureAudioDataOutput()
    var externalSampleBufferDelegate: AVCaptureVideoDataOutputSampleBufferDelegate!
    var adapter:AVAssetWriterInputPixelBufferAdaptor!
    var record = false
    var videoWriter:AVAssetWriter!
    var writerInput:AVAssetWriterInput!
    var audioWriterInput:AVAssetWriterInput!
    var lastPath = ""
    var lastPathURL : URL!
    var starTime = kCMTimeZero
    var imageClicked = false
    
    
    var captureController:ARDCaptureController = ARDCaptureController()
    
    //MARK:- Default Override Functions    
    override func viewDidLoad()
    {
        super.viewDidLoad()
        
        UIApplication.shared.isIdleTimerDisabled = true
        
        Singleton.sharedInstance.delay(50) {
            if self.isRemoteConnected == false {
                
                if Macros.Constants.webRTC_AdminCallId == 0
                {
                    self.dismissVC(false)
                }else
                {
                    self.disconnect()
                    self.dismissVC(false)
                }
            }
        }
    }
    
    override func viewWillAppear(_ animated: Bool)
    {
        super.viewWillAppear(animated)
        if Macros.Constants.webRTC_AdminCallId == 0
        {
            videoCameraButton .setImage(UIImage(named: "captureImage"), for: UIControlState())
            videoFeedServiceButton .setImage(UIImage(named: "callReject"), for: UIControlState())
            callHangUpButton .isHidden = true
        }else
        {
            
        }
        
        if Macros.Constants.webRTC_MeetingUrl != ""
        {
            let url = Macros.Constants.webRTC_MeetingUrl
            
            meetingURLString = url
        }
        
        if Macros.Constants.webRTC_HostUrl != ""
        {
            let url = Macros.Constants.webRTC_HostUrl
            
            hostUrlString = url
        }
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        directJoinMeeting()
        self.view.bringSubview(toFront: self.localFeedView)
    }
    
    override func viewDidDisappear(_ animated: Bool)
    {
        super.viewDidDisappear(animated)
        if UIDevice.current.userInterfaceIdiom == .pad
        {
            NotificationCenter.default.removeObserver(self, name: NSNotification.Name.AVAudioSessionRouteChange, object: nil)
        }
    }
    
    //MARK:- Custom Functions    
    /**
     Toggle buttons container view on UI tapped.
     */
    func toggleButtonContainer()
    {
        UIView.animate(withDuration: 0.3, animations: { () -> Void in
            if (self.controlBaseViewConstraint!.constant <= -40.0) {
                self.controlBaseViewConstraint!.constant = 20.0
                self.controlsView!.alpha = 1.0
            }
            else {
                self.controlBaseViewConstraint!.constant = -40.0
                self.controlsView!.alpha = 0.0
            }
            self.view.layoutIfNeeded()
            self.view.bringSubview(toFront: self.localFeedView)
        })
    }
    
    /**
     To remove all the child view controller and observer and dismiss current view controller on admin call.
     */
    func dismissViewOnSOSAdmiCall()
    {
        self.isRemoteConnected = true
        if self.client != nil
        {
            if Macros.Constants.webRTC_CallType == 2
            {
                if self.localVideoTrack != nil
                {
                    self.localVideoTrack?.remove(self.localFeedView)
                    self.localFeedView.renderFrame(nil)
                    self.localVideoTrack = nil
                }
            }
            
            if self.remoteVideoTrack != nil
            {
                self.remoteVideoTrack?.remove(self.remoteFeedView)
                self.remoteFeedView?.renderFrame(nil)
                self.remoteVideoTrack = nil
            }
        }
    }
    
    /**
     To remove all the child view controller and observer and dismiss current view controller on peer call.
     */
    func dismissVC(_ isRemoteDisconnected : Bool)
    {
        if Macros.Constants.webRTC_AdminCallId == 0
        {
            GraysLoader.sharedInstance.showLoader(NSLocalizedString("Save_Recorded_Call", comment: ""), blockUI: true, passedView: nil)
            stopVideoRecording(isRemoteDisconnected, completionHandler:
                { (status) in
                    if status == true
                    {
                        Singleton.sharedInstance.delay(2.0, closure:
                            {
                                GraysLoader.sharedInstance.hideLoader()
                                if isRemoteDisconnected == false
                                {
                                    self.disconnect()
                                }else
                                {
                                    self.dismissViewOnSOSAdmiCall()
                                }
                                isGotCall = true
                                Macros.Constants.isUserOnWebRTC_Call = false
                                self .dismiss(animated: true, completion: nil)
                        })
                    }else
                    {
                        GraysLoader.sharedInstance.hideLoader()
                        isGotCall = true
                        Macros.Constants.isUserOnWebRTC_Call = false
                        self .dismiss(animated: true, completion: nil)
                    }
            }) // Saving video with AVAssetWriter
            isGotCall = true
            
        }else
        {
            isGotCall = true
            self .dismiss(animated: true, completion: nil)
            Macros.Constants.isUserOnWebRTC_Call = false
        }
    }
    
    func directJoinMeeting()
    {
        self.joinMeeting()
    }
    
    func joinMeeting()
    {
        connectToAVideoChatRoom()
    }
    
    /**
     This function will be called accordingly ,If user pressed accept status will be 1 , if presses reject 2, if presses ended status will be 3
     
     - parameter status: Status is a integer value betweem 0-4
     */
    func notifyCallerPubNub(_ status1: Int, repeatCounter : Int)
    {
        Macros.Constants.webRTC_AcceptRejectStatus = status1
        if clientPubNub != nil
        {
            clientPubNub .publish("Video call ended -  \(MPUserDefaults.sharedInstance.getUserName())", toChannel: "\(Macros.Constants.webRTC_CallerId)", mobilePushPayload: Singleton.sharedInstance.getPayloadPubNubAcceptRejectCall("Video call ended -  \(MPUserDefaults.sharedInstance.getUserName())"), withMetadata: Singleton.sharedInstance.getPayloadPubNubAcceptRejectCall("Video call ended -  \(MPUserDefaults.sharedInstance.getUserName())"), completion: { (status) in
                //print(status)
                if status.isError == false
                {
                    if status1 == 1
                    {
                        AlertView.showToastAt(UIScreen.main.bounds.size.height - 200, viewHeight: 45.0, viewWidth: self.view.frame.size.width, bgColor: Macros.Colors.yellowColor, shadowColor: UIColor.darkGray, txtColor: UIColor.white, onScreenTime: 1.5, title: NSLocalizedString("Connecting", comment: ""), view: nil)
                        
                        self.joinMeeting()
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
    
    /*
     -Initializes the ARDAppClient with the delegate assignment
     -RTCEAGLVideoViewDelegate provides notifications on video frame dimensions
     */
    func inititaliseAppRTCForVideoCall()
    {
        self.client = ARDAppClient (delegate: self)
        
        self.remoteFeedView     .delegate   = self
        
        self.localFeedView      .delegate   = self
        
        stillImageOutput.outputSettings = [AVVideoCodecKey:AVVideoCodecJPEG]
        
        if Macros.Constants.webRTC_AdminCallId == 0
        {
            //client?.isSosCall = true
            
        }else {
            //client?.isSosCall = false
            videoCameraButton.tag = 51
        }
        
        micButton.tag = 61
        
        speakerOnOffButton.tag = 71
        
        videoFeedServiceButton.tag = 81
        
        let tapGestureRecognizer: UITapGestureRecognizer = UITapGestureRecognizer(target: self, action: #selector(self.toggleButtonContainer))
        
        tapGestureRecognizer.numberOfTapsRequired = 1
        
        self.view!.addGestureRecognizer(tapGestureRecognizer)
        
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
     To connect webRTC Video call Room.
     */
    func connectToAVideoChatRoom()
    {
        //Logger
        // heCustomLogger.info("inititaliseAppRTCForVideoCall")
        
        inititaliseAppRTCForVideoCall()
        //self.client?.serverHostUrl = self.hostUrlString
        //self.client?.connectToRoom(withId: self.meetingURLString, options: nil)
        
        let settingsModel = ARDSettingsModel()
        client!.connectToRoom(withId: self.meetingURLString, settings: settingsModel, isLoopback: false, isAudioOnly: false, shouldMakeAecDump: false, shouldUseLevelControl: false)
    }
    
    /**
     Called when audio call get disconnected or ended.
     */
    func remoteDisconnect()
    {
        if Macros.Constants.webRTC_AdminCallId == 0
        {
            dismissVC(true)
        }else
        {
            self.isRemoteConnected = true
            if self.client != nil
            {
                if Macros.Constants.webRTC_CallType == 2
                {
                    if self.localVideoTrack != nil
                    {
                        self.localVideoTrack?.remove(self.localFeedView)
                        self.localFeedView.renderFrame(nil)
                        self.localVideoTrack = nil
                    }
                }
                
                if (self.remoteVideoTrack != nil)
                {
                    self.remoteVideoTrack?.remove(self.remoteFeedView)
                    self.remoteFeedView?.renderFrame(nil)
                    self.remoteVideoTrack = nil
                }
            }
            //Logger
            // heCustomLogger.info("remoteDisconnect()")
            dismissVC(false)
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
            if self.localVideoTrack != nil
            {
                self.localVideoTrack?.remove(self.localFeedView)
                self.localFeedView?.renderFrame(nil)
                self.localVideoTrack = nil
            }
            
            if self.remoteVideoTrack != nil
            {
                self.remoteVideoTrack?.remove(self.remoteFeedView)
                self.remoteFeedView?.renderFrame(nil)
                self.remoteVideoTrack = nil
            }
            
            self.client?.disconnect()
            notifyCallerPubNub(3, repeatCounter: 1)
        }
    }
    
    /**
     Called when user end the call or disconnect the call.
     */
    func hangUpCall()
    {
        if Macros.Constants.webRTC_AdminCallId == 0
        {
            // heCustomLogger.info("hangUpCallButtonPressed")
            dismissVC(false)
            
        }else
        {
            // heCustomLogger.info("hangUpCallButtonPressed")
            disconnect()
            dismissVC(false)
        }
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
    
    /*
     Video Camera Button button to toggle between front and back camera of iPhone.
     
     - parameter sender: AnyObject
     */
    @IBAction func videoCameraFlipButtonPressed(_ sender: AnyObject)
    {
        
        if Macros.Constants.webRTC_AdminCallId == 0
        {
            imageCaptureFromSession()
            return
        }
        
        if self.client != nil && isRemoteConnected == true
        {
            if videoCameraButton.tag == 51
            {
                captureController.switchCamera()
                videoCameraButton .setImage(UIImage(named: "switch_camera_onn"), for: UIControlState())
                
                videoCameraButton.tag = 50
                
            }else
            {
                captureController.switchCamera()
                videoCameraButton .setImage(UIImage(named: "switch_camera_off"), for: UIControlState())
                
                videoCameraButton.tag = 51
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
    
    @IBAction func videoFeedOnOffButtonPressed(_ sender: AnyObject)
    {
        if Macros.Constants.webRTC_AdminCallId == 0
        {
            hangUpCall()
            
        }else
        {
            if self.client != nil && isRemoteConnected == true
            {
                if videoFeedServiceButton.tag == 81
                {
                    //remoteFeedView.hidden = true
                    localFeedView.isHidden = true
                    
                    self.client?.toggleVideoMute()
                    
                    videoFeedServiceButton .setImage(UIImage(named: "videoCross"), for: UIControlState())
                    videoFeedServiceButton.tag = 80
                    
                    videoFeedVerticleConstraint.constant = -40
                    videoCameraButton.isHidden = true
                    
                }else
                {
                    //remoteFeedView.hidden = false
                    localFeedView.isHidden = false
                    
                    self.client?.toggleVideoMute()
                    
                    videoFeedServiceButton .setImage(UIImage(named: "video_on"), for: UIControlState())
                    videoFeedServiceButton.tag = 81
                    
                    videoFeedVerticleConstraint.constant = 15
                    videoCameraButton.isHidden = false
                }
            }
        }
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
            //Logger
            // heCustomLogger.info("Connected")
            
            //print("Connected")
            break
        case .connecting:
            AlertView.showToastAt(UIScreen.main.bounds.size.height - 200, viewHeight: 45.0, viewWidth: self.view.frame.size.width, bgColor: Macros.Colors.yellowColor, shadowColor: UIColor.darkGray, txtColor: UIColor.white, onScreenTime: 1.5, title: NSLocalizedString("Connecting", comment: ""), view: nil)
            //print("Connecting...")
            //Logger
            // heCustomLogger.info("Connecting")
            
            
            break
        case .disconnected:
            //print("Disconnected!")
            AlertView.showToastAt(UIScreen.main.bounds.size.height - 200, viewHeight: 45.0, viewWidth: self.view.frame.size.width, bgColor: Macros.Colors.yellowColor, shadowColor: UIColor.darkGray, txtColor: UIColor.white, onScreenTime: 1.5, title: NSLocalizedString("Disconnected", comment: ""), view: nil)
            //Logger
            // heCustomLogger.info("Disconnected")
            
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
        if Macros.Constants.webRTC_AdminCallId == 0
        {
//            let videoLayer = AVCaptureVideoPreviewLayer(session: self.client?.recordCaptureSession.captureSession)
//            videoLayer?.videoGravity = AVLayerVideoGravityResizeAspectFill
//            videoLayer?.frame = self.localFeedView.bounds
//            DispatchQueue.main.async {
//                self.localFeedView.layer .addSublayer(videoLayer!)
//            }
//            
//            let delay = DispatchTime.now() + .seconds(1)
//            DispatchQueue.main.asyncAfter(deadline: delay, execute: {
//                self.startImageVideoRec()
//            })
            
        }else {
            self.localVideoTrack?.remove(self.localFeedView!)
            self.localFeedView?.renderFrame(nil)
            self.localVideoTrack = localVideoTrack
            self.localVideoTrack?.add(self.localFeedView!)
        }
    }
    
    /*!
     This delegates fires as soon as remote video feed is available,
     
     - parameter client:           ARDAppClient
     - parameter remoteVideoTrack: RTCVideoTrack
     */
    func appClient(_ client: ARDAppClient!, didReceiveRemoteVideoTrack remoteVideoTrack: RTCVideoTrack!)
    {
        self.remoteVideoTrack = remoteVideoTrack
        //DispatchQueue.main.async {
        self.remoteVideoTrack?.add(self.remoteFeedView)
        
        //}
        //localFeedView.hidden = false
        AlertView.showToastAt(UIScreen.main.bounds.size.height - 200, viewHeight: 45.0, viewWidth: self.view.frame.size.width, bgColor: Macros.Colors.yellowColor, shadowColor: UIColor.darkGray, txtColor: UIColor.white, onScreenTime: 1.5, title: NSLocalizedString("Feed_Received", comment: ""), view: nil)
        //Logger
        // heCustomLogger.info("Feed received...")
        
        Singleton.sharedInstance.delay(0.5) {
            if self.client != nil
            {
                self.isRemoteConnected = true
            }
        }
    }
    
    
    public func appClient(_ client: ARDAppClient!, didError error: Error!)
    {
        //print("Grays Error - \(error.localizedDescription)")
        //Logger
        // heCustomLogger.info("ARDAppClient - \(error.localizedDescription)")
        
    }
    
    public func appClient(_ client: ARDAppClient!, didCreateLocalCapturer localCapturer: RTCCameraVideoCapturer!) {
        let settingsModel = ARDSettingsModel()
        captureController = ARDCaptureController(capturer: localCapturer, settings: settingsModel)
        captureController.startCapture()
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
//    
//    func peerConnection(_ peerConnnection: RTCPeerConnection!, iceGatheringChanged newState: RTCICEGatheringState)
//    {
//        
//    }
}

//MARK:- Extension class    
extension VideoCallViewController:AVCaptureVideoDataOutputSampleBufferDelegate,AVCaptureAudioDataOutputSampleBufferDelegate
{
    //MARK: AVCaptureVideoDataOutputSampleBuffer Delegate
    func captureOutput(_ captureOutput: AVCaptureOutput!, didOutputSampleBuffer sampleBuffer: CMSampleBuffer!, from connection: AVCaptureConnection!)
    {
        starTime = CMSampleBufferGetPresentationTimeStamp(sampleBuffer)
        
        if captureOutput == videoOutput
        {
            if self.record == true{
                let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer)
                
                if self.record == true
                {
                    if self.writerInput.isReadyForMoreMediaData
                    {
                        DispatchQueue(label: "newQeueLocalFeedVideo2", attributes: DispatchQueue.Attributes.concurrent).sync(execute: {
                            starTime = CMSampleBufferGetPresentationTimeStamp(sampleBuffer)
                            
                            let bobo = self.adapter.append(pixelBuffer!, withPresentationTime: self.starTime)
                            print("video conversion is \(bobo)")
                            //                            print("Dropped reason - \(kCMSampleBufferAttachmentKey_DroppedFrameReason)")
                            if self.imageClicked == true
                            {
                                // Save image here.
                                self.imageClicked = false
                                
                                // Save image here.
                                self.imageClicked = false
                                let bufferRef : CVImageBuffer = CMSampleBufferGetImageBuffer(sampleBuffer)!
                                let img = DejalActivityView.screenshot(ofVideoStream: bufferRef)
                                HEPhotoLibraryHelper.saveImagesToPhotoLibrary(img!)
                            }
                        })
                    }
                }
            }
        }else if captureOutput == audioOutput
        {
            if self.record == true
            {
                if audioWriterInput.isReadyForMoreMediaData
                {
                    let bo = audioWriterInput.append(sampleBuffer)
                    print("audio conversion is \(bo)")
                }
            }
        }
        
        if localVideoTrack != nil
        {
            //self.externalSampleBufferDelegate?.captureOutput!(captureOutput, didOutputSampleBuffer: sampleBuffer, fromConnection: connection)
            
            DispatchQueue(label: "newQeueLocalFeedSent", attributes: DispatchQueue.Attributes.concurrent).sync(execute: {
                
                self.externalSampleBufferDelegate?.captureOutput!(captureOutput, didOutputSampleBuffer: sampleBuffer, from: connection)
            })
        }
    }
    
    //MARK: Custom Functions
    /**
     Convert CIImage to CGImage.
     */
    func convertCIImageToCGImage(_ inputImage: CIImage) -> CGImage! {
        let context:CIContext? = CIContext(options: nil)
        if context != nil {
            return context!.createCGImage(inputImage, from: inputImage.extent)
        }
        return nil
    }
    
    /**
     Get current date to store video with current date name.
     */
    func getCurrentDate()->String
    {
        //  Make a variable equal to a random number....
        let randomNum:UInt32 = arc4random_uniform(100) + 1 // range is 0 to 99
        let randomNum2:UInt32 = arc4random_uniform(600) + 200// range is 0 to 99
        let randomNum3:UInt32 = arc4random_uniform(900)  + 700// range is 0 to 99
        return String(randomNum + randomNum2 + randomNum3) //string works too
    }
    
    /**
     Record video with asset writer.
     */
    func recordVideoWithAssetWriter()
    {
        if self.localVideoTrack != nil
        {
            if record
            {
                record = false
                self.writerInput.markAsFinished()
                audioWriterInput.markAsFinished()
                
                self.videoWriter.finishWriting { () -> Void in
                    
                    HEPhotoLibraryHelper.saveVideosToPhotoLibrary(self.lastPathURL, withCompletionBlock: { (result) in
                        if result == true
                        {
                            do
                            {
                                try HEDocDirectory.shared.fileManagerDefault .removeItem(atPath: self.lastPath)
                            }catch let err as  NSError
                            {
                                //print("Error in removing file from doc dir \(err.localizedDescription)")
                            }
                        }
                    })
                }
            }else{
                
                let fileUrl = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("\(getCurrentDate())-capturedvideo.mp4")
                
                lastPath = fileUrl.path
                videoWriter = try? AVAssetWriter(outputURL: fileUrl, fileType: AVFileTypeMPEG4)
                lastPathURL = fileUrl
                
                let outputSize = CGSize(width: UIScreen.main.bounds.width, height: UIScreen.main.bounds.height)
                
                let outputSettings = [AVVideoCodecKey : AVVideoCodecH264, AVVideoWidthKey : NSNumber(value: Float(outputSize.width) as Float), AVVideoHeightKey : NSNumber(value: Float(outputSize.height) as Float)] as [String : Any]
                
                writerInput = AVAssetWriterInput(mediaType: AVMediaTypeVideo, outputSettings: outputSettings)
                writerInput.expectsMediaDataInRealTime = true
                //                writerInput.performsMultiPassEncodingIfSupported = true
                audioWriterInput = AVAssetWriterInput(mediaType: AVMediaTypeAudio, outputSettings: DejalActivityView.getAudioDictionary() as? [String:AnyObject])
                
                videoWriter.add(writerInput)
                videoWriter.add(audioWriterInput)
                
                adapter = AVAssetWriterInputPixelBufferAdaptor(assetWriterInput: writerInput, sourcePixelBufferAttributes: DejalActivityView.getAdapterDictionary() as? [String:AnyObject])
                
                videoWriter.startWriting()
                videoWriter.startSession(atSourceTime: starTime)
                //self.client?.recordCaptureSession.captureSession.startRunning()
                
                record = true
            }
        }
    }
    
    /**
     Configure Video recording.
     */
    func startImageVideoRec()
    {
//        (self.client?.recordCaptureSession.captureSession.beginConfiguration())!
//        
//        let audio = AVCaptureDevice.defaultDevice(withMediaType: AVMediaTypeAudio)
//        do
//        {
//            let audioInput = try AVCaptureDeviceInput(device: audio)
//            
//            self.client?.recordCaptureSession.captureSession.addInput(audioInput)
//            
//        }
//        catch  let error as NSError
//        {
//            print("can't access Audio - \(error.localizedDescription)")
//            //return
//        }
//        
//        videoOutput = self.client?.recordCaptureSession.captureSession.outputs[0] as! AVCaptureVideoDataOutput
//        let recordQueue = DispatchQueue(label: "newQeueLocalFeedVideo", attributes: .concurrent)
//        
//        //let recordQueue = DispatchQueue(label: "newQeueLocalFeedVideo", attributes: DispatchQueue.Attributes.concurrent)
//        
//        //let serialQueue = DispatchQueue(label: "newQeueLocalFeedVideo")
//        
//        for outputs in (self.client?.recordCaptureSession.captureSession.outputs)!
//        {
//            if let videoOutput = outputs as? AVCaptureVideoDataOutput {
//                // adding self as delegate and store rtc as externalSampleBufferDelegate
//                self.externalSampleBufferDelegate = self.videoOutput.sampleBufferDelegate
//                videoOutput.setSampleBufferDelegate(self, queue: recordQueue)
//            }
//        }
//        
//        self.client?.recordCaptureSession.captureSession.addOutput(audioOutput)
//        audioOutput.setSampleBufferDelegate(self, queue: recordQueue)
//        self.client?.recordCaptureSession.captureSession.commitConfiguration()
//        self.client?.recordCaptureSession.captureSession.startRunning()
//        recordVideoWithAssetWriter()
//        
//        if Macros.Constants.isHeroEyezOpTap == true
//        {
//            Macros.Constants.isHeroEyezOpTap = false
//            
//            if UIDevice.current.userInterfaceIdiom != .pad
//            {
//                informHeroEyezOperatorAboutSOSCall()
//            }
//        }else {
//            if UIDevice.current.userInterfaceIdiom != .pad
//            {
//                informAdminAboutSOSCall()
//            }
//        }
    }
    
    /**
     Inform SOS Admin to connect video call.
     */
    func informAdminAboutSOSCall()
    {
        if clientPubNub != nil {
            clientPubNub .publish(Macros.Constants.webRTCAlertMessage, toChannel: "adminChannel", mobilePushPayload: nil , withMetadata: nil, completion: { (status) in
                
                if status.isError == false && status.data.information == "Sent"
                {
                    //Logger
                }else
                {
                    GraysLoader.sharedInstance.hideLoader()
                    Singleton.sharedInstance.showAlertWithText(NSLocalizedString("Device_Unreachable", comment: ""), text: NSLocalizedString("Please_Try_Again_Title", comment: ""), target: self)
                    Macros.Constants.isUserOnWebRTC_Call = false
                }
            })
        }else {
            if Macros.Constants.autoLogin == true
            {
                MPUserDefaults.sharedInstance.setUserOnlineForPubNub()
                Singleton.sharedInstance.delay(1.5, closure: {
                    self.informAdminAboutSOSCall()
                })
            }
        }
    }
    
    /**
     Inform HeroEyez Operator to connect video call.
     */
    func informHeroEyezOperatorAboutSOSCall()
    {
        if clientPubNub != nil
        {
            clientPubNub .publish(Macros.Constants.webRTCAlertMessage, toChannel: "AdminOperator", mobilePushPayload: nil , withMetadata: nil, completion: { (status) in
                
                if status.isError == false && status.data.information == "Sent"
                {
                    //Logger
                }else
                {
                    GraysLoader.sharedInstance.hideLoader()
                    Singleton.sharedInstance.showAlertWithText(NSLocalizedString("Device_Unreachable", comment: ""), text: NSLocalizedString("Please_Try_Again_Title", comment: ""), target: self)
                    Macros.Constants.isUserOnWebRTC_Call = false
                }
            })
        }else {
            if Macros.Constants.autoLogin == true
            {
                MPUserDefaults.sharedInstance.setUserOnlineForPubNub()
                Singleton.sharedInstance.delay(1.5, closure: {
                    self.informHeroEyezOperatorAboutSOSCall()
                })
            }
        }
    }
    
    func configurateForRecording()
    {
//        let recordQueue = DispatchQueue(label: "newQeueLocalFeedVideo", attributes: DispatchQueue.Attributes.concurrent)
//        
//        for outputs in (self.client?.recordCaptureSession.captureSession.outputs)!
//        {
//            if let videoOutput = outputs as? AVCaptureVideoDataOutput {
//                // adding self as delegate and store rtc as externalSampleBufferDelegate
//                self.externalSampleBufferDelegate = self.videoOutput.sampleBufferDelegate
//                videoOutput.setSampleBufferDelegate(self, queue: recordQueue)
//            }
//        }
    }
    
    // Click Image
    func imageCaptureFromSession()
    {
        imageClicked = true
    }
    
    /**
     Stop Video recording after end the call and save it to Photos galary.
     */
    func stopVideoRecording(_ isRemote : Bool, completionHandler:@escaping (_ status : Bool) -> Void)
    {
//        // Stoping recording and de intializing image capture configuration
//        if record == true
//        {
//            record = false
//            self.writerInput.markAsFinished()
//            audioWriterInput.markAsFinished()
//            if self.client?.recordCaptureSession != nil
//            {
//                if isRemote == false
//                {
//                    self.client?.recordCaptureSession.captureSession.stopRunning()
//                }
//            }
//            Singleton.sharedInstance.delay(0.5)
//            {
//                self.videoWriter.finishWriting { () -> Void in
//                    Thread.sleep(forTimeInterval: 1.0)
//                    
//                    if self.videoWriter.status == AVAssetWriterStatus.failed {
//                        //print("oh noes, an error: \(self.videoWriter.error.debugDescription)")
//                        completionHandler(true)
//                        
//                    } else {
//                        //let content = FileManager.default.contents(atPath: self.lastPathURL.path)
//                        //print("wrote video: \(self.lastPathURL.path) at size: \(content?.count)")
//                        
//                        HEPhotoLibraryHelper.saveVideosToPhotoLibrary(self.lastPathURL, withCompletionBlock: { (result) in
//                            
//                            if result == true
//                            {
//                                do
//                                {
//                                    try HEDocDirectory.shared.fileManagerDefault .removeItem(atPath: self.lastPath)
//                                }catch let err as  NSError
//                                {
//                                    //print("Error in removing file from doc dir \(err.localizedDescription)")
//                                }
//                            }
//                            if isRemote == true && self.client?.recordCaptureSession != nil
//                            {
//                                self.client?.recordCaptureSession.captureSession.stopRunning()
//                            }
//                            
//                            completionHandler(true)
//                        })
//                    }
//                }
//            }
//        }else
//        {
//            completionHandler(false)
//        }
    }
}
