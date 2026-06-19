//
//  Globals.swift
//  divedave iOS
//
//  Created by David Durkin on 11/7/24.
//

import Foundation
import CoreGraphics
import SpriteKit

// NOTE: screen/scaling globals (WIDTH/HEIGHT/scaleFactor*) have moved to
// GameState.shared.metrics — Lane E (screen/scaling step).
// The remaining session globals migrate in subsequent steps.

var CHALLENGE_MODE = true
var sceneHeight: CGFloat = 0
var platformHeight: CGFloat = 603
var jumpReleasedAt: Date? = nil
var streak = 0
var totalScore = 0
var highScore = 0

let startColor = SKColor(red: 0.74, green: 0.84, blue: 1.0, alpha: 1.0) // Blue color
let middleColor = SKColor(red: 0.9, green: 0.95, blue: 1.0, alpha: 1.0) // Light white-blue color
let endColor = SKColor.black
