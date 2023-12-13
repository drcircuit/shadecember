#version 300 es
precision mediump float;
#define PI 3.1415926535897932384626433832795
uniform vec2 u_resolution;
uniform float u_time;
uniform sampler2D u_texture;
uniform sampler2D u_fftTexture;
uniform samplerCube u_env;
out vec4 fragColor;

mat2 rotate2d(float _angle){
    return mat2(cos(_angle), -sin(_angle),
    sin(_angle), cos(_angle));
}   
vec4 blurEnv(vec3 reflectDir, vec3 normal, float amount){
    vec4 blurredReflection = vec4(0.0);
    float totalSamples = 0.0;

    for (float phi = 0.0; phi < 2.0 * PI; phi += PI / 20.0) { // Adjust for more samples if needed
        for (float theta = 0.0; theta < PI; theta += PI / 20.0) {
            vec3 sampleDir = normalize(reflectDir + amount * (cos(phi) * normal + sin(phi) * cross(normal, reflectDir)) * sin(theta));
            blurredReflection += texture(u_env, sampleDir);
            totalSamples += 1.0;
        }
    }
    return blurredReflection / totalSamples;
}
vec3 rotate3d(vec3 v, vec3 axis, float angle) {
    float s = sin(angle);
    float c = cos(angle);
    float oc = 1.0 - c;
    return vec3(oc * axis.x * axis.x + c, oc * axis.x * axis.y - axis.z * s, oc * axis.z * axis.x + axis.y * s) * v.x +
    vec3(oc * axis.x * axis.y + axis.z * s, oc * axis.y * axis.y + c, oc * axis.y * axis.z - axis.x * s) * v.y +
    vec3(oc * axis.z * axis.x - axis.y * s, oc * axis.y * axis.z + axis.x * s, oc * axis.z * axis.z + c) * v.z;
}

vec4 calculateReflection(vec2 uv, vec3 cameraPos, float sphereRadius, float rotation, vec3 axis, float blur) {
    vec2 center = vec2(0.5, 0.5);
    vec3 sphereCenter = vec3(center, 0);
    vec3 toPoint = vec3(uv - center, 0.0);
    vec3 viewDir = normalize(cameraPos - sphereCenter - toPoint);
    viewDir = rotate3d(viewDir, axis, rotation);
    vec3 domeNormal = normalize(toPoint + vec3(0.0, 0.0, sphereRadius));
    vec3 reflectDir = reflect(viewDir, domeNormal);
    float fresnel = pow(1.0 - dot(viewDir, domeNormal), 3.0);
    vec4 envRef = blurEnv(reflectDir, domeNormal,blur);
    float fade = smoothstep(0.0, 0.25, length(uv - center));
    float fade2 = 1.0 - smoothstep(0.2, 0.30, length(uv - center));
    envRef *= fresnel * fade;
    envRef *= envRef; // Enhance the effect by squaring the result
    return envRef * fade * fade2;
}

float smoothCircle(vec2 uv, vec2 center, float radius, float edgeWidth) {
    float dist = distance(uv, center);
    return smoothstep(radius - edgeWidth, radius + edgeWidth, dist);
}

vec4 calculateBezel(vec2 uv, vec3 cameraPos, vec3 lightDir, vec3 axis, float rotation) {
    vec2 center = vec2(0.5, 0.5);
    float distFromCenter = length(uv - center);
    vec3 viewDir = normalize(cameraPos - vec3(uv, 0.0));
    viewDir = rotate3d(viewDir, axis, rotation);
    // Sharp bevel parameters
    float innerBevelStart = 0.3; // Start of the inner bevel
    float innerBevelEnd = 0.31; // End of the inner bevel (sharp transition)
    float outerBevelStart = 0.34; // Start of the outer bevel (sharp transition)
    float outerBevelEnd = 0.35; // End of the outer bevel
    float innerRadius = 0.3; // Inner radius of the bezel
    float edgeWidth = 0.005; // Width for smoothing, smaller value for a sharper edge

    float outerRadius = 0.34; // Outer radius of the bezel
    float innerEdge = smoothCircle(uv, center, innerRadius, edgeWidth);
    float outerEdge = 1.0 - smoothCircle(uv, center, outerRadius, edgeWidth);
    float bezelMask = innerEdge * outerEdge;
    float bevelMask = smoothstep(innerBevelStart, innerBevelEnd, distFromCenter) *
    (1. - smoothstep(outerBevelStart, outerBevelEnd, distFromCenter));

    // Calculate sharper bevel normals for lighting and reflection
    float bevelFactor = step(innerBevelEnd, distFromCenter) * step(distFromCenter, outerBevelStart);
    vec3 flatNormal = vec3(0.0, 0.0, 1.0); // Normal for flat parts
    vec3 bevelNormal = mix(flatNormal, normalize(vec3(uv - center, bevelFactor * 0.1)), bevelMask);

    // Rotate normals for conical reflection effect
    bevelNormal = rotate3d(bevelNormal, axis, .2);

    // Apply lighting to the bezel
    float lightIntensity = max(dot(bevelNormal, lightDir), 0.0);

    // Calculate shadow based on light
    float shadow = 1.0 - smoothstep(0.0, 0.21, lightIntensity);
    // Sample the environment map for reflection
    vec3 reflectDir = reflect(-viewDir, bevelNormal);
    vec4 reflectedColor = blurEnv(reflectDir, bevelNormal, 0.2);
    // Combine lighting and reflection
    vec4 bezelColor = mix(vec4(0.1, 0.1, 0.12, .40), reflectedColor, lightIntensity);
    bezelColor.rgb -=shadow*.1;
    bezelColor.a =.8;

    // Apply the bevel mask
    return mix(vec4(0.0), bezelColor, bevelMask);
}

