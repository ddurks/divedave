//
//  DiveScene.swift
//  divedave iOS
//
//  Created by David Durkin on 10/29/24.
//

import SpriteKit

struct PhysicsCategory {
    static let dave: UInt32 = 0x1 << 0
    static let springboard: UInt32 = 0x1 << 1
}

struct DiveStats {
    var height: Double = 0.0
    var angle: Double = 0.0
    var tucked: Bool = false
    var tuckCount: Int = 0
    var rotations: Double = 0.0
    var scores: [Int] = [0, 0, 0]
}

var stats = DiveStats()

class DiveScene: SKScene, SKPhysicsContactDelegate {
    private var readyForReset = false
    var controls: Controls!
    var waterLevel: CGFloat = 0
    var jumping = false
    var diveComplete = false
    var landedAt: Date? = nil
    var jumpReleasedAt: Date? = nil
    var boost: CGFloat = 0
    var currentVelocity: CGFloat = MIN_SPIN_VELOCITY
    var tucked = false
    var tuckCount = 0
    var sumRotation = 0.0
    var totalRotations = 0.0
    var streak = 0
    var totalScore = 0
    var sceneHeight: CGFloat! = HEIGHT
    var runningStreakLabel: SKLabelNode!
    var runningScoreLabel: SKLabelNode!
    var highScoreLabel: SKLabelNode!
    var springboard: AnimatedSprite!
    var dave: AnimatedSprite!
    var water: AnimatedSprite!
    var platformTop: SKSpriteNode!
    var highScoreSession = false
    
    override func didMove(to view: SKView) {
        physicsWorld.gravity = CGVector(dx: 0, dy: -GRAVITY)
        physicsWorld.contactDelegate = self
        self.backgroundColor = SKColor(red: 0.74, green: 0.84, blue: 1.0, alpha: 1.0)
        diveComplete = false
        sceneHeight = HEIGHT
        setupScene()
        setupCamera()
        setupControls(view: view, camera: self.camera!)
        setupSpringboard()
        setupHeightLabels()
        setupDave()
    }
    
    func setupControls(view: SKView, camera: SKCameraNode) {
        NSLog("self.size: \(self.size)")
        controls = Controls(camera: camera, sceneSize: self.size, scaleFactorHeight: scaleFactorHeight)
    }

    func setupScene() {
        // Set up the world bounds
        let offset = 100.0
        self.physicsBody = SKPhysicsBody(edgeLoopFrom: CGRect(x: 0, y: -offset, width: WIDTH, height: sceneHeight + offset))
        self.physicsBody?.restitution = 0.0
        
        setupLandscapeAndPool()
        
        // Water level and height labels
        waterLevel = ((256 * scaleFactorHeight)/2) + 1
        
        // Platform sections, scaled and adjusted to fit SpriteKit’s y-axis
        let platformTopPosition = CGPoint(x: 205 * scaleFactorWidth, y: waterLevel + 210)
        platformTop = SKSpriteNode(imageNamed: "platformtop")
        platformTop.position = platformTopPosition
        platformTop.zPosition = 10
        platformTop.setScale(scaleFactorHeight)
        addChild(platformTop)

        for i in stride(from: platformTop.position.y - platformTop.size.height, to: 200 * scaleFactorHeight, by: -100 * scaleFactorHeight) {
            let platformSection = SKSpriteNode(imageNamed: "platformsection")
            platformSection.position = CGPoint(x: platformTopPosition.x, y: i)
            platformSection.zPosition = 9
            platformSection.setScale(scaleFactorHeight)
            addChild(platformSection)
        }
        
        let platformBase = SKSpriteNode(imageNamed: "platformbase")
        platformBase.position = CGPoint(x: platformTopPosition.x, y: 200 * scaleFactorHeight)
        platformBase.zPosition = 10
        platformBase.setScale(scaleFactorHeight)
        addChild(platformBase)
        
        // Running streak and score labels, scaled
        runningStreakLabel = createLabel(text: "streak: 0", fontSize: 30 * scaleFactorHeight, position: CGPoint(x: 125 * scaleFactorHeight, y: sceneHeight - (135 * scaleFactorHeight)), zPosition: 15)
        runningScoreLabel = createLabel(text: "score: 0", fontSize: 30 * scaleFactorHeight, position: CGPoint(x: 125 * scaleFactorHeight, y: sceneHeight - (75 * scaleFactorHeight)), zPosition: 15)
        runningStreakLabel.isHidden = true
        runningScoreLabel.isHidden = true
        
        // High score label
        highScoreLabel = createLabel(text: "NEW HIGH SCORE!", fontSize: 50 * scaleFactorHeight, position: CGPoint(x: WIDTH / 2, y: sceneHeight - (150 * scaleFactorHeight)), zPosition: 24, fontColor: .green)
        highScoreLabel.isHidden = true
        
        physicsWorld.contactDelegate = self
    }
        
