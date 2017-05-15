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

private class VRVideoNode: SKVideoNode {
    
    private var pasueLocked: Bool = false
    
    private override var paused: Bool {
        get {
            return super.paused
        }
        set(newValue) {
            if pasueLocked == false {
                super.paused = newValue
                pasueLocked = true
            }
        }
    }
    
    private override func play() {
        super.play()
        self.pasueLocked = false
        self.paused = false
    }
    
    private override func pause() {
        super.pause()
        self.pasueLocked = false
        self.paused = true
    }
    
}

public class VRVideoPlayerView: UIView {
    
    private weak var sceneView: SCNView?
    
    private weak var videoSKNode: VRVideoNode?
    
    private weak var videoNode: SCNNode?
    private weak var cameraNode: SCNNode?
    private weak var cameraPitchNode: SCNNode?
    private weak var cameraRollNode: SCNNode?
    private weak var cameraYawNode: SCNNode?
    
    private var isPaning: Bool = false
    private var firstFocusing: Bool = false
    
    public var panGestureRecognizer: UIPanGestureRecognizer? {
        willSet(newValue) {
            if let currentGR = self.panGestureRecognizer {
                self.removeGestureRecognizer(currentGR)
            }
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
    
    public var panSensitiveness: Float = 150
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
        
        switch UIApplication.sharedApplication().statusBarOrientation {
        case .Portrait:
            cameraNodeAngleY = Float(-M_PI_2)
            
        case .PortraitUpsideDown:
            cameraNodeAngleY = Float(M_PI_2)
            
        case .LandscapeRight:
            cameraNodeAngleZ = Float(M_PI)
            
        case .LandscapeLeft:
            cameraNodeAngleZ = Float(-M_PI)
            
        default:
            break
        }
        
        return SCNVector3(x: cameraNodeAngleX, y: cameraNodeAngleY, z: cameraNodeAngleZ)
    }
    private var currentCameraAngle: (pitch: Float, yaw: Float, roll: Float) = (0, 0, 0)
    private var currentAttitudeAngle: (pitch: Float, yaw: Float, roll: Float) = (1.5, 0, 0)
    
    public var pasued: Bool {
        if let pasued = self.videoSKNode?.paused {
            return pasued
        }
        return true
    }
    
    public init(AVPlayer player: AVPlayer) {
        super.init(frame: CGRect(x: 0, y: 0, width: 1, height: 1))
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
        self.unobserveNotifications()
        self.videoSKNode?.removeFromParent()
        self.videoNode?.geometry?.firstMaterial?.diffuse.contents = nil
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
        
        let cameraPitchNode = SCNNode()
        cameraPitchNode.addChildNode(cameraNode)
        
        let cameraRollNode = SCNNode()
        cameraRollNode.addChildNode(cameraPitchNode)
        
        let cameraYawNode = SCNNode()
        cameraYawNode.addChildNode(cameraRollNode)
        
        self.cameraPitchNode = cameraPitchNode
        self.cameraRollNode = cameraRollNode
        self.cameraYawNode = cameraYawNode
        
        self.cameraPitchNode?.eulerAngles.x = 1.5
        self.cameraYawNode?.eulerAngles.y = 1.5
        
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
        
        let videoSKNode = VRVideoNode(AVPlayer: player)
        videoSKNode.position = CGPoint(x: spriteKitScene.size.width / 2.0, y: spriteKitScene.size.height / 2.0)
        videoSKNode.size = spriteKitScene.size
        self.videoSKNode = videoSKNode
        
        spriteKitScene.addChild(videoSKNode)
        
        let videoNode = SCNNode()
        let sphere = SCNSphere(radius: 50)
        sphere.segmentCount = 78
        videoNode.geometry = sphere
        videoNode.geometry?.firstMaterial?.diffuse.contents = spriteKitScene
        videoNode.geometry?.firstMaterial?.doubleSided = true
        
        var transform = SCNMatrix4MakeRotation(Float(M_PI), 0, 0, 1)
        transform = SCNMatrix4Translate(transform, 1, 1, 0)
        
        videoNode.pivot = SCNMatrix4MakeRotation(Float(M_PI_2), 0, -1, 0)
        videoNode.geometry?.firstMaterial?.diffuse.contentsTransform = transform
        videoNode.position = SCNVector3(x: 0, y: 0, z: 0)
        videoNode.rotation = SCNVector4Make(1, 1, 1, 0)
        self.sceneView?.scene?.rootNode.addChildNode(videoNode)
        self.videoNode = videoNode
    }
    
}

//MARK: SceneRenderer Delegate
extension VRVideoPlayerView: SCNSceneRendererDelegate {
    
