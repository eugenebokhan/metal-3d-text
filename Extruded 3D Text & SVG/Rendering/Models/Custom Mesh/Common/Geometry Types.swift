//
//  Geometry Types.swift
//  Extruded 3D Text & SVG
//
//  Created by Eugene Bokhan on 28/10/2018.
//  Copyright © 2018 Eugene Bokhan. All rights reserved.
//

import QuartzCore

/// A mesh vertex containing a position, normal, and texture coordinates
public struct MeshVertex {
    var x: Float = 0.0
    var y: Float = 0.0
    var z: Float = 0.0
    var nx: Float = 0.0
    var ny: Float = 0.0
    var nz: Float = 0.0
    var s: Float = 0.0
    var t: Float = 0.0
}

/// A 2D point on a planar path
public struct PathVertex {
    var x: Float = 0.0
    var y: Float = 0.0
}

/// A linked list of closed path contours, each specified as a list of points

public struct PathContour {
    public var vertices: [PathVertex] = []
}

/// A linked list of glyphs, each jointly represented as a list of contours, a CGPath, and a set of vertices and indices
public class GeometryPart {
    var path: CGPath?
    var contoursList = LinkedList<PathContour>()
    var vertices: [TESSreal] = []
    var indices: [TESSindex] = []
    
    public init(path: CGPath) {
        self.path = path
    }
    
    func withFlattenedPath<T: GeometryPart>(flatness: CGFloat,
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
            case .addQuadCurveToPoint:
                if useAdaptiveSubdivision {
                    let maxSubdivisions = 20
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
            case .addCurveToPoint:
                print("Can't currently flatten font outlines containing cubic curve segments")
                break
            case .closeSubpath:
                flattenedPath.closeSubpath()
                break
            }
        }
        
        self.path = flattenedPath
        return self as! T
    }
    
    func withTesselatedPaths<T: GeometryPart>(tesselator: UnsafeMutablePointer<TESStesselator>!) -> T {
        
        /// Accumulate the contours of the flattened path into the tessellator so it can compute the CDT
        let contoursList = getPathContourList(path: self.path!, using: tesselator)
        
        /// Do the actual tessellation work
        let result = tessTesselate(tesselator,
                                   CInt(TESS_WINDING_ODD.rawValue),
                                   CInt(TESS_POLYGONS.rawValue),
                                   CInt(polygonIndexCount),
                                   CInt(vertComponentCount),
                                   nil)
        if result != 1 {
            print("Unable to tessellate path")
        }
        
        /// Retrieve the tessellated mesh from the tessellator and copy the contour list and geometry to the current glyph
        let vertices = Array(UnsafeBufferPointer(start: tessGetVertices(tesselator),
                                                 count: Int(tessGetVertexCount(tesselator)) * vertComponentCount))
        let indices = Array(UnsafeBufferPointer(start: tessGetElements(tesselator),
                                                count: Int(tessGetElementCount(tesselator)) * polygonIndexCount))
        
        
        self.contoursList = contoursList
        self.vertices = vertices
        self.indices = indices
        
        return self as! T
    }
    
    func getPathContourList(path: CGPath, using tesselator: UnsafeMutablePointer<TESStesselator>) -> LinkedList<PathContour> {
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
