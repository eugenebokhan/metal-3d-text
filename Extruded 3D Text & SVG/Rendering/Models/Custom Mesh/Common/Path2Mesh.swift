//
//  Path2Mesh.swift
//  Extruded 3D Text & SVG
//
//  Created by Eugene Bokhan on 28/10/2018.
//  Copyright © 2018 Eugene Bokhan. All rights reserved.
//

import MetalKit

typealias IndexType = UInt32

let polygonIndexCount = 3 /// triangles only
let vertComponentCount = 2 /// 2D vertices (x, y)

func lerp <T: FloatingPoint>(_ a: T, _ b: T, _ t: T) -> T {
    return a + t * (b - a)
}

func lerpPoints(_ a: CGPoint, _ b: CGPoint, _ t: CGFloat) -> CGPoint {
    return CGPoint(x: lerp(a.x, b.x, t), y: lerp(a.y, b.y, t))
}

/// Maps a value t in a range [a, b] to the range [c, d]
func remap <T: FloatingPoint>(_ a: T, _ b: T, _ c: T, _ d: T, _ t: T) -> T {
    let p = (t - a) / (b - a)
    return c + p * (d - c)
}

func evalQuadCurve(a: CGPoint, b: CGPoint, c: CGPoint, t: CGFloat) -> CGPoint {
    let q0 = CGPoint(x: lerp(a.x, c.x, t), y: lerp(a.y, c.y, t))
    let q1 = CGPoint(x: lerp(c.x, b.x, t), y: lerp(c.y, b.y, t))
    let r = CGPoint(x: lerp(q0.x, q1.x, t), y: lerp(q0.y, q1.y, t))
    return r
}

func flattenPaths<T: GeometryPart>(for glyphsList: inout LinkedList<T>) {
    glyphsList = glyphsList.map { $0.withFlattenedPath(flatness: 0.1) }
}

func tesselatePaths<T: GeometryPart>(for glyphsList: inout LinkedList<T>) {
    /// Create a new libtess tessellator, requesting constrained Delaunay triangulation
    guard let tesselator = tessNewTess(nil) else { return }
    tessSetOption(tesselator,
                  CInt(TESS_CONSTRAINED_DELAUNAY_TRIANGULATION.rawValue),
                  1)
    
    glyphsList = glyphsList.map { $0.withTesselatedPaths(tesselator: tesselator) }
    
    tessDeleteTess(tesselator)
}

func calculateVertexCount<T: GeometryPart>(in geometryPartsList: inout LinkedList<T>,
                                         vertexBufferCount: inout UInt32,
                                         indexBufferCount: inout UInt32) {
    
    geometryPartsList.forEach { part in
        /// Space for front- and back-facing tessellated faces
        vertexBufferCount += IndexType(part.vertices.count)
        indexBufferCount += 2 * IndexType(part.indices.count)
        part.contoursList.forEach { contour in
            // Space for stitching faces
            vertexBufferCount += 2 * IndexType(contour.vertices.count)
            indexBufferCount += 6 * IndexType(contour.vertices.count + 1)
        }
    }
}

