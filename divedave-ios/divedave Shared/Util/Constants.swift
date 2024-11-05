//
//  Constants.swift
//  divedave iOS
//
//  Created by David Durkin on 10/29/24.
//

import CoreGraphics

// Game Modes and Gravity
var CHALLENGE_MODE = true
let GRAVITY: CGFloat = 3
let DAVE_MASS: CGFloat = 1.0
let JUMP_IMPULSE: CGFloat = 8000
let WALK_IMPULSE: CGFloat = 1500

// Screen Dimensions
let DEFAULT_WIDTH: CGFloat = 1250
let DEFAULT_HEIGHT: CGFloat = 3000
let DEFAULT_DAVE_HEIGHT: CGFloat = 256
let DEFAULT_BUTTON_HEIGHT: CGFloat = 256

var WIDTH: CGFloat = DEFAULT_WIDTH
var HEIGHT: CGFloat = DEFAULT_HEIGHT
var scaleFactorHeight = HEIGHT / DEFAULT_HEIGHT
var scaleFactorWidth = WIDTH / DEFAULT_WIDTH

// Player Movement and Physics
let DAVE_SPEED: CGFloat = 100
let JUMP_VELOCITY: CGFloat = 300
let MIN_SPIN_VELOCITY: CGFloat = 3
let MAX_SPIN_VELOCITY: CGFloat = 15
let DRAG: CGFloat = 0.95
let ANGULAR_DRAG: CGFloat = 1
let MAX_BOOST: CGFloat = 200
let IDLE_DELAY: CGFloat = 1.0

// Cloud and Bird Constants
let MIN_CLOUDS = 7
let MAX_CLOUDS = 15
let CLOUD_MIN_SPEED: CGFloat = 35
let CLOUD_MAX_SPEED: CGFloat = 85
let MIN_BIRDS = 0
let MAX_BIRDS = 3
let BIRD_MIN_SPEED: CGFloat = 50
let BIRD_MAX_SPEED: CGFloat = 200

// High Score
let HIGH_SCORE_COOKIE = "highScore"
