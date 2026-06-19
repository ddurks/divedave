//
//  Globals.swift
//  divedave iOS
//
//  Created by David Durkin on 11/7/24.
//

import Foundation
import CoreGraphics
import SpriteKit

// NOTE: screen/scaling and session-state globals have all moved to
// GameState.shared — Lane E. `jumpReleasedAt` is the last holdout pending
// the Date -> CFTimeInterval conversion in the next step.

var jumpReleasedAt: Date? = nil

let startColor = SKColor(red: 0.74, green: 0.84, blue: 1.0, alpha: 1.0) // Blue color
let middleColor = SKColor(red: 0.9, green: 0.95, blue: 1.0, alpha: 1.0) // Light white-blue color
let endColor = SKColor.black
