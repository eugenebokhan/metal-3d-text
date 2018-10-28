//
//  ViewController + Gestures.swift
//  Extruded 3D Text & SVG-iOS
//
//  Created by Eugene Bokhan on 28/10/2018.
//  Copyright © 2018 Eugene Bokhan. All rights reserved.
//

import UIKit

extension ViewController {
    static var previousScale: CGFloat = 1
    
    func addGestureRecognizer(to view: UIView) {
        let oneFingerPan = UIPanGestureRecognizer(target: self,
                                                  action: #selector(handleOneFingerPan(gesture:)))
        oneFingerPan.minimumNumberOfTouches = 1
        oneFingerPan.maximumNumberOfTouches = 1
        view.addGestureRecognizer(oneFingerPan)
        let twoFingersPan = UIPanGestureRecognizer(target: self,
                                                   action: #selector(handleTwoFingersPan(gesture:)))
        twoFingersPan.minimumNumberOfTouches = 2
        twoFingersPan.maximumNumberOfTouches = 2
        view.addGestureRecognizer(twoFingersPan)
        
        let pinch = UIPinchGestureRecognizer(target: self,
                                             action: #selector(handlePinch(gesture:)))
        view.addGestureRecognizer(pinch)
    }
    
    @objc func handleOneFingerPan(gesture: UIPanGestureRecognizer) {
        let translation = float2(Float(gesture.translation(in: gesture.view).x),
                                 Float(-gesture.translation(in: gesture.view).y))
        renderer?.rotateCamera(using: translation, sensitivity: 0.01)
        gesture.setTranslation(.zero, in: gesture.view)
    }
    
    @objc func handleTwoFingersPan(gesture: UIPanGestureRecognizer) {
        let translation = float2(Float(-gesture.translation(in: gesture.view).x),
                                 Float(gesture.translation(in: gesture.view).y))
        renderer?.translateCamera(using: translation, sensitivity: 0.06)
        gesture.setTranslation(.zero, in: gesture.view)
    }
    
    @objc func handlePinch(gesture: UIPinchGestureRecognizer) {
        renderer?.zoomCamera(using: gesture.scale-ViewController.previousScale,
                             sensitivity: 30)
        ViewController.previousScale = gesture.scale
        if gesture.state == .ended {
            ViewController.previousScale = 1
        }
    }
}
