#include "Uniforms.glsl"
#include "Samplers.glsl"
#include "Constants.glsl"
#include "Transform.glsl"

varying vec3 vTexCoord;
varying vec3 LocalPos;

void VS()
{
    mat4 modelMatrix = iModelMatrix;
    vec3 worldPos = GetWorldPos(modelMatrix);
    gl_Position = GetClipPos(worldPos);
    gl_Position.z = gl_Position.w;
    vTexCoord = iPos.xyz;
    LocalPos = iPos.xyz;
}

uniform vec3 cSunPosition;

void PS()
{
    //vec4 sky = cMatDiffColor; // * textureCube(sDiffCubeMap, vTexCoord);
    //#ifdef HDRSCALE
        //sky = pow(sky + clamp((cAmbientColor.a - 1.0) * 0.1, 0.0, 0.25), max(vec4(cAmbientColor.a), 1.0)) * clamp(cAmbientColor.a, 0.0, 1.0);
    //#endif

    //gl_FragColor = sky;

    vec3 V = normalize(LocalPos);
    vec3 L = normalize(cSunPosition);

    // Compute the proximity of this fragment to the sun.

    float vl = dot(V, L);

    // Look up the sky color and glow colors.

	vec2 TCc = vec2(clamp((L.y + 1.0f) / 2.0f, 0.05f, 0.95f), clamp(V.y, 0.05f, 0.95f));
	vec2 TCg = vec2(clamp((L.y + 1.0f) / 2.0f, 0.05f, 0.95f), clamp(vl, 0.05f, 0.95f));

    vec4 Kc = texture2D(sDiffMap, TCc);
    vec4 Kg = texture2D(sSpecMap, TCg);

    // Combine the color and glow giving the pixel value.

	vec4 color = vec4(Kc.rgb + Kg.rgb * Kg.a / 2.0f, Kc.a);
	color = mix(vec4(0.025f, 0.025f, 0.2f, 1.0f), color, color.a);
	//color.a = 1.0f; // remove

    gl_FragColor = color;

}
