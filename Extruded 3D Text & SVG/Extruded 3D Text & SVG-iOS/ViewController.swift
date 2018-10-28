//
//  ViewController.swift
//  Extruded 3D Text & SVG-iOS
//
//  Created by Eugene Bokhan on 28/10/2018.
//  Copyright © 2018 Eugene Bokhan. All rights reserved.
//

import MetalKit

class ViewController: UIViewController {
    
    var renderer: Renderer?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        guard let metalView = view as? MTKView else {
            fatalError("metal view not set up in storyboard")
        }
        
        renderer = Renderer(metalView: metalView)
        addGestureRecognizer(to: metalView)
    }
}

