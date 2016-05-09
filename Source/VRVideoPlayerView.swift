//
//  VRVideoPlayerView.swift
//  ChameleonPlayer
//
//  Created by liuyan on 4/29/16.
//  Copyright © 2016 Eyepetizer Inc. All rights reserved.
//

import UIKit
import SceneKit
import SpriteKit
import AVFoundation
import CoreMotion

public class VRVideoPlayerView: UIView {
    
    private weak var sceneView: SCNView?
    
    private weak var videoSKNode: SKVideoNode?
    
    private weak var videoNode: SCNNode?
    private weak var cameraNode: SCNNode?
    private weak var cameraRollNode: SCNNode?
    private weak var cameraPitchNode: SCNNode?
    private weak var cameraYawNode: SCNNode?
    
    public var panGestureRecognizer: UIPanGestureRecognizer? {
        willSet(newValue) {
            if let panGR = newValue {
                panGR.removeTarget(nil, action: nil)
                panGR.addTarget(
                    self,
                    action: #selector(VRVideoPlayerView.panGestureRecognizerHandler(_:))
                )
                panGR.delegate = self
                self.addGestureRecognizer(panGR)
            }
        }
    }
    
    public var panSensitiveness: Float = 100
    public var panEnable: Bool = true
    public var motionEnable: Bool = true {
        didSet(oldValue) {
            guard self.superview != nil else {
                return
            }
            
            if self.motionEnable != oldValue {
                if self.motionEnable == true {
                    self.motionManager.startDeviceMotionUpdatesUsingReferenceFrame(.XArbitraryCorrectedZVertical)
                } else {
                    self.motionManager.stopDeviceMotionUpdates()
                }
            }
        }
    }
    
    private var motionManager: CMMotionManager = {
        let motionManager = CMMotionManager()
        motionManager.deviceMotionUpdateInterval = 1 / 60.0
        return motionManager
    }()
    
    private var cameraNodeAngle: SCNVector3 {
        let cameraNodeAngleX: Float = Float(-M_PI_2)
        var cameraNodeAngleY: Float = 0.0
        var cameraNodeAngleZ: Float = 0.0
        
        switch UIApplication.sharedApplication().statusBarOrientation.rawValue {
        case 1:
            cameraNodeAngleY = Float(-M_PI_2)
        case 2:
            cameraNodeAngleY = Float(M_PI_2)
        case 3:
            cameraNodeAngleZ = Float(M_PI)
        default:
            break
        }
        
        return SCNVector3(x: cameraNodeAngleX, y: cameraNodeAngleY, z: cameraNodeAngleZ)
    }
    private var currentCameraAngle: SCNVector3 = SCNVector3Zero
    
    public init(AVPlayer player: AVPlayer) {
        super.init(frame: CGRect(x: 0, y: 0, width: 1, height: 1))
        UIDeviceOrientationDidChangeNotification
        self.setupScene()
        self.setupVideoSceneWithAVPlayer(player)
        self.videoSKNode?.pause()
    }
    
    public required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    public override func didMoveToSuperview() {
        super.didMoveToSuperview()
        self.cameraNode?.eulerAngles = self.cameraNodeAngle
        self.observeNotifications()
        if self.motionEnable {
            self.motionManager.startDeviceMotionUpdatesUsingReferenceFrame(.XArbitraryCorrectedZVertical)
        }
    }
    
    public override func willMoveToSuperview(newSuperview: UIView?) {
        super.willMoveToSuperview(newSuperview)
        if newSuperview == nil {
            self.unobserveNotifications()
            self.motionManager.stopDeviceMotionUpdates()
        }
    }
    
    deinit {
        if let rootNode = self.sceneView?.scene?.rootNode {
            func removeChildNodesInNode(node: SCNNode) {
                for node in node.childNodes {
                    removeChildNodesInNode(node)
                }
            }
            removeChildNodesInNode(rootNode)
        }
    }
    
}

//MARK: Setup
private extension VRVideoPlayerView {
    
    func setupScene() {
        // Create Scene View
        let sceneView = SCNView(frame: self.bounds)
        sceneView.autoresizingMask = [.FlexibleWidth, .FlexibleHeight]
        sceneView.backgroundColor = UIColor.blackColor()
        self.sceneView = sceneView
        self.addSubview(sceneView)
        
        // Create Scene
        let scene = SCNScene()
        sceneView.scene = scene
        
        // Create Cameras
        let camera = SCNCamera()
        camera.zFar = 50.0
        
        let cameraNode = SCNNode()
        cameraNode.camera = camera
        cameraNode.position = SCNVector3Zero
        self.cameraNode = cameraNode
        
        let cameraRollNode = SCNNode()
        cameraRollNode.addChildNode(cameraNode)
        
        let cameraPitchNode = SCNNode()
        cameraPitchNode.addChildNode(cameraRollNode)
        
        let cameraYawNode = SCNNode()
        cameraYawNode.addChildNode(cameraPitchNode)
        
        self.cameraRollNode = cameraRollNode
        self.cameraPitchNode = cameraPitchNode
        self.cameraYawNode = cameraYawNode
        
        sceneView.scene?.rootNode.addChildNode(cameraYawNode)
        sceneView.pointOfView = cameraNode
        
        sceneView.delegate = self
        sceneView.playing = true
        
        self.panGestureRecognizer = UIPanGestureRecognizer()
        self.userInteractionEnabled = true
    }
    