func writeVertices<T: GeometryPart>(from geometryPartsList: inout LinkedList<T>,
                                  to vertexBuffer: inout MDLMeshBuffer,
                                  bounds: CGRect,
                                  extrusionDepth: CGFloat,
                                  offset: inout Int) {
    /// For each glyph, write two copies of the tessellated mesh into the vertex buffer,
    /// one after the other. The first copy is for front-facing faces, and the second
    /// copy is for rear-facing faces
    geometryPartsList.forEach { part in
        var vertices = Array(repeating: MeshVertex(), count: part.vertices.count)
        var i: Int = 0
        var j: Int = part.vertices.count / vertComponentCount
        
        while i < part.vertices.count / vertComponentCount {
            
            let x = part.vertices[i * vertComponentCount + 0]
            let y = part.vertices[i * vertComponentCount + 1]
            let s = remap(Float(bounds.minX), Float(bounds.maxX), 0, 1, x)
            let t = remap(Float(bounds.minY), Float(bounds.maxY), 1, 0, y)
            
            vertices[i].x = x
            vertices[i].y = y
            vertices[i].z = 0
            vertices[i].s = s
            vertices[i].t = t
            
            vertices[j].x = x
            vertices[j].y = y
            vertices[j].z = Float(-extrusionDepth);
            vertices[j].s = s
            vertices[j].t = t
            
            i += 1
            j += 1
        }
        let verticesData = vertices.withUnsafeBytes{ Data($0) }
        vertexBuffer.fill(verticesData, offset: offset)
        
        offset += part.vertices.count * MemoryLayout<MeshVertex>.size
    }
    
    /// Now, write two copies of the contour vertices into the vertex buffer. The first
    /// set correspond to the front-facing faces, and the second copy correspond to the
    /// rear-facing faces
    geometryPartsList.forEach { part in
        part.contoursList.forEach { contour in
            var vertices = Array(repeating: MeshVertex(), count: contour.vertices.count * 2)
            
            var i: Int = 0
            var j: Int = contour.vertices.count
            while i < contour.vertices.count {
                
                let x = contour.vertices[i].x
                let y = contour.vertices[i].y
                let s = remap(Float(bounds.minX), Float(bounds.maxX), 0, 1, x)
                let t = remap(Float(bounds.minY), Float(bounds.maxY), 1, 0, y)
                
                vertices[i].x = x
                vertices[i].y = y
                vertices[i].z = 0
                vertices[i].s = s
                vertices[i].t = t
                
                vertices[j].x = x
                vertices[j].y = y
                vertices[j].z = Float(-extrusionDepth)
                vertices[j].s = s
                vertices[j].t = t
                
                i += 1
                j += 1
            }
            
            let verticesData = vertices.withUnsafeBytes{ Data($0) }
            vertexBuffer.fill(verticesData, offset: offset)
            
            offset += contour.vertices.count * 2 * MemoryLayout<MeshVertex>.size
        }
    }
}

func writeIndices<T: GeometryPart>(from geometryPartsList: inout LinkedList<T>,
                                 to indexBuffer: inout MDLMeshBuffer,
                                 offset: inout Int) {
    var baseVertex: UInt32 = 0
    
    /// Write indices for front-facing and back-facing faces
    geometryPartsList.forEach { part in
        var indices = Array(repeating: IndexType(0), count: part.indices.count * 2)
        
        var i: Int = 0
        var j: Int = part.indices.count
        while i < part.indices.count {
            
            /// front face
            indices[i + 2] = IndexType(part.indices[i + 0]) + baseVertex
            indices[i + 1] = IndexType(part.indices[i + 1]) + baseVertex
            indices[i + 0] = IndexType(part.indices[i + 2]) + baseVertex
            /// rear face
            indices[j + 0] = IndexType(part.indices[i + 0]) + baseVertex + IndexType(part.vertices.count / vertComponentCount)
            indices[j + 1] = IndexType(part.indices[i + 1]) + baseVertex + IndexType(part.vertices.count / vertComponentCount)
            indices[j + 2] = IndexType(part.indices[i + 2]) + baseVertex + IndexType(part.vertices.count / vertComponentCount)
            
            i += 3
            j += 3
        }
        
        let indicesData = indices.withUnsafeBytes{ Data($0) }
        indexBuffer.fill(indicesData, offset: offset)
        
        baseVertex += IndexType(part.vertices.count)
        offset += part.indices.count * 2 * MemoryLayout<IndexType>.size
    }
    
    /// Write indices for stitching faces
    geometryPartsList.forEach { part in
        part.contoursList.forEach { contour in
            var indices = Array(repeating: UInt32(0), count: Int(contour.vertices.count * 6))
            for i in 0 ..< contour.vertices.count {
                let i0 = IndexType(i)
                let i1 = IndexType((i + 1) % contour.vertices.count)
                let i2 = IndexType(i + contour.vertices.count)
                let i3 = IndexType((i + 1) % contour.vertices.count + contour.vertices.count)
                
                indices[i * 6 + 0] = i0 + baseVertex
                indices[i * 6 + 1] = i1 + baseVertex
                indices[i * 6 + 2] = i2 + baseVertex
                indices[i * 6 + 3] = i1 + baseVertex
                indices[i * 6 + 4] = i3 + baseVertex
                indices[i * 6 + 5] = i2 + baseVertex
            }
            let indicesData = indices.withUnsafeBytes{ Data($0) }
            indexBuffer.fill(indicesData, offset: offset)
            
            baseVertex += IndexType(contour.vertices.count * 2)
            offset += contour.vertices.count * 6 * MemoryLayout<IndexType>.size
        }
    }
}

