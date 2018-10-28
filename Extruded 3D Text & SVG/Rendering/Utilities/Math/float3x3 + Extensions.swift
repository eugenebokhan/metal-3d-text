//
//  float3x3 + Extensions.swift
//  Extruded 3D Text & SVG
//
//  Created by Eugene Bokhan on 28/10/2018.
//  Copyright © 2018 Eugene Bokhan. All rights reserved.
//

import simd

extension float3x3 {
    init(normalFrom4x4 matrix: float4x4) {
        self.init()
        columns = matrix.upperLeft().inverse.transpose.columns
    }
}
