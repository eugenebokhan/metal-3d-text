//
//  Float + Extensions.swift
//  Extruded 3D Text & SVG
//
//  Created by Eugene Bokhan on 28/10/2018.
//  Copyright © 2018 Eugene Bokhan. All rights reserved.
//

import simd

extension Float {
    var radiansToDegrees: Float {
        return (self / .pi) * 180
    }
    var degreesToRadians: Float {
        return (self / 180) * .pi
    }
}
