//
//  DiveScene.swift
//  divedave iOS
//
//  Created by David Durkin on 10/29/24.
//

import SpriteKit
import os

private let logger = Logger(subsystem: "com.drawvid.divedave", category: "gameplay")

struct DiveStats {
    var height: Double = 0.0
    var angle: Double = 0.0
    var tucked: Bool = false
    var tuckCount: Int = 0
    var rotations: Double = 0.0
    var scores: [Int] = [0, 0, 0]
    var emotionFrame: Int = 2
}

var stats = DiveStats()

final class DiveScene: SKScene, SKPhysicsContactDelegate {
    private var readyForReset = false
    var hud: HUD!
    var waterLevel: CGFloat = 0
    var jumping = false
    var diveComplete = false
    var landedAt: Date? = nil
    var boost: CGFloat = 0
    var currentVelocity: CGFloat = Game.minSpinVelocity
    var tucked = false
    var tuckCount = 0
    var sumRotation = 0.0
    var totalRotations = 0.0
    var springboard: AnimatedSprite!
    var dave: AnimatedSprite!
    var water: AnimatedSprite!
    var splash: AnimatedSprite!
    var climbdave: AnimatedSprite!
    var gettingoutdave: AnimatedSprite!
    var platformTop: SKSpriteNode!
    var goalRotations: Double = 0.5
    var highScoreSession = false
    var info: InfoPanel!
    var highScorePanel: InfoPanel!
    var daveIsTouchingBoardBool: Bool! = false
    var lastUpdateTime: TimeInterval = 0.0
    private var atmosphere: Atmosphere!
    
    override func didMove(to view: SKView) {
        lastUpdateTime = CACurrentMediaTime()
        physicsWorld.gravity = CGVector(dx: 0, dy: -Game.gravity)
        physicsWorld.contactDelegate = self
        self.backgroundColor = SKColor(red: 0.74, green: 0.84, blue: 1.0, alpha: 1.0)
        diveComplete = false
        let buffer = HEIGHT/2
        if ((platformHeight * scaleFactorHeight) < HEIGHT - buffer) {
            sceneHeight = HEIGHT
        } else {
            sceneHeight = platformHeight + buffer
        }
        setupScene()
        setupCamera()
        setupHUD(view: view, camera: self.camera!)
        setupInfoPanels()
        setupSpringboard()
        setupHeightLabels()
        setupDave()
        setupSplash()
        calculateGameLogic()
        atmosphere = Atmosphere(scene: self, sceneHeight: sceneHeight, startY: gettingoutdave.size.height, middleY: HEIGHT * 2, endY: HEIGHT * 4)
    }
    
    func setupHUD(view: SKView, camera: SKCameraNode) {
        logger.debug("self.size: \(self.size.debugDescription)")
        hud = HUD(view: view, camera: camera, sceneSize: self.size, scaleFactorHeight: scaleFactorHeight)
        hud.onMenuPressed = self.prepareAndPresentMainMenuScene
    }
    
    func approximateFallTime(from height: CGFloat, to groundLevel: CGFloat, gravity: CGFloat, frameRate: Double = 60.0) -> Double {
        // Closed-form solution for free fall from rest: t = sqrt(2 * d / g)
        let distance = max(0, height - groundLevel)
        guard gravity > 0 else { return 0 }
        return sqrt(2 * Double(distance) / Double(gravity))
    }

    func calculateGameLogic() {
        let diveHeight = (platformHeight * scaleFactorHeight)
        let time = approximateFallTime(from: diveHeight, to: waterLevel, gravity: Game.gravity) / 10
        
        // Calculate maximum number of flips based on the total rotation in radians
        let totalRotation = time * (Game.maxSpinVelocity * 0.70)
        let maxFlips = totalRotation / (2 * Double.pi)
        
        // Generate a random goal rotation value in terms of half rotations
        let halfFlips = Int(maxFlips * 2)
        let randomHalfFlips = Double(Int.random(in: 1...halfFlips)) / 2.0
        
        // Set goal rotations to the selected half-flip value
        goalRotations = randomHalfFlips
        hud.setGoalFlips(flips: goalRotations)
        
        logger.debug("DiveHeight: \(diveHeight), Time (approximated): \(time), Total Rotation (radians): \(totalRotation), Max Flips: \(maxFlips), Half-Flips (integer): \(halfFlips), Random Half-Flips: \(randomHalfFlips), Goal Rotations: \(self.goalRotations)")
    }

