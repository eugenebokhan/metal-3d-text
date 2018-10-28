//
//  Renderer.swift
//  Extruded 3D Text & SVG
//
//  Created by Eugene Bokhan on 28/10/2018.
//  Copyright © 2018 Eugene Bokhan. All rights reserved.
//

import MetalKit

class Renderer: NSObject {
    
    // MARK: - Properties
    
    static var device: MTLDevice!
    static var commandQueue: MTLCommandQueue!
    static var colorPixelFormat: MTLPixelFormat!
    static var library: MTLLibrary?
    var depthStencilState: MTLDepthStencilState!
    
    var uniforms = Uniforms()
    var fragmentUniforms = FragmentUniforms()
    
    lazy var camera: Camera = {
        let camera = Camera()
        camera.position = [0, 1.2, -40]
        return camera
    }()
    
    var models: [Model] = []
    
    lazy var sunlight: Light = {
        var light = buildDefaultLight()
        light.position = [1, 2, -2]
        return light
    }()
    
    var lights: [Light] = []
    
    // MARK: - Life Cycle
    
    init(metalView: MTKView) {
        guard let device = MTLCreateSystemDefaultDevice() else {
            fatalError("GPU not available")
        }
        metalView.depthStencilPixelFormat = .depth32Float
        metalView.device = device
        Renderer.device = device
        Renderer.commandQueue = device.makeCommandQueue()!
        Renderer.colorPixelFormat = metalView.colorPixelFormat
        Renderer.library = device.makeDefaultLibrary()
        
        super.init()
        metalView.clearColor = MTLClearColor(red: 0.8, green: 0.8,
                                             blue: 0.8, alpha: 1)
        metalView.delegate = self
        mtkView(metalView, drawableSizeWillChange: metalView.bounds.size)
        
        /// Models
        let font = CTFontCreateWithName("HoeflerText-Black" as CFString, 72, nil)
        let text = Model(string: "Iceland", font: font, extrusionDepth: 16, textureName: "wood")
        text.position = [0, 8, 0]
        text.scale = [0.08, 0.08, 0.08]
        models.append(text)
        
        let svgModel = Model(svgName: "iceland", extrusionDepth: 16, textureName: "ice")
        svgModel.position = [-14, 6, 0]
        svgModel.rotation = [radians(fromDegrees: -180), 0, 0]
        svgModel.scale = [0.05, 0.05, 0.05]
        models.append(svgModel)
        
        buildDepthStencilState()
        
        /// lights
        lights.append(sunlight)
        fragmentUniforms.lightCount = UInt32(lights.count)
    }
    
    // MARK: - Helpers
    
    func buildDefaultLight() -> Light {
        var light = Light()
        light.position = [0, 0, 0]
        light.color = [1, 1, 1]
        light.specularColor = [0.6, 0.6, 0.6]
        light.intensity = 1
        light.attenuation = float3(1, 0, 0)
        light.type = Sunlight
        return light
    }
    
    func buildDepthStencilState() {
        let descriptor = MTLDepthStencilDescriptor()
        descriptor.depthCompareFunction = .less
        descriptor.isDepthWriteEnabled = true
        depthStencilState =
            Renderer.device.makeDepthStencilState(descriptor: descriptor)
    }
    
}

extension Renderer: MTKViewDelegate {
    func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {
        camera.aspect = Float(view.bounds.width)/Float(view.bounds.height)
    }
    
    func draw(in view: MTKView) {
        guard let descriptor = view.currentRenderPassDescriptor,
            let commandBuffer = Renderer.commandQueue.makeCommandBuffer(),
            let renderEncoder =
            commandBuffer.makeRenderCommandEncoder(descriptor: descriptor) else {
                return
        }
        renderEncoder.setDepthStencilState(depthStencilState)
        
        fragmentUniforms.cameraPosition = camera.position
        uniforms.projectionMatrix = camera.projectionMatrix
        uniforms.viewMatrix = camera.viewMatrix
        
        renderEncoder.setFragmentBytes(&lights,
                                       length: MemoryLayout<Light>.stride * lights.count,
                                       index: Int(BufferIndexLights.rawValue))
        
        for model in models {
            
            // add tiling here
            fragmentUniforms.tiling = model.tiling
            renderEncoder.setFragmentBytes(&fragmentUniforms,
                                           length: MemoryLayout<FragmentUniforms>.stride,
                                           index: Int(BufferIndexFragmentUniforms.rawValue))
            
            uniforms.modelMatrix = model.modelMatrix
            uniforms.normalMatrix = float3x3(normalFrom4x4: model.modelMatrix)
            
            renderEncoder.setVertexBytes(&uniforms,
                                         length: MemoryLayout<Uniforms>.stride,
                                         index: Int(BufferIndexUniforms.rawValue))
            
            renderEncoder.setRenderPipelineState(model.pipelineState)
            renderEncoder.setVertexBuffer(model.vertexBuffer, offset: 0,
                                          index: Int(BufferIndexVertices.rawValue))
            
            for modelSubmesh in model.submeshes {
                renderEncoder.setFragmentSamplerState(model.samplerState, index: 0)
                
                // set the fragment texture here
                renderEncoder.setFragmentTexture(modelSubmesh.textures.baseColor,
                                                 index: Int(BaseColorTexture.rawValue))
                
                let submesh = modelSubmesh.submesh
                renderEncoder.drawIndexedPrimitives(type: .triangle,
                                                    indexCount: submesh.indexCount,
                                                    indexType: submesh.indexType,
                                                    indexBuffer: submesh.indexBuffer.buffer,
                                                    indexBufferOffset: submesh.indexBuffer.offset)
            }
        }
        
        renderEncoder.endEncoding()
        guard let drawable = view.currentDrawable else {
            return
        }
        commandBuffer.present(drawable)
        commandBuffer.commit()
    }
}


