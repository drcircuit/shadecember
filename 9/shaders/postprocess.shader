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
void main() {
    // normalize uv to be between 0 and 1  
    float bass = texture(u_fftTexture, vec2(0.0, 0.0)).r;
    float t = u_time * 0.0001;
    vec2 uv = gl_FragCoord.xy / u_resolution.xy;
    vec2 uv2 = uv;    
    // glass dome distortion
    vec2 center = vec2(0.5, 0.5);
    float domeRadius = 2.5; 
    float sphereRadius =.5;
    vec3 u_cameraPos = vec3(0.45, 0.5, .2)  ;
    uv2.xy *= rotate2d(.02);
    vec3 viewDir = normalize(u_cameraPos - vec3(uv2, 0.0));
    vec3 sphereCenter = vec3(center, 0.0);
    float intersection = dot(sphereCenter - u_cameraPos, viewDir);
    vec3 onSphere = u_cameraPos + intersection * viewDir;
    vec3 domeNormal = normalize(vec3(uv - center, sqrt(max(0.0, sphereRadius * sphereRadius - dot(uv - center, uv - center)))));
    vec3 reflectDir = reflect(-viewDir, domeNormal);
    float fresnel = pow(1.0 - dot(viewDir, domeNormal), 3.0);
    vec4 envRef = blurEnv(reflectDir, domeNormal, .05);
    float fade = 1.0 - smoothstep(0.3, .34, length(uv2 - center));
    envRef *= fresnel * fade;
    envRef *= envRef;
    float domeDist = distance(uv, center);
    // Apply distortion
    float distortion = .5 * pow(1.0 - domeDist / domeRadius, 2.0);
    vec2 domeUV = mix(uv, center, distortion);
    
    // Sample texture and apply environment reflection
    vec4 color = texture(u_texture, domeUV); 
    color += envRef;
    
    fragColor = color;   
}