    func setupScene() {
        setupLandscapeAndPool()
        
        // Water level and height labels
        waterLevel = ((256 * scaleFactorHeight)/2) + 1
        
        // Platform sections, scaled and adjusted to fit SpriteKit’s y-axis
        let platformTopPosition = CGPoint(x: WIDTH/7, y: waterLevel + (platformHeight * scaleFactorHeight))
        platformTop = SKSpriteNode(imageNamed: "platformtop")
        platformTop.position = platformTopPosition
        platformTop.zPosition = 9
        platformTop.setScale(scaleFactorHeight)
        addChild(platformTop)

        for i in stride(from: platformTop.position.y - platformTop.size.height, to: 200 * scaleFactorHeight, by: -100 * scaleFactorHeight) {
            let platformSection = SKSpriteNode(imageNamed: "platformsection")
            platformSection.position = CGPoint(x: platformTopPosition.x, y: i)
            platformSection.zPosition = 8
            platformSection.setScale(scaleFactorHeight)
            addChild(platformSection)
        }
        
        let platformBase = SKSpriteNode(imageNamed: "platformbase")
        platformBase.position = CGPoint(x: platformTopPosition.x, y: 200 * scaleFactorHeight)
        platformBase.zPosition = 9
        platformBase.setScale(scaleFactorHeight)
        addChild(platformBase)
        
        setupClimbDave(x: platformBase.position.x, y: platformBase.position.y)
        
        // Set up the world bounds
        let offset = 100.0
        self.physicsBody = SKPhysicsBody(edgeLoopFrom: CGRect(x: platformTop.position.x - (platformTop.size.width/2), y: -offset, width: WIDTH, height: sceneHeight + 2*offset))
        self.physicsBody?.restitution = 0.0
        physicsWorld.contactDelegate = self
    }
    
    func setupInfoPanels() {
        info = InfoPanel(scene: self, depth: 20);
        highScorePanel = InfoPanel(scene: self, depth: 24)
    }
        
    func setupCamera() {
        let cameraNode = SKCameraNode()
        self.camera = cameraNode
        addChild(cameraNode)
    }
    
    func setupHeightLabels() {
        logger.debug("water level: \(self.waterLevel)")
        
        var y = waterLevel
        var currentMeter = 1  // Start at 0 meters from the water level
        let majorSpacing = 200.0 * scaleFactorHeight
        let minorSpacing = 20.0 * scaleFactorHeight
        let maxY = springboard.position.y
        
        // Initialize counters for major and minor spacing
        var majorCounter = 0.0
        var minorCounter = 0.0

        // Loop until y reaches the springboard position
        while y < maxY {
            // Set label color based on height
            var labelColor: SKColor = Game.customRed
            if currentMeter < 25 {
                labelColor = Game.customYellow
            }
            if currentMeter < 10 {
                labelColor = Game.customGreen
            }
            
            let labelPosition = CGPoint(x: 5*WIDTH/6, y: CGFloat(y))
            let formattedHeight = String(currentMeter)

            // Check major spacing counter
            if majorCounter >= majorSpacing {
                let label = createLabel(text: "- \(formattedHeight)m", fontSize: 20, position: labelPosition, zPosition: 10, fontColor: labelColor, bold: true)
                label.isHidden = false
                addChild(label)
                majorCounter = 0.0  // Reset major counter
                currentMeter += 1   // Increment the meter label by 1
            }
            // Check minor spacing counter
            else if minorCounter >= minorSpacing {
                let marker = createLabel(text: "-", fontSize: 20, position: labelPosition, zPosition: 10, fontColor: labelColor)
                marker.isHidden = false
                addChild(marker)
                minorCounter = 0.0  // Reset minor counter
            }
            
            // Increment y by scaleFactorHeight for each iteration
            y += scaleFactorHeight
            
            // Increment the spacing counters by scaleFactorHeight
            majorCounter += scaleFactorHeight
            minorCounter += scaleFactorHeight
        }
    }
    
