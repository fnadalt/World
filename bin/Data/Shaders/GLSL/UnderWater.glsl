#include "Uniforms.glsl"
#include "Samplers.glsl"
#include "Transform.glsl"
#include "ScreenPos.glsl"
#include "Lighting.glsl"

varying vec4 vWorldPos;
varying vec2 vTexCoord;
varying vec2 vScreenPosPreDiv;
varying vec4 vScreenPos;

#ifdef COMPILEPS
uniform float cElapsedTime;
uniform float cOceanAltitude;
#endif

void VS()
{
    mat4 modelMatrix = iModelMatrix;
    vec3 worldPos = GetWorldPos(modelMatrix);
    gl_Position = GetClipPos(worldPos);
    vWorldPos = vec4(worldPos, GetDepth(gl_Position));
    vTexCoord = GetQuadTexCoord(gl_Position);
    vScreenPosPreDiv = GetScreenPosPreDiv(gl_Position);
    vScreenPos = GetScreenPos(gl_Position);

}

void PS()
{

    #ifdef VELO
    if (cCameraPosPS.y < cOceanAltitude) {
        gl_FragColor = vec4(0.0, 0.0, 0.6, 1.0);
    } else {
        gl_FragColor = vec4(1.0, 1.0, 1.0, 1.0);
    }
    //~ gl_FragColor = vec4(vec3(cOceanAltitude / 255), 1.0);
    #endif

    #ifdef COMBINE
    vec3 original = texture2D(sDiffMap, vScreenPosPreDiv).rgb;
    vec3 screen = texture2D(sNormalMap, vTexCoord).rgb;
    // Prevent oversaturation
    gl_FragColor = vec4((original + screen) * 0.5, 1.0);
    #endif

    #ifdef NOISEDEFORM
    //~ if (cCameraPosPS.y < cOceanAltitude)  // shouldn't exist, use effect activation.
    {
        //
        vec2 tc_time_offset = vec2(0.05, 0.05) * cElapsedTime;
        float noise = texture2D(sNormalMap, vScreenPosPreDiv + tc_time_offset).r;
        vec2 tc_noise_offset = vec2(cos(noise), sin(noise)) * 0.05;
        vec3 vpColor = texture2D(sDiffMap, vScreenPosPreDiv + tc_noise_offset).rgb;
        #ifdef HWDEPTH
            float depth = ReconstructDepth(texture2DProj(sDepthBuffer, vScreenPos).r) ;
        #else
            float depth = DecodeDepth(texture2DProj(sDepthBuffer, vScreenPos).rgb);
        #endif
        vec3 wavesColor = texture2DProj(sEmissiveMap, vec3(vScreenPosPreDiv, 1.0 - depth)).rgb;
        gl_FragColor = vec4(vpColor, 1.0);  // vec4(vpColor * wavesColor, 1.0);
    }
    #endif

}
