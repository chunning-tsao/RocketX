//
//  GameViewController.swift
//  Asteroid_Test
//
//  Created by Willy on 2018/5/16.
//  Copyright © 2018年 Willy. All rights reserved.
//

import UIKit
import QuartzCore
import SceneKit
import CoreMotion
import ARKit

// setting the collision mask
enum CollisionMask: Int {
    case ship = 1
    case asteroid = 2
}

enum GameState: Int {
    case playing
    case dead
    case paused
}


class AsteroidGameViewController: UIViewController, SCNSceneRendererDelegate, SCNPhysicsContactDelegate {

    
    // MARK: Properties
    
    // object of other classes
    var objMotionControl = MotionControl()
    
    var gameScene: SCNScene!
    var cameraNode: SCNNode!
    var shipNode: SCNNode!
    var springNode: SCNNode!
    
    var startAsteroidCreation: Bool = false
    var asteroidCreationTiming: Double = 4
    var gameState: GameState = GameState.paused
    
    let horizontalBound: Float = 6 //was 7
    let upperBound: Float = 8 //was 8
    let lowerBound: Float = -8
    let edgeWidth: Float = 3
    
    
    
    @IBOutlet var gameView: SCNView!
    @IBOutlet weak var arView: ARSCNView!
    
    
    
    // MARK:
    override func viewDidLoad() {
        
        
        
        super.viewDidLoad()
        initGameView()
        initScene()
        initCamera()
        initShip()
        
        gameState = .playing
        
        objMotionControl.setDevicePitchOffset()
        
    }
    
    
    
    
    // MARK: functions
    
    func initGameView() {
        //gameView = self.view as! SCNView
        gameView.allowsCameraControl = false
        gameView.autoenablesDefaultLighting = true
        gameView.delegate = self
    }
    
    func initScene() {
        gameScene = SCNScene()
        gameView.scene = gameScene
        gameView.scene?.physicsWorld.gravity = SCNVector3(x: 0, y: 0, z: 0)
        gameView.scene?.physicsWorld.speed = 1
        gameScene.background.contents = UIColor.darkGray
        gameScene.physicsWorld.contactDelegate = self
        
    }
    
    func initCamera() {
        cameraNode = SCNNode()
        cameraNode.camera = SCNCamera()
        let cameraAngle: Float = 20
        let cameraDistance: Float = 10
        cameraNode.eulerAngles = SCNVector3(x: -.pi*cameraAngle/180, y: 0, z: 0)
        cameraNode.position = SCNVector3(x: 0, y: tan(.pi*cameraAngle/180)*cameraDistance + 1, z: cameraDistance)
        //cameraNode.position = SCNVector3(x: 0, y: 0, z: 10)
        gameScene.rootNode.addChildNode(cameraNode)
    }
    