    func setupVideoSceneWithAVPlayer(player: AVPlayer) {
        let spriteKitScene = SKScene(size: CGSize(width: 2500, height: 2500))
        spriteKitScene.scaleMode = .AspectFit
        
        let videoSKNode = SKVideoNode(AVPlayer: player)
        videoSKNode.position = CGPoint(x: spriteKitScene.size.width / 2.0, y: spriteKitScene.size.height / 2.0)
        videoSKNode.size = spriteKitScene.size
        self.videoSKNode = videoSKNode
        
        spriteKitScene.addChild(videoSKNode)
        
        let videoNode = SCNNode()
        videoNode.geometry = SCNSphere(radius: 30)
        videoNode.geometry?.firstMaterial?.diffuse.contents = spriteKitScene
        videoNode.geometry?.firstMaterial?.doubleSided = true
        
        var transform = SCNMatrix4MakeRotation(Float(M_PI), 0, 0, 1)
        transform = SCNMatrix4Translate(transform, 1, 1, 0)
        
        videoNode.pivot = SCNMatrix4MakeRotation(Float(M_PI_2), 0, -1, 0)
        videoNode.geometry?.firstMaterial?.diffuse.contentsTransform = transform
        videoNode.position = SCNVector3(x: 0, y: 0, z: 0)
        self.sceneView?.scene?.rootNode.addChildNode(videoNode)
        self.videoNode = videoNode
    }
    
}

//MARK: SceneRenderer Delegate
extension VRVideoPlayerView: SCNSceneRendererDelegate {
    
    public func renderer(renderer: SCNSceneRenderer, updateAtTime time: NSTimeInterval) {
        dispatch_async(dispatch_get_main_queue()) {
            if let currentAttitude = self.motionManager.deviceMotion?.attitude {
                let roll: Float = {
                    if UIApplication.sharedApplication().statusBarOrientation == .LandscapeRight {
                        return -1.0 * Float(-M_PI - currentAttitude.roll)
                    } else {
                        return Float(currentAttitude.roll)
                    }
                }()
                self.cameraRollNode?.eulerAngles.x = roll
                self.cameraPitchNode?.eulerAngles.z = Float(currentAttitude.pitch)
                self.cameraYawNode?.eulerAngles.y = Float(currentAttitude.yaw)
            }
        }
    }
    
}

//MARK: GestureRecognizer Handler
extension VRVideoPlayerView: UIGestureRecognizerDelegate {
    
    public override func gestureRecognizerShouldBegin(gestureRecognizer: UIGestureRecognizer) -> Bool {
        return self.panEnable
    }
    
    func panGestureRecognizerHandler(panGR: UIPanGestureRecognizer) {
        if let panView = panGR.view {
            let translation = panGR.translationInView(panView)
            
            var newAngleX = Float(translation.x)
            var newAngleY = Float(translation.y)
            
            //current angle is an instance variable so i am adding the newAngle to it
            newAngleX += currentCameraAngle.x
            newAngleY += currentCameraAngle.y
            
            self.videoNode?.eulerAngles.y = -newAngleX / self.panSensitiveness
            self.videoNode?.eulerAngles.z = newAngleY / self.panSensitiveness
            
            if panGR.state == .Ended {
                currentCameraAngle.x = newAngleX
                currentCameraAngle.y = newAngleY
            }
        }
    }
    
}

//MARK: Player Control
public extension VRVideoPlayerView {
    
    func play() {
        videoSKNode?.play()
    }
    
    func pause() {
        videoSKNode?.pause()
    }
    
}

//MARK: Notification
extension VRVideoPlayerView {
    
    private func observeNotifications() {
        let notificationCenter = NSNotificationCenter.defaultCenter()
        notificationCenter.addObserver(
            self,
            selector: #selector(VRVideoPlayerView.applicationDidChangeStatusBarOrientationNotificationHandler(_:)),
            name: UIApplicationDidChangeStatusBarOrientationNotification,
            object: nil
        )
    }
    
    private func unobserveNotifications() {
        let notificationCenter = NSNotificationCenter.defaultCenter()
        notificationCenter.removeObserver(
            self,
            name: UIApplicationDidChangeStatusBarOrientationNotification,
            object: nil
        )
    }
    
    func applicationDidChangeStatusBarOrientationNotificationHandler(notification: NSNotification?) {
        self.cameraNode?.eulerAngles = self.cameraNodeAngle
    }
    
}