    public func renderer(renderer: SCNSceneRenderer, updateAtTime time: NSTimeInterval) {
        if self.isPaning == false {
            dispatch_async(dispatch_get_main_queue()) {
                if let currentAttitude = self.motionManager.deviceMotion?.attitude {
                    let roll: Float = {
                        if UIApplication.sharedApplication().statusBarOrientation == .LandscapeRight {
                            return -1.0 * Float(-M_PI - currentAttitude.roll)
                        } else {
                            return Float(currentAttitude.roll)
                        }
                    }()
                    
                    //because of landscape
                    self.currentAttitudeAngle.pitch = roll
                    self.currentAttitudeAngle.yaw = Float(currentAttitude.yaw)
                    self.currentAttitudeAngle.roll = Float(currentAttitude.pitch)
                    
                    if self.firstFocusing == false {
                        self.currentCameraAngle.pitch = (self.currentAttitudeAngle.pitch - 1.5) * self.panSensitiveness
                        self.currentCameraAngle.yaw = (self.currentAttitudeAngle.yaw - 1.5) * self.panSensitiveness
                        self.firstFocusing = true
                    }
                    
                    self.cameraPitchNode?.eulerAngles.x = (self.currentAttitudeAngle.pitch
                        - self.currentCameraAngle.pitch / self.panSensitiveness)
                    self.cameraYawNode?.eulerAngles.y = (self.currentAttitudeAngle.yaw
                        - self.currentCameraAngle.yaw / self.panSensitiveness)
                    self.cameraRollNode?.eulerAngles.z = self.currentAttitudeAngle.roll
                }
            }
        }
    }
    
}

//MARK: GestureRecognizer Handler
extension VRVideoPlayerView: UIGestureRecognizerDelegate {
    
    public override func gestureRecognizerShouldBegin(gestureRecognizer: UIGestureRecognizer) -> Bool {
        return self.panEnable
    }
    
    public func panGestureRecognizerHandler(panGR: UIPanGestureRecognizer) {
        if let panView = panGR.view {
            let translation = panGR.translationInView(panView)
            
            
            var newAngleYaw: Float = {
                switch UIApplication.sharedApplication().statusBarOrientation {
                case .Portrait:
                    return Float(translation.y)
                    
                case .PortraitUpsideDown:
                    return Float(-translation.y)
                    
                case .LandscapeRight:
                    return Float(translation.x)
                    
                case .LandscapeLeft:
                    return Float(-translation.x)
                    
                default:
                    return Float(translation.x)
                }
            }()
            var newAnglePitch: Float = {
                switch UIApplication.sharedApplication().statusBarOrientation {
                case .Portrait:
                    return Float(translation.x)
                    
                case .PortraitUpsideDown:
                    return Float(-translation.x)
                    
                case .LandscapeRight:
                    return Float(translation.y)
                    
                case .LandscapeLeft:
                    return Float(-translation.y)
                    
                default:
                    return Float(translation.y)
                }
            }()
            
            //current angle is an instance variable so i am adding the newAngle to it
            newAnglePitch += self.currentCameraAngle.pitch
            newAngleYaw += self.currentCameraAngle.yaw
            
            self.cameraPitchNode?.eulerAngles.x = self.currentAttitudeAngle.pitch - newAnglePitch / self.panSensitiveness
            self.cameraYawNode?.eulerAngles.y = self.currentAttitudeAngle.yaw - newAngleYaw / self.panSensitiveness
            
            switch panGR.state {
            case .Began:
                self.isPaning = true
                
            case .Cancelled, .Ended, .Failed:
                self.isPaning = false
                currentCameraAngle.pitch = newAnglePitch
                currentCameraAngle.yaw = newAngleYaw
                
            default:
                break
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
    
    func focuseCenter() {
        self.currentCameraAngle.pitch = (self.currentAttitudeAngle.pitch - 1.5) * self.panSensitiveness
        self.currentCameraAngle.yaw = (self.currentAttitudeAngle.yaw - 1.5) * self.panSensitiveness
        
        self.cameraPitchNode?.eulerAngles.x = 1.5
        self.cameraYawNode?.eulerAngles.y = 1.5
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
        if UIApplication.sharedApplication().applicationState == .Active {
            self.cameraNode?.eulerAngles = self.cameraNodeAngle
        }
    }
    
}