    func setupCamera() {
        let cameraNode = SKCameraNode()
        self.camera = cameraNode
        addChild(cameraNode)
    }
    
    func setupHeightLabels() {
        // Calculate height labels from water level to springboard position
        NSLog("water level: \(waterLevel)")
        var heightFromWater = waterLevel
        let majorSpacing = Int(200 * scaleFactorHeight)
        let minorSpacing = Int(20 * scaleFactorHeight)
        for y in stride(from: Int(heightFromWater + 1), to: Int(springboard.position.y), by: 1) {
            let currHeight = heightFromWater / 2 / 100
            
            // Set label color based on height
            var labelColor: SKColor = .red
            if currHeight < 25 {
                labelColor = .yellow
            }
            if currHeight < 10 {
                labelColor = .black
            }
            
            let labelPosition = CGPoint(x: WIDTH - 50, y: CGFloat(y))
            let formattedHeight = String(Int(currHeight / scaleFactorHeight))
            
            if Int(heightFromWater) % majorSpacing == 0 {
                let label = createLabel(text: "-- \(formattedHeight)m", fontSize: 24, position: labelPosition, zPosition: 20, fontColor: labelColor)
                label.isHidden = false
            } else if Int(heightFromWater) % minorSpacing == 0 {
                let marker = createLabel(text: "-", fontSize: 26, position: labelPosition, zPosition: 20, fontColor: labelColor)
                marker.isHidden = false
            }
            heightFromWater += 1
        }
    }
        
    func createLabel(text: String, fontSize: CGFloat, position: CGPoint, zPosition: CGFloat, fontColor: SKColor = .white) -> SKLabelNode {
        let label = SKLabelNode(text: text)
        label.fontSize = fontSize
        label.position = position
        label.zPosition = zPosition
        label.fontColor = fontColor
        addChild(label)
        return label
    }

    
    func restartScene() {
        // Restart the scene
        let newScene = DiveScene(size: self.size)
        newScene.scaleMode = self.scaleMode
        self.view?.presentScene(newScene, transition: SKTransition.fade(withDuration: 0.5))
    }
    
    func setupDave() {
        // Initialize dave as an AnimatedSprite with the spritesheet, frame size, and scaling factor
        dave = AnimatedSprite(spritesheetName: "divedave-spritesheet-extruded",
                              frameWidth: DEFAULT_DAVE_HEIGHT,
                              frameHeight: DEFAULT_DAVE_HEIGHT,
                              margin: 1,
                              spacing: 2,
                              scale: scaleFactorHeight)
        
        // Position and layer `dave`
        dave.position = CGPoint(x: WIDTH / 4, y: springboard.position.y + 100)
        dave.zPosition = 12
        
        // Add physics body to `dave`
        dave.physicsBody = SKPhysicsBody(rectangleOf: CGSize(width: 64 * scaleFactorWidth, height: 256 * scaleFactorHeight))
        dave.physicsBody?.isDynamic = true
        dave.physicsBody?.mass = DAVE_MASS
        dave.physicsBody?.affectedByGravity = true          // Enable gravity
//        dave.physicsBody?.linearDamping = DRAG              // Equivalent to setDrag
        dave.physicsBody?.angularDamping = ANGULAR_DRAG     // Equivalent to setAngularDrag
        dave.physicsBody?.restitution = 0.0                 // Prevent bouncing
        dave.physicsBody?.friction = 0.0                    // Prevent friction against surfaces
        
        dave.physicsBody?.categoryBitMask = PhysicsCategory.dave
        dave.physicsBody?.contactTestBitMask = PhysicsCategory.springboard
        dave.physicsBody?.collisionBitMask = PhysicsCategory.springboard
        
        // Add `dave` to the scene
        addChild(dave)
        
        // Define animations for `dave`
        dave.defineAnimation(name: "idle", frameIndices: [18, 18, 18, 18, 18, 19, 20, 21], timePerFrame: 0.125)
        dave.defineAnimation(name: "walkRight", frameIndices: [2, 3, 2, 4], timePerFrame: 0.166)
        dave.defineAnimation(name: "walkLeft", frameIndices: [11, 12, 11, 13], timePerFrame: 0.166)
        dave.defineAnimation(name: "jump", frameIndices: [5, 5, 6], timePerFrame: 0.083, repeatForever: false)
    }
    
