//
//  PlayerViewController.swift
//  ChameleonPlayer
//
//  Created by liuyan on 5/24/16.
//  Copyright © 2016 Eyepetizer Inc. All rights reserved.
//

import UIKit
import AVFoundation

class PlayerViewController: UIViewController {
    
    var vrPlayer: VRVideoPlayerView?
    var player: AVPlayer?

    override func viewDidLoad() {
        super.viewDidLoad()

        // Do any additional setup after loading the view.
        let player = AVPlayer(URL: NSURL(string: "http://eyepetizer.ufile.ucloud.com.cn/1495173324927_a7b59cdf.mp4")!)
        self.player = player
        let vrPlayer = VRVideoPlayerView(AVPlayer: player)
//        vrPlayer.frame = CGRect(x: 0, y: 0, width: self.view.bounds.width, height: self.view.bounds.width * 9 / 16.0)
        vrPlayer.frame = self.view.bounds
        vrPlayer.autoresizingMask = [.FlexibleHeight, .FlexibleWidth]
        self.view.addSubview(vrPlayer)
        
        self.vrPlayer = vrPlayer
        
        let button = UIButton(type: .Custom)
        button.frame = CGRect(x: 10, y: 10, width: 120, height: 60)
        self.view.addSubview(button)
        button.setTitle("关闭", forState: .Normal)
        button.addTarget(
            self,
            action: #selector(PlayerViewController.closeButtonTapActionHandler(_:)),
            forControlEvents: .TouchUpInside
        )
        
        let playButton = UIButton(type: .Custom)
        playButton.frame = CGRect(x: 150, y: 10, width: 120, height: 60)
        self.view.addSubview(playButton)
        playButton.setTitle("播放", forState: .Normal)
        playButton.addTarget(
            self,
            action: #selector(PlayerViewController.playButtonTapActionHandler(_:)),
            forControlEvents: .TouchUpInside
        )
        
        self.observeNotifcations()
    }
    
    override func supportedInterfaceOrientations() -> UIInterfaceOrientationMask {
        return .LandscapeRight
    }
    
    override func viewDidAppear(animated: Bool) {
        super.viewDidAppear(animated)
        self.vrPlayer?.play()
    }
    
    override func shouldAutorotate() -> Bool {
        return true
    }
    
    func closeButtonTapActionHandler(sender: UIButton) {
        self.dismissViewControllerAnimated(true, completion: nil)
    }
    
    func playButtonTapActionHandler(sender: UIButton) {
        self.vrPlayer?.play()
    }

}

extension PlayerViewController {
    
    private func observeNotifcations() {
        let notificationCenter = NSNotificationCenter.defaultCenter()
        notificationCenter.addObserver(
            self,
            selector: #selector(PlayerViewController.applicationDidBecomeActiveNotificationHandler(_:)),
            name: UIApplicationDidBecomeActiveNotification,
            object: nil
        )
        notificationCenter.addObserver(
            self,
            selector: #selector(PlayerViewController.applicationWillResginActiveNotificationHandler(_:)),
            name: UIApplicationWillResignActiveNotification,
            object: nil
        )
    }
    
    private func unobserveNotifications() {
        let center = NSNotificationCenter.defaultCenter()
        center.removeObserver(self, name: UIApplicationDidBecomeActiveNotification, object: nil)
        center.removeObserver(self, name: UIApplicationWillResignActiveNotification, object: nil)
    }

    func notificationHandler(notification: NSNotification) {

    }
    
    func applicationDidBecomeActiveNotificationHandler(notification: NSNotification) {
        guard UIApplication.sharedApplication().applicationState != UIApplicationState.Background else {
            return
        }
        self.vrPlayer?.play()
    }
    
    func applicationWillResginActiveNotificationHandler(notification: NSNotification) {
        UIApplication.sharedApplication().idleTimerDisabled = false
        self.vrPlayer?.pause()
    }
    
}
