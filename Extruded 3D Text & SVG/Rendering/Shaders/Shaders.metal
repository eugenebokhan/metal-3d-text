//
//  Shaders.metal
//  Extruded 3D Text & SVG
//
//  Created by Eugene Bokhan on 28/10/2018.
//  Copyright © 2018 Eugene Bokhan. All rights reserved.
//

#include <metal_stdlib>
using namespace metal;
#import "MetalShaderStructures.h"

struct VertexIn {
    float4 position [[ attribute(Position) ]];
    float3 normal [[ attribute(Normal) ]];
    float2 uv [[ attribute(UV) ]];
};

struct VertexOut {
    float4 position [[ position ]];
    float3 worldPosition;
    float3 worldNormal;
    float2 uv;
};

vertex VertexOut vertex_main(const VertexIn vertexIn [[ stage_in ]],
                             constant Uniforms &uniforms [[ buffer(BufferIndexUniforms) ]])
{
    VertexOut out;
    out.position = uniforms.projectionMatrix * uniforms.viewMatrix
    * uniforms.modelMatrix * vertexIn.position;
    out.worldPosition = (uniforms.modelMatrix * vertexIn.position).xyz;
    out.worldNormal = uniforms.normalMatrix * vertexIn.normal;
    out.uv = vertexIn.uv;
    
    return out;
}

fragment float4 fragment_main(VertexOut in [[stage_in]],
                              texture2d<float> baseColorTexture [[ texture(BaseColorTexture)]],
                              sampler textureSampler [[sampler(0)]],
                              constant Light *lights [[buffer(BufferIndexLights)]],
                              constant FragmentUniforms &fragmentUniforms [[ buffer(BufferIndexFragmentUniforms)]]) {
    float3 baseColor = baseColorTexture.sample(textureSampler,
                                               in.uv * fragmentUniforms.tiling).rgb;
    return float4(baseColor, 1);
    float3 diffuseColor = 0;
    float3 ambientColor = 0;
    float3 specularColor = 0;
    float materialShininess = 32;
    float3 materialSpecularColor = float3(1, 1, 1);
    float3 normalDirection = normalize(in.worldNormal);
    
    for (uint i = 0; i < fragmentUniforms.lightCount; i++) {
        Light light = lights[i];
        if (light.type == Sunlight) {
            float3 lightDirection = normalize(light.position);
            float diffuseIntensity =
            saturate(dot(lightDirection, normalDirection));
            diffuseColor += light.color * baseColor * diffuseIntensity;
            if (diffuseIntensity > 0) {
                float3 reflection = reflect(lightDirection, normalDirection); // (R)
                float3 cameraPosition = normalize(in.worldPosition - fragmentUniforms.cameraPosition); // (V)
                float specularIntensity = pow(saturate(dot(reflection, cameraPosition)), materialShininess);
                specularColor += light.specularColor * materialSpecularColor * specularIntensity;
            }
        } else if (light.type == Ambientlight) {
            ambientColor += light.color * light.intensity;
        } else if (light.type == Pointlight) {
            float d = distance(light.position, in.worldPosition);
            float3 lightDirection = normalize(light.position - in.worldPosition);
            float attenuation = 1.0 / (light.attenuation.x +
                                       light.attenuation.y * d + light.attenuation.z * d * d);
            
            float diffuseIntensity = saturate(dot(lightDirection, normalDirection));
            float3 color = light.color * baseColor * diffuseIntensity;
            color *= attenuation;
            diffuseColor += color;
        } else if (light.type == Spotlight) {
            float d = distance(light.position, in.worldPosition);
            float3 lightDirection = normalize(light.position - in.worldPosition);
            float3 coneDirection = normalize(-light.coneDirection);
            float spotResult = (dot(lightDirection, coneDirection));
            if (spotResult > cos(light.coneAngle)) {
                float attenuation = 1.0 / (light.attenuation.x +
                                           light.attenuation.y * d + light.attenuation.z * d * d);
                attenuation *= pow(spotResult, light.coneAttenuation);
                float diffuseIntensity = saturate(dot(lightDirection, normalDirection));
                float3 color = light.color * baseColor * diffuseIntensity;
                color *= attenuation;
                diffuseColor += color;
            }
        }
    }
    float3 color = diffuseColor + ambientColor + specularColor;
    return float4(color, 1);
}



