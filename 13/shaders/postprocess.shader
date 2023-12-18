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

vec3 sampleScene(vec2 pixelCoord){
    vec2 uv = gl_FragCoord.xy / u_resolution.xy;
    vec2 uv2 = (gl_FragCoord.xy - u_resolution.xy * 0.5) / u_resolution.y;

    // 2x antialiasing

    vec4 color = texture(u_texture, uv);
    vec3 vignette = 1.0 - vec3(length(uv2));
    vignette = pow(vignette,vec3(2.0))+0.3;
    return (color * vec4(vignette,1.0)).rgb;
}
#define AASAMPLES 1
void main() {
    // normalize uv to be between 0 and 1  
    vec3 color = sampleScene(gl_FragCoord.xy);
 
    fragColor = vec4(color/1.0,1.0);   
}