    func initShip() {
        //set the ship
        let shipScene = SCNScene(named: "art.scnassets/retrorockett4k1t.dae")
        shipNode = shipScene?.rootNode
        shipNode.position = SCNVector3(x: 0, y: 0, z: 0)
        shipNode.scale = SCNVector3(x: 0.5, y: 0.5, z: 0.5)
        shipNode.eulerAngles = SCNVector3(x: -(Float.pi/2), y: 0, z: 0)
        // setting the physicsbody of the ship
        shipNode.physicsBody = SCNPhysicsBody(type: .dynamic, shape: nil)
        shipNode.physicsBody?.damping = 0.05
        shipNode.physicsBody?.angularDamping = 0.9
        shipNode.physicsBody?.categoryBitMask = CollisionMask.ship.rawValue
        shipNode.physicsBody?.contactTestBitMask = CollisionMask.asteroid.rawValue
        shipNode.name = "rocket"
        gameScene.rootNode.addChildNode(shipNode)
        
        
        
        //for debugging below
        print(gameState)
    }
    
    
    
    
    func createAsteroid() {
        // create the SCNGeometry
        let asteroidGeometry = SCNCapsule(capRadius: 2.5, height: 6)
        // create the SCNNode with SCNGeometry
        let asteroidNode = SCNNode(geometry: asteroidGeometry)
        
        //setting the asteroid spawn position
        let asteroidSpawnRange = 10.0
        let randomAsteroidPositionX = Float((drand48()-0.5)*asteroidSpawnRange)
        let randomAsteroidPositionY = Float((drand48()-0.5)*asteroidSpawnRange)
        asteroidNode.position = SCNVector3(x: randomAsteroidPositionX, y: randomAsteroidPositionY, z: -50)
        
        // put the asteroid into the rootNode
        asteroidNode.physicsBody = SCNPhysicsBody(type: .dynamic, shape: nil)
        asteroidNode.physicsBody?.categoryBitMask = CollisionMask.asteroid.rawValue
        asteroidNode.physicsBody?.damping = 0
        gameScene.rootNode.addChildNode(asteroidNode)
        
        //apllying forces and torques
        let asteroidInitialForce = SCNVector3(x: 0, y: 0, z: 10)
        asteroidNode.physicsBody?.applyForce(asteroidInitialForce, asImpulse: true)
        let randomAsteroidTorqueX = Float(drand48()-0.5)
        let randomAsteroidTorqueY = Float(drand48()-0.5)
        let randomAsteroidTorqueZ = Float(drand48()-0.5)
        asteroidNode.physicsBody?.applyTorque(SCNVector4(x: randomAsteroidTorqueX, y: randomAsteroidTorqueY, z: randomAsteroidTorqueZ, w: 5), asImpulse: true)
    }
    
    
    // remove the unseeable asteroid behind the camera
    func cleanUp() {
        for node in gameScene.rootNode.childNodes {
            if node.presentation.position.z > 50 {
                node.removeFromParentNode()
            }
        }
    }
    
    
    
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        // Create a session configuration
        guard ARFaceTrackingConfiguration.isSupported else { return }
        
        let configuration = ARFaceTrackingConfiguration()
        
        configuration.isLightEstimationEnabled = true
        configuration.worldAlignment = .camera
        