void main() {
    // normalize uv to be between 0 and 1  
    float bass = texture(u_fftTexture, vec2(0.0, 0.0)).r;
    float t = mod(u_time * 0.0001, PI * 2.0)    ;
    vec2 uv = gl_FragCoord.xy / u_resolution.xy;
    vec2 uv2 = uv;    
    // glass dome distortion
    vec2 center = vec2(0.5, 0.5);
    float domeRadius = 2.5; 
    uv2.xy *= rotate2d(.02);

    // Layer 1 Reflection
    vec3 layer1CameraPos = vec3(0.5,0.5, .001);  // Adjust as needed

    float layer1SphereRadius = .43;  // Adjust as needed
    float rotation = t;
    vec4 layer1Reflection = calculateReflection(uv2, layer1CameraPos, layer1SphereRadius, rotation, vec3(0.0, 1.0, 0.0), 0.1);

    // Layer 2 Reflection
    vec3 layer2CameraPos = vec3(0.5, 0.5, .2);  // Adjust as needed
    float layer2SphereRadius = .35;  // Adjust as needed
    vec4 layer2Reflection = calculateReflection(uv2, layer2CameraPos, layer2SphereRadius, rotation, vec3(0.0, 1.0, 0.0),0.3);
    vec4 sharp = layer1Reflection;
    layer1Reflection = clamp(layer1Reflection, 0.0, 1.0);
    layer2Reflection = clamp(layer2Reflection, 0.0, 1.0);
    vec4 envRef = layer2Reflection*0.4 + layer1Reflection*0.6;
    
    float domeDist = distance(uv, center);
    // Apply distortion
    float distortion = .5 * pow(1.0 - domeDist / domeRadius, 2.0);
    vec2 domeUV = mix(uv, center, distortion);
    
    // Sample texture and apply environment reflection
    vec4 color = texture(u_texture, domeUV); 

    // Define the light direction

    // Calculate the distance from the center of the sphere to the current fragment
    float distFromCenter = length(uv - center);
    envRef = clamp(envRef, 0.0, 1.0);
    color += envRef * (1./distFromCenter) * .02;
    
    float mask = smoothstep(0.1, .3, distFromCenter);
    sharp.rgb *= mask;
    color += .5*clamp(0.01*sharp, 0., 1.0) * (distFromCenter);

    // Define parameters for the bezel
    float innerRadius = 0.3;  // Inner radius of the bezel
    float outerRadius = 0.34; // Outer radius of the bezel
    float bevelAmount = 0.0; // Amount of bevel
    vec3 lightDir = normalize(vec3(1.0, 1.0, 1.0)); // Direction of the light affecting the bezel
    lightDir = rotate3d(lightDir, vec3(0.0, 1.0, 0.0), rotation);
    vec3 rotationAxis = vec3(0.0, 0.0, 1.0); // Axis for rotating the bevel normal

    // Calculate bezel with sharper bevel and conical reflection
    vec4 bezel = calculateBezel(uv2, layer1CameraPos, lightDir, rotationAxis, rotation);

    float mask2 = smoothstep(0.1, .5, distFromCenter);
    // Combine bezel with existing color
    color = mix(color, bezel, bezel.a*.95);
    color = mix(color, vec4(vec3(0), 1.0), mask2);
    fragColor = color;   
}