    func resetScene() {
        if (self.diveComplete && self.readyForReset) {
            if (!CHALLENGE_MODE) {
                platformHeight = Double.random(in: 703...(HEIGHT * 25))
                restartScene()
            } else {
                if (totalScore == 0) {
                    platformHeight = 703
                    restartScene()
                } else {
                    let streakFactor = 2.0 * Double(streak)
                    let denominator = streakFactor + 100.0
                    let streakMultiplier: Double = 1.0 + (streakFactor / denominator)

                    let randomHeightIncrease = Double.random(in: 0...500)
                    let newPlatformHeight = platformHeight + randomHeightIncrease
                    platformHeight = newPlatformHeight * streakMultiplier

                    restartScene()
                }
            }
        }
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
                              frameWidth: Game.defaultDaveHeight,
                              frameHeight: Game.defaultDaveHeight,
                              margin: 1,
                              spacing: 2,
                              scale: scaleFactorHeight)
        
        // Position and layer `dave`
        dave.position = CGPoint(x: WIDTH / 4, y: springboard.position.y + 100)
        dave.zPosition = 5
        
        // Add physics body to `dave`
        dave.physicsBody = SKPhysicsBody(rectangleOf: CGSize(width: dave.size.width/4, height: dave.size.height))
        dave.physicsBody?.isDynamic = true
        dave.physicsBody?.mass = Game.daveMass
        dave.physicsBody?.affectedByGravity = true          // Enable gravity
        dave.physicsBody?.restitution = 0.0                 // Prevent bouncing
        dave.physicsBody?.friction = 0.0                    // Prevent friction against surfaces
        
        dave.physicsBody?.categoryBitMask = PhysicsCategory.dave.rawValue
        dave.physicsBody?.contactTestBitMask = PhysicsCategory.springboard.rawValue
        dave.physicsBody?.collisionBitMask = PhysicsCategory.springboard.rawValue
        
        // Add `dave` to the scene
        addChild(dave)
        