        // Run the view's session
        arView.session.run(configuration)
        gameScene.isPaused = false
        
        
        self.arView.debugOptions = [ARSCNDebugOptions.showWorldOrigin]
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        
        // Pause the view's session
        arView.session.pause()
        gameScene.isPaused = true
    }
    
    // MARK: SCNSceneRendererDeligate functions
    
    func renderer(_ renderer: SCNSceneRenderer, willUpdate node: SCNNode, for anchor: ARAnchor) {
            //Apply input from face camera to rocket
        gameView.scene?.rootNode.childNode(withName: "rocket", recursively: true)?.transform = node.transform

        //Some code that Junning might want to see, just for future reference
//        gameScene.rootNode.childNode(withName: "cube", recursively: true)?.transform = (gameView.pointOfView?.transform)!
//        gameScene.rootNode.childNode(withName: "cube", recursively: true)?.position = SCNVector3(x: 0, y: 0, z: 0)
//
    }
    
    
    func renderer(_ renderer: SCNSceneRenderer, updateAtTime time: TimeInterval) {
        
        
        
        // following part are controls for the ship, need to able to switch between iphoneX and others
        
        //read device motion (attitude)
        objMotionControl.updateDeviceMotionData()
        
        //set control of the ship
        
        
        var horizontalCentralForce: Float = 0
        var verticalCentralForce: Float = 0
        
        //edge assist
        if shipNode.presentation.position.x > (horizontalBound - edgeWidth) && (shipNode.physicsBody?.velocity.x)! > Float(0) {
            horizontalCentralForce = (shipNode.presentation.position.x - (horizontalBound - edgeWidth)) / edgeWidth * -6
        }
        else if shipNode.presentation.position.x < (-horizontalBound + edgeWidth) && (shipNode.physicsBody?.velocity.x)! < Float(0)  {
            horizontalCentralForce = (shipNode.presentation.position.x - (-horizontalBound + edgeWidth)) / edgeWidth * -6
        }
        else {
            horizontalCentralForce = 0
        }
        if shipNode.presentation.position.y > (upperBound - edgeWidth) && (shipNode.physicsBody?.velocity.y)! > Float(0) {
            verticalCentralForce = (shipNode.presentation.position.y - (upperBound - edgeWidth)) / edgeWidth * -10
        }
        else if shipNode.presentation.position.y < (lowerBound + edgeWidth) && (shipNode.physicsBody?.velocity.y)! < Float(0) {
            verticalCentralForce = (shipNode.presentation.position.y - (lowerBound + edgeWidth)) / edgeWidth * -10
        } else {
            verticalCentralForce = 0
        }
        
        
        
        var shipControlForce = SCNVector3(x: 0, y: 0, z: 0)
        
        // should see if the device is an iPhone X or not
        if UIDevice.current.model == "iPhone X"{
            //face control
            // replace the objMotionControl components (objMotionControl.roll and objMotionControl.pitch) with face orientation in degree, and remove the "objMotionControl.devicePitchOffset"
            shipControlForce = SCNVector3(x: Float(objMotionControl.roll*6.0) + horizontalCentralForce, y: Float(((objMotionControl.pitch)-objMotionControl.devicePitchOffset)*10.0) + verticalCentralForce, z: 0)
        }
        else {
            //device motion control
            shipControlForce = SCNVector3(x: Float(objMotionControl.roll*6.0) + horizontalCentralForce, y: Float(((objMotionControl.pitch)-objMotionControl.devicePitchOffset)*10.0) + verticalCentralForce, z: 0)
        }
        
//        shipNode.physicsBody?.applyForce(shipControlForce, asImpulse: false)
       
        shipNode.physicsBody?.applyForce(shipControlForce, at: SCNVector3(x: 0, y: 0, z: -1.5), asImpulse: false)
        let shipBow = shipNode.presentation.convertVector(SCNVector3(x: 0, y: 5, z: 0), to: nil)
        let shipStern = shipNode.presentation.convertVector(SCNVector3(x: 0, y: -5, z: 0), to: nil)
        shipNode.physicsBody?.applyForce(SCNVector3(x: 0, y: 0, z: -18), at: shipBow, asImpulse: false)
        shipNode.physicsBody?.applyForce(SCNVector3(x: 0, y: 0, z: 18), at: shipStern, asImpulse: false)
//        print(shipNode.presentation.rotation)


        //reset the ship after the ship died, should be removed after the interface is set
        if(gameState == GameState.dead) {
            for node in gameScene.rootNode.childNodes {
                node.removeFromParentNode()
                startAsteroidCreation = false
            }
            initShip()
            gameState = GameState.playing
        }
        
        //dead if ship is too far away
        
        if abs(shipNode.presentation.position.x) > horizontalBound || shipNode.presentation.position.y > upperBound || shipNode.presentation.position.y < lowerBound {
            gameState = .dead
        }
    
        
        
        //creating asteroids and cleaning up asteroids
        if time > asteroidCreationTiming {
            if startAsteroidCreation == true {
                createAsteroid()
                asteroidCreationTiming = time + 4
                cleanUp()
            } else {
                asteroidCreationTiming = time + 3
                startAsteroidCreation = true
            }
        }
    }
    
    
    
    
    // MARK: SCNPhysicsContactDelegate Functions
    func physicsWorld(_ world: SCNPhysicsWorld, didBegin contact: SCNPhysicsContact) {
//        gameScene.rootNode.childNode(withName: "ship", recursively: false)?.removeFromParentNode()
        gameState = GameState.dead
        print(gameState)
    }
    
    
    
    
    
    
    override var shouldAutorotate: Bool {
        return false
    }
    
    override var prefersStatusBarHidden: Bool {
        return true
    }
    
    override var supportedInterfaceOrientations: UIInterfaceOrientationMask {
        if UIDevice.current.userInterfaceIdiom == .phone {
            return .portrait
        } else {
            return .all
        }
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Release any cached data, images, etc that aren't in use.
    }

}