    func setupSpringboard() {
        // Initialize the AnimatedSprite for the springboard
        springboard = AnimatedSprite(spritesheetName: "board", frameWidth: 440, frameHeight: 64, scale: scaleFactorHeight)
        springboard.position = CGPoint(x: platformTop.position.x + platformTop.size.width / 3, y: platformTop.position.y)
        springboard.zPosition = 11
        
        // Define animations if needed (e.g., "bounce" or other)
        springboard.defineAnimation(name: "flex", frameIndices: [0, 1, 0], timePerFrame: 0.25)

        // Add physics body to springboard
        springboard.physicsBody = SKPhysicsBody(rectangleOf: CGSize(width: springboard.size.width, height: springboard.size.height))
        springboard.physicsBody?.isDynamic = false
        springboard.physicsBody?.affectedByGravity = false
        springboard.physicsBody?.restitution = 0.0
        springboard.physicsBody?.friction = 0.0
        springboard.physicsBody?.categoryBitMask = PhysicsCategory.springboard

        addChild(springboard)
    }
    
    public func didBegin(_ contact: SKPhysicsContact) {
        let bodies = (contact.bodyA.categoryBitMask, contact.bodyB.categoryBitMask)
        
        // Check if the contact is between `dave` and `springboard`
        if (bodies == (PhysicsCategory.dave, PhysicsCategory.springboard)) ||
           (bodies == (PhysicsCategory.springboard, PhysicsCategory.dave)) {
            
            if landedAt == nil {
                landedAt = Date()
                dave.playAnimation(name: "idle")
                NSLog("LANDED AT \(landedAt)")
            }
        }
    }
    
    func setupLandscapeAndPool() {
        // Landscape background image scaled and positioned
        let landscape = SKSpriteNode(imageNamed: "landscape")
        let aspectRatio = landscape.size.width / landscape.size.height
        
        // Scale landscape width to match viewport and adjust height based on aspect ratio
        landscape.size = CGSize(width: WIDTH, height: WIDTH / aspectRatio)
        landscape.position = CGPoint(x: WIDTH / 2, y: landscape.size.height / 2)
        addChild(landscape)
        
        water = AnimatedSprite(
            spritesheetName: "water",
            frameWidth: 1250,
            frameHeight: 200,
            margin: 0,
            spacing: 0,
            scale: 1.0
        )

        water.defineAnimation(name: "idle", frameIndices: [0, 1, 2, 3], timePerFrame: 0.25)

        let waterAspectRatio = water.size.width / water.size.height
        water.size = CGSize(width: WIDTH, height: WIDTH / waterAspectRatio)
        water.position = CGPoint(x: WIDTH / 2, y: water.size.height / 2)
        water.zPosition = 15
        addChild(water)
        water.playAnimation(name: "idle", timePerFrame: 0.25)
    }

    
    func daveIsAboveBoard(tolerance: CGFloat = 1.0) -> Bool {
        guard let dave = dave else { return false }
        
        // Calculate and log intermediate values for debugging
        let daveRightEdge = dave.position.x + dave.size.width / 4
        let daveLeftEdge = dave.position.x - dave.size.width / 4
        let springboardRightEdge = springboard.position.x + springboard.size.width / 2 - 10
        let daveBottomEdge = dave.position.y - dave.size.height / 2
        let springboardTopEdge = springboard.position.y + springboard.size.height / 2
        
        // Check if dave is above the springboard
        let result = (daveRightEdge > 0 && daveLeftEdge < springboardRightEdge) && (daveBottomEdge >= springboardTopEdge - tolerance)
        
        if result && sumRotation != 0 {
            sumRotation = 0
            totalRotations = 0
        }
                
        return result
    }


    func daveIsTouchingBoard() -> Bool {
        guard let dave = dave else { return false }
        
        // Calculate the bottom of dave and the top of the springboard
        let daveBottom = dave.position.y - dave.size.height / 2
        let springboardTop = springboard.position.y + springboard.size.height / 2
        
        // Check if dave's bottom is close enough to the springboard’s top (with a small tolerance)
        let isVerticallyTouching = abs(daveBottom - springboardTop) <= 1  // 1-point tolerance
        
        // Log results for debugging
//        NSLog("daveIsTouchingBoard: \(isVerticallyTouching), daveBottom: \(daveBottom), springboardTop: \(springboardTop)")
        
        return isVerticallyTouching
    }

    func daveIsTucked() -> Bool {
        if tucked {
            dave?.texture = dave.frames[7]
        }
        return dave?.texture == dave.frames[7] || tucked
    }

