//
//  Model.swift
//  Extruded 3D Text & SVG
//
//  Created by Eugene Bokhan on 28/10/2018.
//  Copyright © 2018 Eugene Bokhan. All rights reserved.
//

import MetalKit

class Model: Node {
    
    // MARK: - Properties
    
    static var defaultVertexDescriptor: MDLVertexDescriptor = {
        let vertexDescriptor = MDLVertexDescriptor()
        vertexDescriptor.attributes[Int(Position.rawValue)] =
            MDLVertexAttribute(name: MDLVertexAttributePosition,
                               format: .float3,
                               offset: 0, bufferIndex: 0)
        vertexDescriptor.attributes[Int(Normal.rawValue)] =
            MDLVertexAttribute(name: MDLVertexAttributeNormal,
                               format: .float3,
                               offset: 12, bufferIndex: 0)
        vertexDescriptor.attributes[Int(UV.rawValue)] =
            MDLVertexAttribute(name: MDLVertexAttributeTextureCoordinate,
                               format: .float2,
                               offset: 24, bufferIndex: 0)
        
        // add the texture attribute here
        
        vertexDescriptor.layouts[0] = MDLVertexBufferLayout(stride: 32)
        return vertexDescriptor
    }()
    
    let vertexBuffer: MTLBuffer
    let mesh: MTKMesh
    let pipelineState: MTLRenderPipelineState
    let submeshes: [Submesh]
    var tiling: UInt32 = 1
    let samplerState: MTLSamplerState?
    
    // MARK: - Life Cycle
    
    /// OBJ Mesh Init
    
    init(name: String) {
        let assetURL = Bundle.main.url(forResource: name, withExtension: "obj")!
        let allocator = MTKMeshBufferAllocator(device: Renderer.device)
        let asset = MDLAsset(url: assetURL, vertexDescriptor: Model.defaultVertexDescriptor,
                             bufferAllocator: allocator)
        let mdlMesh = asset.object(at: 0) as! MDLMesh
        
        let mesh = try! MTKMesh(mesh: mdlMesh, device: Renderer.device)
        self.mesh = mesh
        vertexBuffer = mesh.vertexBuffers[0].buffer
        
        submeshes = mdlMesh.submeshes?.enumerated().compactMap { index, submesh in
            (submesh as? MDLSubmesh).map { Submesh(submesh: mesh.submeshes[index], mdlSubmesh: $0) }
            }
            ?? []
        
        pipelineState = Model.buildPipelineState(vertexDescriptor: mdlMesh.vertexDescriptor)
        samplerState = Model.buildSamplerState()
        
        super.init()
        
    }
    
    // Text Mesh Init
    
    public init(string: String,
                font: CTFont,
                extrusionDepth: CGFloat,
                textureName: String?) {
        let bufferAllocator = MTKMeshBufferAllocator(device: Renderer.device)
        
        let mdlMesh = TextMesh(string: string,
                               font: font,
                               extrusionDepth: extrusionDepth,
                               textureName: textureName,
                               bufferAllocator: bufferAllocator)
        let mesh = try! MTKMesh(mesh: mdlMesh,
                                device: Renderer.device)
        self.mesh = mesh
        self.vertexBuffer = mesh.vertexBuffers[0].buffer
        
        submeshes = mdlMesh.submeshes?.enumerated().compactMap {index, submesh in
            (submesh as? MDLSubmesh).map {
                Submesh(submesh: mesh.submeshes[index],
                        mdlSubmesh: $0)
            }
            }
            ?? []
        
        pipelineState = Model.buildPipelineState(vertexDescriptor: mdlMesh.vertexDescriptor)
        samplerState = Model.buildSamplerState()
        
        super.init()
    }
    
    /// SVG Mesh Init
    
    public init(svgName: String,
                extrusionDepth: CGFloat,
                textureName: String?) {
        let bufferAllocator = MTKMeshBufferAllocator(device: Renderer.device)
        
        let mdlMesh = SVGMesh(svgName: svgName,
                              extrusionDepth: extrusionDepth,
                              textureName: textureName,
                              bufferAllocator: bufferAllocator)
        let mesh = try! MTKMesh(mesh: mdlMesh,
                                device: Renderer.device)
        self.mesh = mesh
        self.vertexBuffer = mesh.vertexBuffers[0].buffer
        
        submeshes = mdlMesh.submeshes?.enumerated().compactMap {index, submesh in
            (submesh as? MDLSubmesh).map {
                Submesh(submesh: mesh.submeshes[index],
                        mdlSubmesh: $0)
            }
            }
            ?? []
        
        pipelineState = Model.buildPipelineState(vertexDescriptor: mdlMesh.vertexDescriptor)
        samplerState = Model.buildSamplerState()
        
        super.init()
    }
    
    // MARK: - Helpers
    
    private static func buildPipelineState(vertexDescriptor: MDLVertexDescriptor) -> MTLRenderPipelineState {
        let library = Renderer.library
        let vertexFunction = library?.makeFunction(name: "vertex_main")
        let fragmentFunction = library?.makeFunction(name: "fragment_main")
        
        var pipelineState: MTLRenderPipelineState
        let pipelineDescriptor = MTLRenderPipelineDescriptor()
        pipelineDescriptor.vertexFunction = vertexFunction
        pipelineDescriptor.fragmentFunction = fragmentFunction
        pipelineDescriptor.vertexDescriptor = MTKMetalVertexDescriptorFromModelIO(vertexDescriptor)
        pipelineDescriptor.colorAttachments[0].pixelFormat = Renderer.colorPixelFormat
        pipelineDescriptor.depthAttachmentPixelFormat = .depth32Float
        do {
            pipelineState = try Renderer.device.makeRenderPipelineState(descriptor: pipelineDescriptor)
        } catch let error {
            fatalError(error.localizedDescription)
        }
        return pipelineState
    }
    
    private static func buildSamplerState() -> MTLSamplerState? {
        let descriptor = MTLSamplerDescriptor()
        descriptor.sAddressMode = .repeat
        descriptor.tAddressMode = .repeat
        descriptor.mipFilter = .linear
        descriptor.maxAnisotropy = 8
        let samplerState =
            Renderer.device.makeSamplerState(descriptor: descriptor)
        return samplerState
    }
    
}



