#include "Uniforms.glsl"
#include "Samplers.glsl"
#include "Transform.glsl"
#include "ScreenPos.glsl"
#include "Lighting.glsl"
#include "Fog.glsl"

varying vec2 vTexCoord;

#ifndef GL_ES
varying vec2 vDetailTexCoord;
#else
varying mediump vec2 vDetailTexCoord;
#endif

varying vec3 vNormal;
varying vec4 vWorldPos;
#ifdef PERPIXEL
    #ifdef SHADOW
        #ifndef GL_ES
            varying vec4 vShadowPos[NUMCASCADES];
        #else
            varying highp vec4 vShadowPos[NUMCASCADES];
        #endif
    #endif
    #ifdef SPOTLIGHT
        varying vec4 vSpotPos;
    #endif
    #ifdef POINTLIGHT
        varying vec3 vCubeMaskVec;
    #endif
#else
    varying vec3 vVertexLight;
    varying vec4 vScreenPos;
    #ifdef ENVCUBEMAP
        varying vec3 vReflectionVec;
    #endif
    #if defined(LIGHTMAP) || defined(AO)
        varying vec2 vTexCoord2;
    #endif
#endif

varying vec4 vData;

uniform sampler2D sDiffuse0;
uniform sampler2D sDiffuse1;
uniform sampler2D sData2;

#ifndef GL_ES
uniform vec2 cDetailTiling;
uniform float cHeightMapSize;
uniform float cTerrainSpacingXZ;
#else
uniform mediump vec2 cDetailTiling;
uniform mediump float cHeightMapSize;
uniform mediump float cTerrainSpacingXZ;
#endif

void VS()
{
    mat4 modelMatrix = iModelMatrix;
    vec3 worldPos = GetWorldPos(modelMatrix);
    gl_Position = GetClipPos(worldPos);
    vNormal = GetWorldNormal(modelMatrix);
    vWorldPos = vec4(worldPos, GetDepth(gl_Position));
    vTexCoord = GetTexCoord(iTexCoord);
    vDetailTexCoord = cDetailTiling * vTexCoord;

    // Get terrain data from texture
    vec2 TexCoord = vec2(cHeightMapSize * vTexCoord.s, cHeightMapSize * vTexCoord.t);
    vData = texture2D(sData2, TexCoord);
    //~ vData += texelFetch(sData2, clamp(TexCoord + ivec2(-1, -1), ivec2(0), ivec2(Diffuse0Size - 1)), 0);
    //~ vData += texelFetch(sData2, clamp(TexCoord + ivec2(0, -1), ivec2(0), ivec2(Diffuse0Size - 1)), 0);
    //~ vData += texelFetch(sData2, clamp(TexCoord + ivec2(1, -1), ivec2(0), ivec2(Diffuse0Size - 1)), 0);
    //~ vData += texelFetch(sData2, clamp(TexCoord + ivec2(-1, 0), ivec2(0), ivec2(Diffuse0Size - 1)), 0);
    //~ vData += texelFetch(sData2, clamp(TexCoord + ivec2(1, 0), ivec2(0), ivec2(Diffuse0Size - 1)), 0);
    //~ vData += texelFetch(sData2, clamp(TexCoord + ivec2(-1, 1), ivec2(0), ivec2(Diffuse0Size - 1)), 0);
    //~ vData += texelFetch(sData2, clamp(TexCoord + ivec2(0, 1), ivec2(0), ivec2(Diffuse0Size - 1)), 0);
    //~ vData += texelFetch(sData2, clamp(TexCoord + ivec2(1, 1), ivec2(0), ivec2(Diffuse0Size - 1)), 0);
    //~ vData /= 9.0f;

    #ifdef PERPIXEL
        // Per-pixel forward lighting
        vec4 projWorldPos = vec4(worldPos, 1.0);

        #ifdef SHADOW
            // Shadow projection: transform from world space to shadow space
            for (int i = 0; i < NUMCASCADES; i++)
                vShadowPos[i] = GetShadowPos(i, vNormal, projWorldPos);
        #endif

        #ifdef SPOTLIGHT
            // Spotlight projection: transform from world space to projector texture coordinates
            vSpotPos = projWorldPos * cLightMatrices[0];
        #endif

        #ifdef POINTLIGHT
            vCubeMaskVec = (worldPos - cLightPos.xyz) * mat3(cLightMatrices[0][0].xyz, cLightMatrices[0][1].xyz, cLightMatrices[0][2].xyz);
        #endif
    #else
        // Ambient & per-vertex lighting
        #if defined(LIGHTMAP) || defined(AO)
            // If using lightmap, disregard zone ambient light
            // If using AO, calculate ambient in the PS
            vVertexLight = vec3(0.0, 0.0, 0.0);
            vTexCoord2 = iTexCoord1;
        #else
            vVertexLight = GetAmbient(GetZonePos(worldPos));
        #endif

        #ifdef NUMVERTEXLIGHTS
            for (int i = 0; i < NUMVERTEXLIGHTS; ++i)
                vVertexLight += GetVertexLight(i, worldPos, vNormal) * cVertexLights[i * 3].rgb;
        #endif

        vScreenPos = GetScreenPos(gl_Position);

        #ifdef ENVCUBEMAP
            vReflectionVec = worldPos - cCameraPos;
        #endif
    #endif
}