    func daveJump() {
        guard !jumping else { return }
        if (dave.currentAnimation != "jump") {
            springboard.playAnimation(name: "flex", timePerFrame: 0.25, repeatForever: false) {
                self.springboard.currentAnimation = nil
            }
            jumpReleasedAt = Date()
            jumping = true
            dave.playAnimation(name: "jump", timePerFrame: 0.1, repeatForever: false) { [weak self] in
                guard let self = self else { return }
                
                jumping = false
                calculateBoost()
                landedAt = nil
                
                dave.physicsBody?.velocity.dy = JUMP_VELOCITY + boost;
            }
        }
    }
    
    func calculateBoost() {
//        NSLog("Calculating Boost")
        // Calculate the time difference between landing and jump release
        let quickness = diff(landedAt, jumpReleasedAt)
        
        // Determine the boost based on the quickness of the jump release
        if quickness < 125 {
            boost = MAX_BOOST
        } else if quickness < 250 {
            boost = MAX_BOOST - 50
        } else if quickness < 350 {
            boost = MAX_BOOST - 100
        } else {
            boost = 0
        }
        
        // Calculate the horizontal distance between Dave and the springboard's center
        let daveBoardDist = dave.position.x - (springboard.position.x - springboard.size.width / 2)
        if daveBoardDist > 0 {
            // Calculate the boost reduction based on Dave's distance from the board
            var newRatio = daveBoardDist / springboard.size.width
            newRatio = min(newRatio, 1) // Clamp to a maximum of 1
            boost *= newRatio
        }
    }
    
    func diff(_ start: Date?, _ end: Date?) -> Double {
        guard let start = start, let end = end else { return Double.greatestFiniteMagnitude }
        return end.timeIntervalSince(start) * 1000 // Convert seconds to milliseconds
    }

    
    func playerHandler() {
        guard let dave = dave else { return }

        applyCustomDamping()
        checkForReset()
        if !jumping {
            playerMobileMovementHandler()
            playerFrameHandler()
        }
    }
    
    func applyCustomDamping() {
        guard let dave = dave else { return }

        guard let physicsBody = dave.physicsBody else { return }
        
        // Apply damping only to the x component of the velocity
        let newVelocityX = physicsBody.velocity.dx * DRAG
        physicsBody.velocity = CGVector(dx: newVelocityX, dy: physicsBody.velocity.dy)
    }

    
    func playerFrameHandler() {
        guard let dave = dave else { return }
        if !jumping {
            if daveIsAboveBoard() {
                if dave.zRotation != 0 {
                    dave.zRotation = 0
                }
                if daveIsTouchingBoard() {
                    if let velocity = dave.physicsBody?.velocity.dx, velocity > (DAVE_SPEED/10) {
                        dave.playAnimation(name: "walkRight")
                    } else if let velocity = dave.physicsBody?.velocity.dx, velocity < -(DAVE_SPEED/10) {
                        dave.playAnimation(name: "walkLeft")
                    } else {
                        dave.playAnimation(name: "idle")
                    }
                } else {
                    dave.stopAnimation()
                    if ((dave.physicsBody?.velocity.dy)! > 0) {
                        if ((dave.physicsBody?.velocity.dx)! < 0) {
                            dave.texture =  dave.frames[15]
                        } else {
                            dave.texture =  dave.frames[6]
                        }
                    } else {
                        if ((dave.physicsBody?.velocity.dx)! < 0) {
                            dave.texture =  dave.frames[11]
                        } else {
                            dave.texture =  dave.frames[2]
                        }
                    }
                }
            } else if !tucked {
                dave.texture = dave.zRotation >= -CGFloat.pi / 2 && dave.zRotation <= CGFloat.pi / 2 ? dave.frames[6] : dave.frames[8]
                dave.currentAnimation = nil
            }
        }
    }
    
