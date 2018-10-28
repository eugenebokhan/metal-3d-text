//
//  Submesh.swift
//  Extruded 3D Text & SVG
//
//  Created by Eugene Bokhan on 28/10/2018.
//  Copyright © 2018 Eugene Bokhan. All rights reserved.
//

import MetalKit

class Submesh {
    
    // MARK: - Properties
    
    let submesh: MTKSubmesh
    
    struct Textures {
        let baseColor: MTLTexture?
    }
    let textures: Textures
    
    // MARK: - Life Cycle
    
    init(submesh: MTKSubmesh, mdlSubmesh: MDLSubmesh) {
        self.submesh = submesh
        textures = Textures(material: mdlSubmesh.material)
    }
}
