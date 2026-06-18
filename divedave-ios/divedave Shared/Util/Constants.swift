//
//  Constants.swift
//  divedave iOS
//
//  Created by David Durkin on 10/29/24.
//

import CoreGraphics
import SpriteKit

// Game Modes and Gravity
let GRAVITY: CGFloat = 2
let DAVE_MASS: CGFloat = 1.0
let JUMP_IMPULSE: CGFloat = 8000
let WALK_IMPULSE: CGFloat = 1500

// Default Game Dimensions
let DEFAULT_WIDTH: CGFloat = 1250
let DEFAULT_HEIGHT: CGFloat = 3000
let DEFAULT_DAVE_HEIGHT: CGFloat = 256
let DEFAULT_BUTTON_HEIGHT: CGFloat = 256

// Player Movement and Physics
let DAVE_SPEED: CGFloat = 100
let JUMP_VELOCITY: CGFloat = 200
let MIN_SPIN_VELOCITY: CGFloat = 100.0 * .pi / 180.0
let MAX_SPIN_VELOCITY: CGFloat = 550.0 * .pi / 180.0
let DRAG: CGFloat = 0.94
let ANGULAR_DRAG: CGFloat = 0.9
let LINEAR_ANGULAR_DRAG: CGFloat = 2.618
let MAX_BOOST: CGFloat = 100
let IDLE_DELAY: CGFloat = 1.0

// Cloud and Bird Constants
let MIN_CLOUDS = 5
let MAX_CLOUDS = 12
let CLOUD_MIN_SPEED: CGFloat = 8
let CLOUD_MAX_SPEED: CGFloat = 20
let MIN_BIRDS = 0
let MAX_BIRDS = 3
let BIRD_MIN_SPEED: CGFloat = 25
let BIRD_MAX_SPEED: CGFloat = 100

let HIGH_SCORE = "highScore"

let customGreen = SKColor(red: 0/255, green: 128/255, blue: 0/255, alpha: 1.0)
let customRed = SKColor(red: 255/255, green: 0/255, blue: 0/255, alpha: 1.0)
let customYellow = SKColor(red: 255/255, green: 255/255, blue: 0/255, alpha: 1.0)