    func playerMobileMovementHandler() {
        if !diveComplete {
            if daveIsAboveBoard() {
                controls?.jumpControls()
            } else {
                controls?.flipControls()
            }
        }
        
        // Check mobile control button states and handle movement
        if controls?.leftButton.isDown == true || controls?.rightButton.isDown == true ||
           controls?.jumpButton.isDown == true || controls?.flipButton.isDown == true {
            
            if diveComplete {
                NSLog("DIVE COMPLETE") // Implement this to reset the scene
            } else {
                if controls?.leftButton.isDown == true {
                    dave.physicsBody?.velocity.dx = -DAVE_SPEED
                    
                }
                if controls?.rightButton.isDown == true {
                    dave.physicsBody?.velocity.dx = DAVE_SPEED
                }
                if daveIsAboveBoard() {
                    if controls?.jumpButton.isDown == true && daveIsTouchingBoard() {
                        NSLog("JUMP!!")
                        daveJump()
                    }
                } else if controls?.flipButton.isDown == true {
                    if !daveIsTucked() {
                        tucked = true
                        tuckCount += 1
                    } else {
                        if currentVelocity < MAX_SPIN_VELOCITY - (MAX_SPIN_VELOCITY/2) {
                            currentVelocity += (MAX_SPIN_VELOCITY/100)
                        } else if currentVelocity < MAX_SPIN_VELOCITY {
                            currentVelocity += (MIN_SPIN_VELOCITY/100)
                        }
                    }
                    dave.physicsBody?.angularVelocity = -currentVelocity
                }
            }
        } else {
            tucked = false
            currentVelocity = MIN_SPIN_VELOCITY
        }
    }
    
    func checkForReset() {
        // Ensure dive is not already marked as complete
        if !diveComplete && !daveIsAboveBoard() {
            // Check if Dave has reached the water level
            if dave.position.y < waterLevel {
                diveComplete = true
                
                // Calculate height, angle, and other stats
                let heightFromWater = springboard.position.y
                stats.height = round((heightFromWater / 2 / 100) * 10) / 10
                stats.angle = round(dave.zRotation * 10.0) / 10
                stats.tucked = daveIsTucked()
                stats.tuckCount = tuckCount
                stats.rotations = round(totalRotations * 10) / 10
                
                NSLog("stats: \(stats)")
                
                // Hide mobile controls
                controls.setVisible(false)
                
                // Set a delay to allow for scene reset readiness
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                    self.readyForReset = true
                    self.restartScene()
                }
            }
            
            // Track rotations while in the air
            countRotations()
        }
    }
    
    var previousAngle: CGFloat = 0
    var currentAngle: CGFloat = 0
    var lastFlipNumber: Double = 0
    var goalRotations: Int = 3 // Adjust this to set the goal for rotations
    func countRotations() {
        // Normalize Dave's rotation within [0, 2 * PI]
        let daveRotation = (dave.zRotation.truncatingRemainder(dividingBy: 2 * .pi) + 2 * .pi).truncatingRemainder(dividingBy: 2 * .pi)
        
        if daveRotation != currentAngle {
            // Calculate the angle difference
            var angleDiff = abs(previousAngle - currentAngle)
            
            // Handle large angle jumps due to wrapping from 0 to 2π or vice versa
            if angleDiff > 5 {
                if daveRotation < 1 {
                    previousAngle = 0
                } else if daveRotation > 5 {
                    previousAngle = 2 * .pi
                }
                angleDiff = abs(previousAngle - currentAngle)
            }
            
            // Accumulate rotation and update total rotations
            sumRotation += angleDiff
            totalRotations = sumRotation / (2 * .pi)
            
            // Update angles for next calculation
            previousAngle = currentAngle
            currentAngle = daveRotation
            
            // Check for completed rotations and display rotation count
            if totalRotations > lastFlipNumber {
                let rotationDifference = totalRotations - lastFlipNumber
                if rotationDifference >= 1 {
                    let roundedRotations = round(totalRotations)
                    
                    // Display rotation count near `dave`'s position
                    let rotationLabel = createRotationLabel(text: "\(Int(roundedRotations))", fontColor: roundedRotations > Double(goalRotations) ? .red : .green)
                    rotationLabel.position = dave.position
                    rotationLabel.zPosition = 14
                    addChild(rotationLabel)
                    
                    // Update the last counted flip number
                    lastFlipNumber = roundedRotations
                }
            }
        }
    }

    func createRotationLabel(text: String, fontColor: SKColor) -> SKLabelNode {
        let label = SKLabelNode(text: text)
        label.fontName = "Arial"
        label.fontSize = 50
        label.fontColor = fontColor
        return label
    }

    
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {

    }
    
    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {

    }
    
    override func update(_ currentTime: TimeInterval) {
        playerHandler()
        updateCamera()
    }

    func updateCamera() {
        guard let camera = self.camera, let davePosition = dave?.position else { return }

        // Calculate the desired camera y-position to follow dave
        var targetY = davePosition.y

        // Clamp the camera y-position between (0 + HEIGHT / 2) and (sceneHeight - HEIGHT / 2)
        let minY = HEIGHT / 2
        let maxY = sceneHeight - HEIGHT / 2
        targetY = max(minY, min(targetY, maxY))

        // Set the camera position to the clamped y-coordinate, centered horizontally
        camera.position = CGPoint(x: WIDTH / 2, y: targetY)
    }
}
