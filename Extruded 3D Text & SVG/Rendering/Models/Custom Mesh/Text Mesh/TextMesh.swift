//
//  TextMesh.swift
//  Extruded 3D Text & SVG
//
//  Created by Eugene Bokhan on 28/10/2018.
//  Copyright © 2018 Eugene Bokhan. All rights reserved.
//

import MetalKit

class TextMesh: MDLMesh {
    
    // MARK: - Life Cycle
    
    init(string: String,
         font: CTFont,
         extrusionDepth: CGFloat,
         textureName: String?,
         bufferAllocator: MDLMeshBufferAllocator) {
        /// Create an attributed string from the provided text; we make our own attributed string
        /// to ensure that the entire mesh has a single style, which simplifies things greatly.
        let cfString = string as CFString
        let attributes = [ NSAttributedString.Key.font : font ] as CFDictionary
        let attributedString = CFAttributedStringCreate(nil, cfString, attributes)
        
        /// Transform the attributed string to a linked list of glyphs, each with an associated path from the specified font
        var bounds = CGRect.zero
        var glyphsList = TextMesh.createGlyphs(for: attributedString!, imageBounds: &bounds)
        
        /// Flatten the paths associated with the glyphs so we can more easily tessellate them in the next step
        flattenPaths(for: &glyphsList)
        // Tessellate the glyphs into contours and actual mesh geometry
        tesselatePaths(for: &glyphsList)
        
        /// Figure out how much space we need in our vertex and index buffers to accommodate the mesh
        var vertexCount: UInt32 = 0
        var indexCount: UInt32 = 0
        calculateVertexCount(in: &glyphsList, vertexBufferCount: &vertexCount, indexBufferCount: &indexCount)
        
        var vertexBuffer = bufferAllocator.newBuffer(MemoryLayout<MeshVertex>.size * Int(vertexCount), type: .vertex)
        var indexBuffer = bufferAllocator.newBuffer(MemoryLayout<IndexType>.size * Int(indexCount), type: .index)
        
        /// Write text mesh geometry into the vertex and index buffers
        var vertexBufferOffset = 0
        var indexBufferOffset = 0
        writeVertices(from: &glyphsList,
                               to: &vertexBuffer,
                               bounds: bounds,
                               extrusionDepth: extrusionDepth,
                               offset: &vertexBufferOffset)
        
        writeIndices(from: &glyphsList,
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
    
    private static func createGlyphs(for attributedString: CFAttributedString, imageBounds: inout CGRect) -> LinkedList<Glyph> {
        let glyphsList = LinkedList<Glyph>()
        
        /// Create a typesetter and use it to lay out a single line of text
        let typesetter = CTTypesetterCreateWithAttributedString(attributedString)
        let line = CTTypesetterCreateLine(typesetter, CFRange(location: 0, length: 0))
        let runs = CTLineGetGlyphRuns(line) as NSArray
        
        /// For each of the runs, of which there should only be one...
        for runIndex in 0 ..< CFArrayGetCount(runs) {
            let run = runs[runIndex] as! CTRun
            let glyphCount = CTRunGetGlyphCount(run)
            
            /// Retrieve the list of glyph positions so we know how to transform the paths we get from the font
            var glyphPositions = Array<CGPoint>(repeating: CGPoint.zero, count: glyphCount)
            CTRunGetPositions(run, CFRangeMake(0, 0), &glyphPositions)
            
            // Retrieve the bounds of the text, so we can crudely center it
            var bounds = CTRunGetImageBounds(run, nil, CFRangeMake(0, 0))
            bounds.origin.x -= bounds.size.width / 2
            imageBounds = bounds
            
            var glyphs = Array<CGGlyph>(repeating: CGGlyph(), count: glyphCount)
            CTRunGetGlyphs(run, CFRangeMake(0, 0), &glyphs)
            
            /// Fetch the font from the current run. We could have taken this as a parameter, but this is more future-proof.
            let runAttributes = CTRunGetAttributes(run) as NSDictionary
            let key = NSAttributedString.Key.font
            let font = runAttributes[key] as! CTFont
            
            /// For each glyph in the run...
            for glyphIdx in 0 ..< glyphCount {
                // Compute a transform that will position the glyph correctly relative to the others, accounting for centering
                let glyphPosition = glyphPositions[glyphIdx]
                var glyphTransform = CGAffineTransform(translationX: glyphPosition.x - bounds.size.width / 2,
                                                       y: glyphPosition.y)
                
                /// Retrieve the actual path for this glyph from the font
                if let path = CTFontCreatePathForGlyph(font, glyphs[glyphIdx], &glyphTransform) {
                    // Add the glyph to the list of glyphs, creating the list if this is the first glyph
                    glyphsList.append(Glyph(path: path))
                }
            }
            
        }
        
        return glyphsList
    }
    
}
