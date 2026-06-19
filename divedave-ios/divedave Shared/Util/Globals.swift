//
//  Globals.swift
//  divedave iOS
//
//  Created by David Durkin on 11/7/24.
//

import Foundation
import CoreGraphics
import SpriteKit

// NOTE: every file-scope `var` that used to live here has moved to
// GameState.shared (Lane E). Only the color constants below remain, and they
// migrate (along with this file's deletion) in the cleanup step.

let startColor = SKColor(red: 0.74, green: 0.84, blue: 1.0, alpha: 1.0) // Blue color
let middleColor = SKColor(red: 0.9, green: 0.95, blue: 1.0, alpha: 1.0) // Light white-blue color
let endColor = SKColor.black
