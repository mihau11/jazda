#version 330

in vec2 fragTexCoord;
in vec4 fragColor;
in vec3 fragNormal;
in vec4 fragPosLightSpace;
in vec4 fragPosLightSpaceFar;
in vec3 fragPosWorld;

uniform sampler2D texture0;
uniform sampler2D shadowMap;
uniform sampler2D shadowMapFar;
uniform vec4 colDiffuse;
uniform vec3 sunDirection; // normalized, points from the surface toward the sun
uniform vec3 sunColor;
uniform vec3 ambientColor;
uniform vec3 viewPos;

const float SpecularStrength = 0.25;
const float Shininess = 16.0;

out vec4 finalColor;

bool InRange(vec3 projCoords)
{
    return projCoords.x >= 0.0 && projCoords.x <= 1.0 &&
           projCoords.y >= 0.0 && projCoords.y <= 1.0 &&
           projCoords.z >= 0.0 && projCoords.z <= 1.0;
}

// Percentage-closer filtering: average the binary in/out occlusion test over
// a 3x3 texel neighborhood so shadow edges are a soft gradient instead of a
// single hard step.
float SampleCascade(sampler2D map, vec3 projCoords, float bias)
{
    vec2 texelSize = 1.0 / vec2(textureSize(map, 0));
    float occluded = 0.0;
    for (int x = -1; x <= 1; x++)
    {
        for (int y = -1; y <= 1; y++)
        {
            float closestDepth = texture(map, projCoords.xy + vec2(x, y) * texelSize).r;
            if (projCoords.z - bias > closestDepth) occluded += 1.0;
        }
    }
    return occluded / 9.0;
}

// The light frustum re-centers on the player every frame, so a fragment
// crossing the [0,1] boundary would otherwise pop instantly between
// shadowed and lit. Fade the last 12% of each axis toward "lit" instead of
// cutting off sharply.
float EdgeFade(vec3 projCoords)
{
    vec3 edgeDist = min(projCoords, 1.0 - projCoords);
    return smoothstep(0.0, 0.12, min(edgeDist.x, min(edgeDist.y, edgeDist.z)));
}

// Fraction (0..1) of this fragment that's occluded from the sun. Tries the
// tight, high-resolution near cascade first (sharper shadows close to the
// player); if the fragment falls outside that cascade's coverage, falls
// back to the larger, lower-resolution far cascade so distant terrain still
// gets shadowed instead of just going unshadowed past the near cutoff.
float ShadowFactor(vec3 normal)
{
    float bias = max(0.0015 * (1.0 - dot(normal, sunDirection)), 0.0004);

    vec3 nearCoords = fragPosLightSpace.xyz / fragPosLightSpace.w * 0.5 + 0.5;
    if (InRange(nearCoords))
        return SampleCascade(shadowMap, nearCoords, bias) * EdgeFade(nearCoords);

    vec3 farCoords = fragPosLightSpaceFar.xyz / fragPosLightSpaceFar.w * 0.5 + 0.5;
    if (InRange(farCoords))
        return SampleCascade(shadowMapFar, farCoords, bias) * EdgeFade(farCoords);

    return 0.0;
}

void main()
{
    vec3 n = normalize(fragNormal);
    float diff = max(dot(n, sunDirection), 0.0);
    float shadow = diff > 0.0 ? ShadowFactor(n) : 0.0;
    float lit = 1.0 - shadow;

    vec3 viewDir = normalize(viewPos - fragPosWorld);
    vec3 halfwayDir = normalize(sunDirection + viewDir);
    float spec = diff > 0.0 ? pow(max(dot(n, halfwayDir), 0.0), Shininess) : 0.0;

    vec3 lighting = ambientColor + sunColor * (diff + spec * SpecularStrength) * lit;

    vec4 texel = texture(texture0, fragTexCoord);
    finalColor = vec4(texel.rgb * fragColor.rgb * lighting, texel.a * fragColor.a) * colDiffuse;
}
