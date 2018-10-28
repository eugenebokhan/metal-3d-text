//
//  ViewController + Gestures.swift
//  Extruded 3D Text & SVG-macOS
//
//  Created by Eugene Bokhan on 28/10/2018.
//  Copyright © 2018 Eugene Bokhan. All rights reserved.
//

import Cocoa

extension ViewController {
    func addGestureRecognizer(to view: NSView) {
        let pan = NSPanGestureRecognizer(target: self, action: #selector(handlePan(gesture:)))
        view.addGestureRecognizer(pan)
    }
    
    @objc func handlePan(gesture: NSPanGestureRecognizer) {
        let translation = float2(Float(gesture.translation(in: gesture.view).x),
                                 Float(gesture.translation(in: gesture.view).y))
        
        renderer?.rotateCamera(using: translation, sensitivity: 0.01)
        gesture.setTranslation(.zero, in: gesture.view)
    }
    
    override open func scrollWheel(with event: NSEvent) {
        let translation = float2(Float(-event.deltaX),
                                 Float(event.deltaY))
        renderer?.translateCamera(using: translation, sensitivity: 0.4)
    }
    
    override open func magnify(with event: NSEvent) {
        renderer?.zoomCamera(using: event.magnification,
                             sensitivity: 30)
    }
}