vec4 GetDiffuseBLD2()  // land_data_alpha[01].png, texture7.png
{
    vec3 color = vec3(0.0);
    vec4 blend0 = texture2D(sDiffuse1, vTexCoord);
    vec4 blend1 = texture2D(sData2, vTexCoord);
    vec2 tc_detail = fract(vDetailTexCoord) * 0.25;
    float sum = blend0.r + blend0.g + blend0.b + blend0.a + blend1.r + blend1.g + blend1.b + blend1.a;
    //~ if (sum == 0.0) return vec4(1.0, 0.0, 0.0, 1.0);
    if (blend0.r > 0.0) color += texture2D(sDiffuse0, vec2(0.0, 0.0) + tc_detail).rgb * blend0.r / sum;
    if (blend0.g > 0.0) color += texture2D(sDiffuse0, vec2(0.25, 0.0) + tc_detail).rgb * blend0.g / sum;
    if (blend0.b > 0.0) color += texture2D(sDiffuse0, vec2(0.0, 0.25) + tc_detail).rgb * blend0.b / sum;
    if (blend0.a > 0.0) color += texture2D(sDiffuse0, vec2(0.25, 0.25) + tc_detail).rgb * blend0.a / sum;
    if (blend1.r > 0.0) color += texture2D(sDiffuse0, vec2(0.0, 0.5) + tc_detail).rgb * blend1.r / sum;
    if (blend1.g > 0.0) color += texture2D(sDiffuse0, vec2(0.25, 0.5) + tc_detail).rgb * blend1.g / sum;
    if (blend1.b > 0.0) color += texture2D(sDiffuse0, vec2(0.0, 0.75) + tc_detail).rgb * blend1.b / sum;
    if (blend1.a > 0.0) color += texture2D(sDiffuse0, vec2(0.25, 0.75) + tc_detail).rgb * blend1.a / sum;
    //
    vec4 diffColor = vec4(color, 1.0);
    return diffColor;
}

