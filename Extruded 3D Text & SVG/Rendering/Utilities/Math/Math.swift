//
//  Math.swift
//  Extruded 3D Text & SVG
//
//  Created by Eugene Bokhan on 28/10/2018.
//  Copyright © 2018 Eugene Bokhan. All rights reserved.
//

import simd

func radians(fromDegrees degrees: Float) -> Float {
    return (degrees / 180) * .pi
}

func degrees(fromRadians radians: Float) -> Float {
    return (radians / .pi) * 180
}
