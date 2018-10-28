//
//  SVGMesh.swift
//  Extruded 3D Text & SVG
//
//  Created by Eugene Bokhan on 28/10/2018.
//  Copyright © 2018 Eugene Bokhan. All rights reserved.
//

import MetalKit

import MetalKit

class SVGMesh: MDLMesh {
    
    // MARK: - Life Cycle
    
    init(svgName: String,
         extrusionDepth: CGFloat,
         textureName: String?,
         bufferAllocator: MTKMeshBufferAllocator) {
        // Transform the attributed string to a linked list of glyphs, each with an associated path from the specified font
        var bounds = CGRect.zero
        var geometryParts = SVGMesh.createSVGGeometryParts(from: svgName, imageBounds: &bounds)
        
        // Flatten the paths associated with the glyphs so we can more easily tessellate them in the next step
        flattenPaths(for: &geometryParts)
        // Tessellate the glyphs into contours and actual mesh geometry
        tesselatePaths(for: &geometryParts)
        
        // Figure out how much space we need in our vertex and index buffers to accommodate the mesh
        var vertexCount: UInt32 = 0
        var indexCount: UInt32 = 0
        calculateVertexCount(in: &geometryParts, vertexBufferCount: &vertexCount, indexBufferCount: &indexCount)
        
        // Allocate the vertex and index buffers
        var vertexBuffer = bufferAllocator.newBuffer(MemoryLayout<MeshVertex>.size * Int(vertexCount), type: .vertex)
        var indexBuffer = bufferAllocator.newBuffer(MemoryLayout<IndexType>.size * Int(indexCount), type: .index)
        
        // Write text mesh geometry into the vertex and index buffers
        var vertexBufferOffset = 0
        var indexBufferOffset = 0
        writeVertices(from: &geometryParts,
                              to: &vertexBuffer,
                              bounds: bounds,
                              extrusionDepth: extrusionDepth,
                              offset: &vertexBufferOffset)
        
        writeIndices(from: &geometryParts,
                             to: &indexBuffer,
                             offset: &indexBufferOffset)
        
        // Use ModelIO to create a mesh object, then return a MetalKit mesh we can render later
        var material: MDLMaterial?
        if let textureName = textureName {
            let scatteringFunction = MDLScatteringFunction()
            material = MDLMaterial(name: "baseMaterial", scatteringFunction: scatteringFunction)
            let materialProperty = MDLMaterialProperty(name: "baseMaterial", semantic: .baseColor)
            materialProperty.type = .string
            materialProperty.stringValue = textureName
            material?.setProperty(materialProperty)
        }
        let submesh = MDLSubmesh(indexBuffer: indexBuffer,
                                 indexCount: Int(indexCount),
                                 indexType: .uint32,
                                 geometryType: .triangles,
                                 material: material)
        
        super.init(vertexBuffer: vertexBuffer, vertexCount: Int(vertexCount), descriptor: Model.defaultVertexDescriptor, submeshes: [submesh])
        
        addNormals(withAttributeNamed: MDLVertexAttributeNormal, creaseThreshold: (sqrt(2)/2))
    }
    
    // MARK: - Create Geometry Parts
    
    private static func createSVGGeometryParts(from svg: String, imageBounds: inout CGRect) -> LinkedList<SVGGeometryPart> {
        let geometryPartsList = LinkedList<SVGGeometryPart>()
        
        let svgURL = Bundle.main.url(forResource: svg, withExtension: "svg")!
        let paths = SVGBezierPath.pathsFromSVG(at: svgURL)
        
        imageBounds = SVGBoundingRectForPaths(paths)
        
        for path in paths {
            geometryPartsList.append(SVGGeometryPart(path: path.cgPath))
        }
        
        return geometryPartsList
    }
    
}