void PS()
{

    // Get diffuse
    //~ vec4 diffColor = GetDiffuseTHN(data);
    //~ vec4 diffColor = GetDiffuseBLD(data);
    //~ vec4 diffColor0 = GetDiffuseTHN2(vData, vDetailTexCoord);
    //~ vec4 diffColor1 = GetDiffuseTHN2(vData, vDetailTexCoord / 4.0);
    //~ float d = distance(vWorldPos.xyz, cCameraPosPS.xyz);
    //~ vec4 diffColor =  mix(diffColor0, diffColor1, clamp(d / 128.0, 0.0, 1.0));
    //~ vec4 diffColor = texture2D(sDiffuse0, vec2(0.0, 0.75) + fract(vDetailTexCoord) / 4);
    //~ vec4 diffColor = vec4(vec3(vData.x), 1);
    vec4 diffColor = GetDiffuseBLD2();
    //~ gl_FragColor = diffColor;
    //~ return;

    // Get material specular albedo
    vec3 specColor = cMatSpecColor.rgb;

    // Get normal
    vec3 normal = normalize(vNormal);

    // Get fog factor
    #ifdef HEIGHTFOG
        float fogFactor = GetHeightFogFactor(vWorldPos.w, vWorldPos.y);
    #else
        float fogFactor = GetFogFactor(vWorldPos.w);
    #endif

    #if defined(PERPIXEL)
        // Per-pixel forward lighting
        vec3 lightColor;
        vec3 lightDir;
        vec3 finalColor;

        float diff = GetDiffuse(normal, vWorldPos.xyz, lightDir);

        #ifdef SHADOW
            diff *= GetShadow(vShadowPos, vWorldPos.w);
        #endif

        #if defined(SPOTLIGHT)
            lightColor = vSpotPos.w > 0.0 ? texture2DProj(sLightSpotMap, vSpotPos).rgb * cLightColor.rgb : vec3(0.0, 0.0, 0.0);
        #elif defined(CUBEMASK)
            lightColor = textureCube(sLightCubeMap, vCubeMaskVec).rgb * cLightColor.rgb;
        #else
            lightColor = cLightColor.rgb;
        #endif

        #ifdef SPECULAR
            float spec = GetSpecular(normal, cCameraPosPS - vWorldPos.xyz, lightDir, cMatSpecColor.a);
            finalColor = diff * lightColor * (diffColor.rgb + spec * specColor * cLightColor.a);
        #else
            finalColor = diff * lightColor * diffColor.rgb;
        #endif

        #ifdef AMBIENT
            finalColor += cAmbientColor.rgb * diffColor.rgb;
            finalColor += cMatEmissiveColor;
            gl_FragColor = vec4(GetFog(finalColor, fogFactor), diffColor.a);
        #else
            gl_FragColor = vec4(GetLitFog(finalColor, fogFactor), diffColor.a);
        #endif
    #elif defined(PREPASS)
        // Fill light pre-pass G-Buffer
        float specPower = cMatSpecColor.a / 255.0;

        gl_FragData[0] = vec4(normal * 0.5 + 0.5, specPower);
        gl_FragData[1] = vec4(EncodeDepth(vWorldPos.w), 0.0);
    #elif defined(DEFERRED)
        // Fill deferred G-buffer
        float specIntensity = specColor.g;
        float specPower = cMatSpecColor.a / 255.0;

        gl_FragData[0] = vec4(GetFog(vVertexLight * diffColor.rgb, fogFactor), 1.0);
        gl_FragData[1] = fogFactor * vec4(diffColor.rgb, specIntensity);
        gl_FragData[2] = vec4(normal * 0.5 + 0.5, specPower);
        gl_FragData[3] = vec4(EncodeDepth(vWorldPos.w), 0.0);
    #else
        // Ambient & per-vertex lighting
        vec3 finalColor = vVertexLight * diffColor.rgb;

        #ifdef MATERIAL
            // Add light pre-pass accumulation result
            // Lights are accumulated at half intensity. Bring back to full intensity now
            vec4 lightInput = 2.0 * texture2DProj(sLightBuffer, vScreenPos);
            vec3 lightSpecColor = lightInput.a * lightInput.rgb / max(GetIntensity(lightInput.rgb), 0.001);

            finalColor += lightInput.rgb * diffColor.rgb + lightSpecColor * specColor;
        #endif

        gl_FragColor = vec4(GetFog(finalColor, fogFactor), diffColor.a);
    #endif
}
