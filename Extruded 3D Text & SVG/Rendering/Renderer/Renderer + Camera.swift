//
//  Renderer + Camera.swift
//  Extruded 3D Text & SVG
//
//  Created by Eugene Bokhan on 28/10/2018.
//  Copyright © 2018 Eugene Bokhan. All rights reserved.
//

import MetalKit

extension Renderer {
    func zoomCamera(using delta: CGFloat, sensitivity: Float) {
        camera.position.z += Float(delta) * sensitivity
    }
    
    func rotateCamera(using translation: float2, sensitivity: Float) {
        camera.rotation.x += Float(translation.y) * sensitivity
        camera.rotation.y -= Float(translation.x) * sensitivity
    }
    
    func translateCamera(using translation: float2, sensitivity: Float) {
        camera.position.x += Float(translation.x) * sensitivity
        camera.position.y += Float(translation.y) * sensitivity
    }
}
