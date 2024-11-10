//
//  Globals.swift
//  divedave iOS
//
//  Created by David Durkin on 11/7/24.
//

import Foundation
import CoreGraphics
import SpriteKit

var WIDTH: CGFloat = DEFAULT_WIDTH
var HEIGHT: CGFloat = DEFAULT_HEIGHT
var scaleFactorHeight = HEIGHT / DEFAULT_HEIGHT
var scaleFactorWidth = WIDTH / DEFAULT_WIDTH

var CHALLENGE_MODE = true
var sceneHeight: CGFloat! = HEIGHT
var platformHeight: CGFloat = 603
var jumpReleasedAt: Date? = nil
var streak = 0
var totalScore = 0
var highScore = 0

let startColor = SKColor(red: 0.74, green: 0.84, blue: 1.0, alpha: 1.0) // Blue color
let middleColor = SKColor(red: 0.9, green: 0.95, blue: 1.0, alpha: 1.0) // Light white-blue color
let endColor = SKColor.black
