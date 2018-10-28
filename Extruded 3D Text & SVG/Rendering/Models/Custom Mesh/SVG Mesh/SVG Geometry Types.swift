//
//  SVG Geometry Types.swift
//  Extruded 3D Text & SVG
//
//  Created by Eugene Bokhan on 28/10/2018.
//  Copyright © 2018 Eugene Bokhan. All rights reserved.
//

import QuartzCore

public class SVGGeometryPart: GeometryPart {
    
    override func withFlattenedPath<T: GeometryPart>(flatness: CGFloat,
                                            useAdaptiveSubdivision: Bool = true,
                                            defaultQuadCurveSubdivisions: Int = 5) -> T {
        let flattenedPath = CGMutablePath()
        /// Iterate the elements in the path, converting curve segments into sequences of small line segments
        guard self.path != nil else { return self as! T }
        self.path!.applyWithBlock { (element) in
            switch element.pointee.type {
            case .moveToPoint:
                let point = element.pointee.points[0]
                flattenedPath.move(to: point)
                break
            case .addLineToPoint:
                let point = element.pointee.points[0]
                flattenedPath.addLine(to: point)
                break
            case .addQuadCurveToPoint, .addCurveToPoint:
                if useAdaptiveSubdivision {
                    let maxSubdivisions = 200
                    let fromPoint = flattenedPath.currentPoint
                    let toPoint = element.pointee.points[1]
                    let controlPoint = element.pointee.points[0]
                    let maximumTolerableSquaredError = pow(flatness, 2)
                    var subdivisionParameter: CGFloat = 0 // Parameter of the curve up to which we've subdivided
                    var candidateParameter: CGFloat = 0.5 // "Candidate" parameter of the curve we're currently evaluating
                    var point = fromPoint // Point along curve at parameter t
                    while subdivisionParameter < 1.0 {
                        var subdivisions = 1
                        var error = CGFloat(MAXFLOAT)
                        var candidatePoint = point
                        candidateParameter = min(1.0, subdivisionParameter + 0.5)
                        while error > maximumTolerableSquaredError {
                            candidatePoint = evalQuadCurve(a: fromPoint,
                                                           b: toPoint,
                                                           c: controlPoint,
                                                           t: candidateParameter)
                            let middleParameter = (subdivisionParameter + candidateParameter) / 2
                            let middleCurve = evalQuadCurve(a: fromPoint,
                                                            b: toPoint,
                                                            c: controlPoint,
                                                            t: middleParameter)
                            let middleSegment = lerpPoints(point, candidatePoint, 0.5)
                            error = pow(middleSegment.x - middleCurve.x, 2) + pow(middleSegment.y - middleCurve.y, 2)
                            if error > maximumTolerableSquaredError {
                                candidateParameter = subdivisionParameter + 0.5 * (candidateParameter - subdivisionParameter)
                                subdivisions += 1
                                if subdivisions > maxSubdivisions {
                                    break
                                }
                            }
                        }
                        subdivisionParameter = candidateParameter
                        point = candidatePoint
                        flattenedPath.addLine(to: point)
                    }
                } else {
                    let fromPoint = flattenedPath.currentPoint
                    let toPoint = element.pointee.points[1]
                    let controlPoint = element.pointee.points[0]
                    for i in 0 ..< defaultQuadCurveSubdivisions {
                        let subdivisionParameter = CGFloat(i / (defaultQuadCurveSubdivisions - 1))
                        let point = evalQuadCurve(a: fromPoint, b: toPoint, c: controlPoint, t: subdivisionParameter)
                        flattenedPath.addLine(to: point)
                    }
                }
                break
            case .closeSubpath:
                flattenedPath.closeSubpath()
                break
            }
        }
        
        self.path = flattenedPath
        return self as! T
    }
    
    override func getPathContourList(path: CGPath, using tesselator: UnsafeMutablePointer<TESStesselator>) -> LinkedList<PathContour> {
        let contourList = LinkedList<PathContour>()
        contourList.append(PathContour())
        /// Iterate the line segments in the flattened path, accumulating each subpath as a contour,
        /// then pass closed contours to the tessellator
        var counter = 0
        path.applyWithBlock { (element) in
            counter += 1
            switch element.pointee.type {
            case .moveToPoint:
                if contourList.last!.value.vertices.count != 0 {
                    print("Open subpaths are not supported; all contours must be closed")
                }
                let point = element.pointee.points[0]
                let pathVertex = PathVertex(x: Float(point.x), y: Float(point.y))
                if pathVertex.x == 0 && pathVertex.y == 0 {
                    break
                }
                contourList.last!.value.vertices.append(pathVertex)
                break
            case .addLineToPoint:
                let point = element.pointee.points[0]
                let pathVertex = PathVertex(x: Float(point.x), y: Float(point.y))
                contourList.last!.value.vertices.append(pathVertex)
                break
            case .addQuadCurveToPoint:
                print("Tessellator does not expect curve segments; flatten path first")
                break
            case .addCurveToPoint:
                break
            case .closeSubpath:
                let vertices = contourList.last!.value.vertices
                let vertexCount = vertices.count
                
                tessAddContour(tesselator, 2, vertices, CInt(MemoryLayout<PathVertex>.size), CInt(vertexCount))
                contourList.append(PathContour())
                break
            }
        }
        return contourList
    }
    
}