        // Define animations for `dave`
        dave.defineAnimation(name: "idle", frameIndices: [18, 18, 18, 18, 18, 19, 20, 21], timePerFrame: 0.125)
        dave.defineAnimation(name: "walkRight", frameIndices: [2, 3, 2, 4], timePerFrame: 0.166)
        dave.defineAnimation(name: "walkLeft", frameIndices: [11, 12, 11, 13], timePerFrame: 0.166)
        dave.defineAnimation(name: "jump", frameIndices: [5, 5, 6], timePerFrame: 0.1, repeatForever: false)
    }
    
    func setupClimbDave(x: CGFloat, y: CGFloat) {
        climbdave = AnimatedSprite(spritesheetName: "climbdave",
                              frameWidth: Game.defaultDaveHeight,
                              frameHeight: Game.defaultDaveHeight,
                              scale: scaleFactorHeight)
        climbdave.position = CGPoint(x: x - (5*climbdave.size.width/7), y: y + climbdave.size.height/3)
        climbdave.zPosition = 5
        
        climbdave.physicsBody = SKPhysicsBody(rectangleOf: CGSize(width: 64 * scaleFactorWidth, height: 256 * scaleFactorHeight))
        climbdave.physicsBody?.isDynamic = true
        climbdave.physicsBody?.affectedByGravity = false
        climbdave.physicsBody?.linearDamping = 0
        climbdave.physicsBody?.collisionBitMask = 0
        climbdave.physicsBody?.contactTestBitMask = 0
        climbdave.isHidden = true
        
        addChild(climbdave)
        
        climbdave.defineAnimation(name: "climb", frameIndices: [0, 1, 2, 3], timePerFrame: 0.125)
    }
    
    func setupSpringboard() {
        // Initialize the AnimatedSprite for the springboard
        springboard = AnimatedSprite(spritesheetName: "board", frameWidth: 440, frameHeight: 64, scale: scaleFactorHeight)
        springboard.position = CGPoint(x: platformTop.position.x + platformTop.size.width / 3, y: platformTop.position.y)
        springboard.zPosition = 10
        
        // Define animations if needed (e.g., "bounce" or other)
        springboard.defineAnimation(name: "flex", frameIndices: [0, 1, 0], timePerFrame: 0.25)

        // Add physics body to springboard
        springboard.physicsBody = SKPhysicsBody(rectangleOf: CGSize(width: springboard.size.width, height: springboard.size.height))
        springboard.physicsBody?.isDynamic = false
        springboard.physicsBody?.affectedByGravity = false
        springboard.physicsBody?.restitution = 0.0
        springboard.physicsBody?.friction = 0.0
        springboard.physicsBody?.categoryBitMask = PhysicsCategory.springboard.rawValue

        addChild(springboard)
    }
    
    func setupSplash() {
        splash = AnimatedSprite(spritesheetName: "splash", frameWidth: 256, frameHeight: 256, scale: scaleFactorHeight)
        splash.zPosition = 7
        
        // Define animations if needed (e.g., "bounce" or other)
        splash.defineAnimation(name: "splash", frameIndices: [0, 1, 2, 3, 4, 5, 6, 7], timePerFrame: 0.125, repeatForever: false)
        addChild(splash)
    }
    
    func didBegin(_ contact: SKPhysicsContact) {
        let bodies = (contact.bodyA.categoryBitMask, contact.bodyB.categoryBitMask)
        
        // Check if the contact is between `dave` and `springboard`
        if (bodies == (PhysicsCategory.dave.rawValue, PhysicsCategory.springboard.rawValue)) ||
           (bodies == (PhysicsCategory.springboard.rawValue, PhysicsCategory.dave.rawValue)) {
            Haptics.impact(.light)
            daveIsTouchingBoardBool = true
            if landedAt == nil {
                landedAt = Date()
                dave.playAnimation(name: "idle")
                logger.debug("LANDED AT \(String(describing: self.landedAt))")
            }
        }
    }
    
    func didEnd(_ contact: SKPhysicsContact) {
        let bodies = (contact.bodyA.categoryBitMask, contact.bodyB.categoryBitMask)
        
        if (bodies == (PhysicsCategory.dave.rawValue, PhysicsCategory.springboard.rawValue)) ||
           (bodies == (PhysicsCategory.springboard.rawValue, PhysicsCategory.dave.rawValue)) {
                daveIsTouchingBoardBool = false
        }
    }
    
    func setupLandscapeAndPool() {
        // Landscape background image scaled and positioned
        let landscape = SKSpriteNode(imageNamed: "landscape")
        let aspectRatio = landscape.size.width / landscape.size.height
        
        // Scale landscape width to match viewport and adjust height based on aspect ratio
        landscape.size = CGSize(width: WIDTH, height: WIDTH / aspectRatio)
        landscape.position = CGPoint(x: WIDTH / 2, y: landscape.size.height / 2)
        landscape.zPosition = 1
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
        water.zPosition = 6
        addChild(water)
        water.playAnimation(name: "idle")
        
        gettingoutdave = AnimatedSprite(
            spritesheetName: "getting-out-spritesheet",
            frameWidth: 1250,
            frameHeight: 500,
            margin: 0,
            spacing: 0,
            scale: 1.0
        )

        gettingoutdave.defineAnimation(name: "getOut", frameIndices: [0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 17, 18, 19, 20, 21, 22, 23, 24, 25, 26, 27], timePerFrame: 0.125, repeatForever: false)

        gettingoutdave.size = CGSize(width: WIDTH, height: WIDTH / aspectRatio)
        gettingoutdave.position = CGPoint(x: WIDTH / 2, y: landscape.size.height / 2)
        gettingoutdave.zPosition = 7
        gettingoutdave.isHidden = true
        addChild(gettingoutdave)
    }

    
    func daveIsAboveBoard(tolerance: CGFloat = 1.0) -> Bool {
        guard let dave = dave else { return false }
        
        // Calculate and log intermediate values for debugging
        let daveRightEdge = dave.position.x + dave.size.width / 4
        let daveLeftEdge = dave.position.x - dave.size.width / 4
        let springboardRightEdge = springboard.position.x + springboard.size.width / 2
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
            springboard.playAnimation(name: "flex") {
                self.springboard.clearCurrentAnimation()
            }
            jumping = true
            dave.playAnimation(name: "jump") { [weak self] in
                guard let self = self else { return }
                
                jumping = false
                calculateBoost()
                landedAt = nil
                
                dave.physicsBody?.velocity.dy = Game.jumpVelocity + boost;
            }
        }
    }
    
    func calculateBoost() {
//        NSLog("Calculating Boost")
        // Calculate the time difference between landing and jump release
        let quickness = diff(landedAt, jumpReleasedAt)
        
        // Determine the boost based on the quickness of the jump release
        if quickness < 125 {
            boost = Game.maxBoost
        } else if quickness < 250 {
            boost = Game.maxBoost - 50
        } else if quickness < 350 {
            boost = Game.maxBoost - 100
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
        guard dave != nil else { return }

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
        let newVelocityX = physicsBody.velocity.dx * Game.drag
        physicsBody.velocity = CGVector(dx: newVelocityX, dy: physicsBody.velocity.dy)
    }

    
    func playerFrameHandler() {
        guard let dave = dave else { return }
        if !jumping {
            if daveIsAboveBoard() {
                if dave.zRotation != 0 {
                    dave.zRotation = 0
                }
                if daveIsTouchingBoardBool {
                    if let velocity = dave.physicsBody?.velocity.dx, velocity > (Game.daveSpeed/10) {
                        dave.playAnimation(name: "walkRight")
                    } else if let velocity = dave.physicsBody?.velocity.dx, velocity < -(Game.daveSpeed/10) {
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
                dave.clearCurrentAnimation()
            }
        }
    }
    
    func playerMobileMovementHandler() {
        if !diveComplete {
            if daveIsAboveBoard() {
                hud?.jumpControls()
            } else {
                hud?.flipControls()
            }
        }
        
        // Check mobile control button states and handle movement
        if hud?.leftButton.isDown == true || hud?.rightButton.isDown == true ||
           hud?.jumpButton.isDown == true || hud?.flipButton.isDown == true {
            
            if !diveComplete {
                if hud?.leftButton.isDown == true {
                    dave.physicsBody?.velocity.dx = -Game.daveSpeed
                    
                }
                if hud?.rightButton.isDown == true {
                    dave.physicsBody?.velocity.dx = Game.daveSpeed
                }
                if daveIsAboveBoard() {
                    if hud?.jumpButton.isDown == true && daveIsTouchingBoardBool {
                        daveJump()
                    }
                } else if (hud?.jumpButton.isDown == true || hud?.flipButton.isDown == true) {
                    if !daveIsTucked() {
                        tucked = true
                        tuckCount += 1
                    } else {
                        if currentVelocity < Game.maxSpinVelocity - (200.0 * .pi / 180.0) {
                            currentVelocity += 5.0 * .pi / 180.0
                        } else if currentVelocity < Game.maxSpinVelocity {
                            currentVelocity += 1.0 * .pi / 180.0
                        }
                    }
                    dave.physicsBody?.angularVelocity = -currentVelocity
                }
            }
        } else {
            tucked = false
            currentVelocity = Game.minSpinVelocity
        }
    }
    
    func checkForReset() {
        // Ensure dive is not already marked as complete
        if !diveComplete && !daveIsAboveBoard() {
            // Check if Dave has reached the water level
            if dave.position.y < waterLevel {
                Haptics.impact(.heavy)
                diveComplete = true
                splash.position = CGPoint(x: dave.position.x, y: waterLevel + 100*scaleFactorHeight)
                splash.isHidden = false
                splash.playAnimation(name: "splash") {
                    self.splash.isHidden = true
                    self.splash.clearCurrentAnimation()
                }
            
                // Calculate height, angle, and other stats
                stats.height = calculateHeightFromWater()
                stats.angle = round(dave.zRotation * (180.0 / .pi) * 10.0) / 10
                stats.tucked = daveIsTucked()
                stats.tuckCount = tuckCount
                stats.rotations = round(totalRotations * 10) / 10
                
                logger.debug("stats: \(String(describing: stats))")
                
                // Display the InfoPanel with calculated stats
                let result = scoreDive()
                Haptics.notify(result == "FAILED DIVE" ? .error : .success)
                hud.setRunningStreak(streak: streak)
                hud.setRunningScore(score: totalScore)
                let displayStrings = [
                    "height: \(stats.height)m",
                    "entry angle: \(stats.angle)",
                    "rotations: \(stats.rotations)"
                ]
                info.display(result: result, strings: displayStrings, frame: stats.emotionFrame, scores: stats.scores)
                
                // Hide mobile hud
                hud.setVisible(false)
                
                // Set a delay to allow for scene reset readiness
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                    self.readyForReset = true
                    
                    self.gettingoutdave.isHidden = false
                    self.gettingoutdave.playAnimation(name: "getOut") {
                        self.climbdave.physicsBody?.velocity.dy = 50
                        self.gettingoutdave.isHidden = true
                        self.climbdave.playAnimation(name: "climb")
                        self.climbdave.isHidden = false
                    }
                }
            }
            
            // Track rotations while in the air
            countRotations()
        }
    }
    
    func calculateHeightFromWater() -> Double {
        let heightDifference = springboard.position.y - waterLevel
        let heightInMeters = heightDifference / (200.0 * scaleFactorHeight)
        return round(heightInMeters * 10) / 10
    }
    
    var previousAngle: CGFloat = 0
    var currentAngle: CGFloat = 0
    var lastFlipNumber: Double = 0
    func countRotations() {
        if (tuckCount >= 1) {
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
                        Haptics.impact(.light)

                        // Display rotation count near `dave`'s position
                        let rotationLabel = createRotationLabel(text: "\(Int(roundedRotations))", fontColor: roundedRotations > Double(goalRotations) ? Game.customRed : Game.customGreen)
                        rotationLabel.position = dave.position
                        rotationLabel.zPosition = 4
                        addChild(rotationLabel)

                        // Update the last counted flip number
                        lastFlipNumber = roundedRotations
                    }
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
    
    func scoreDive() -> String {
        // Persist per-dive meta-progression (every dive, success or fail)
        StatsStore.totalDives += 1
        StatsStore.totalFlips += Int(stats.rotations)
        StatsStore.maxHeightReached = max(StatsStore.maxHeightReached, Int(platformHeight))

        // Check if the rotations are within the goal range
        if abs(stats.rotations - goalRotations) < 0.25 {
            // Set emotion frame based on the angle
            stats.emotionFrame = chooseEmotionFrame(angle: stats.angle)
            
            // Calculate individual scores based on emotion frame and tuck count
            for (index, _) in stats.scores.enumerated() {
                switch stats.emotionFrame {
                case 4:
                    stats.scores[index] = Int(10 - Double(Int.random(in: 0...1)) / 2.0 - Double(tuckCount - 1))
                case 3:
                    stats.scores[index] = Int(10 - Double(Int.random(in: 3...6)) / 2.0 - Double(tuckCount - 1))
                case 2:
                    stats.scores[index] = Int(10 - Double(Int.random(in: 7...10)) / 2.0 - Double(tuckCount - 1))
                case 1:
                    stats.scores[index] = Int(10 - Double(Int.random(in: 10...15)) / 2.0 - Double(tuckCount - 1))
                case 0:
                    stats.scores[index] = Int(10 - Double(Int.random(in: 14...18)) / 2.0 - Double(tuckCount - 1))
                default:
                    break
                }
            }

            // Adjust emotion frame if there was a tuck
            if tuckCount > 1 {
                stats.emotionFrame -= 1
            }
            
            // Update total score and streak
            streak += 1
            totalScore += stats.scores.reduce(0, +)

            // Track longest streak across runs
            StatsStore.longestStreak = max(StatsStore.longestStreak, streak)

            // Update per-mode high score in the new store (legacy write below
            // is intentionally preserved — Lane E owns its removal).
            if CHALLENGE_MODE {
                StatsStore.challengeHigh = max(StatsStore.challengeHigh, totalScore)
            } else {
                StatsStore.arcadeHigh = max(StatsStore.arcadeHigh, totalScore)
            }

            if CHALLENGE_MODE && totalScore > highScore {
                highScore = totalScore
                UserDefaults.standard.set(highScore, forKey: Game.highScoreKey)
                highScoreSession = true

                // Display high score text briefly
                hud.highScoreLabel.isHidden = false
                DispatchQueue.main.asyncAfter(deadline: .now() + 5.0) {
                    self.hud.highScoreLabel.isHidden = true
                }
            }
            
            return "SUCCESS"
        } else {
            // Failed dive: reset scores and show "Game Over" panel if high score was reached
            stats.emotionFrame = 0
            stats.scores = [0, 0, 0]
            
            if highScoreSession {
                highScorePanel.display(result: "GAME OVER",  strings: [
                    "",
                    "NEW HIGH SCORE: \(totalScore)",
                    "",
                    "final height: \(stats.height)m",
                    "streak: \(streak) dives",
                ], frame: 3, scores: nil)
            }
            
            // Reset streak and total score
            streak = 0
            totalScore = 0
            
            return "FAILED DIVE"
        }
    }

    func chooseEmotionFrame(angle: Double) -> Int {
        let absAngle = abs(angle)

        // Convert degree boundaries to radians
        let boundary10 = 10.0
        let boundary25 = 25.0
        let boundary45 = 45.0
        let boundary70 = 70.0
        let boundary110 = 110.0
        let boundary135 = 135.0
        let boundary155 = 155.0
        let boundary170 = 170.0

        if absAngle < boundary10 || absAngle > boundary170 {
            return 4
        } else if (absAngle >= boundary10 && absAngle < boundary25) || (absAngle <= boundary170 && absAngle > boundary155) {
            return 3
        } else if (absAngle >= boundary25 && absAngle < boundary45) || (absAngle <= boundary155 && absAngle > boundary135) {
            return 2
        } else if (absAngle >= boundary45 && absAngle < boundary70) || (absAngle <= boundary135 && absAngle > boundary110) {
            return 1
        } else if absAngle >= boundary70 && absAngle < boundary110 {
            return 0
        }

        return 2 // Default return value if no conditions match
    }
    
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        if (self.diveComplete) {
            resetScene()
        }
    }
    
    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {

    }
    
    override func update(_ currentTime: TimeInterval) {
        playerHandler()
        applyPhaserStyleAngularDrag(currentTime: currentTime)
        updateClimbDave()
        updateCamera()
        atmosphere.update()
    }
    
    func applyPhaserStyleAngularDrag(currentTime: TimeInterval) {
        let dt = currentTime - lastUpdateTime
        lastUpdateTime = currentTime
        let deltaTime = CGFloat(dt)

        guard let body = dave.physicsBody else { return }

        let sign: CGFloat = body.angularVelocity >= 0 ? 1 : -1
        let dragThisFrame = Game.linearAngularDrag * deltaTime
        let newAngularVelocity = abs(body.angularVelocity) - dragThisFrame

        body.angularVelocity = max(newAngularVelocity, 0) * sign
    }
    
    func updateClimbDave() {
        if (diveComplete && climbdave != nil && platformTop != nil) {
            if (climbdave.position.y > platformTop.position.y) {
                climbdave.physicsBody?.velocity.dy = 0
                climbdave.stopAnimation()
                climbdave.texture = climbdave.frames[0]
            }
        }
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
        
        atmosphere.updateBackgroundColor(for: camera.position.y)
    }
    
    func prepareAndPresentMainMenuScene() {
        let mainMenuScene = MainMenuScene(size: self.view!.bounds.size)
        mainMenuScene.backgroundColor = SKColor(red: 0.74, green: 0.84, blue: 1.0, alpha: 1.0)
        mainMenuScene.scaleMode = .aspectFill
        mainMenuScene.setupMenu()
        self.diveComplete = true
        self.readyForReset = true
        totalScore = 0
        platformHeight = 703
        self.restartScene()
        self.view!.presentScene(mainMenuScene, transition: SKTransition.crossFade(withDuration: 0.5))
    }
}
