#version 300 es
precision mediump float;
uniform vec2 u_resolution;
uniform vec2 u_mouse;
uniform float u_time;
uniform sampler2D u_texture;
uniform sampler2D u_fftTexture;
uniform samplerCube u_env;
out vec4 fragColor;

vec2 gausian(vec2 uv, float sigma){
    float pi = 3.1415926535897932384626433832795;
    float e = 2.718281828459045235360287471352;
    float a = 1.0/(2.0*pi*sigma*sigma);
    float b = 2.0*sigma*sigma;
    return a*vec2(pow(e, -dot(uv, uv)/b));
}
void main(){
    // normalize uv to be between 0 and 1  
    float bass = texture(u_fftTexture, vec2(0.0, 0.0)).r;
    vec2 uv = gl_FragCoord.xy/u_resolution.xy;
    // glass dome distortion
    vec2 center = vec2(0.5, 0.5);
    float domeRadius = 0.5; 
    float domeHeight = .5;
    float domeDist = distance(uv, center);
    vec2 domeDir = normalize(uv - center);
    vec2 domeUVO = center + domeDir * domeRadius;
    vec3 domeNormal = normalize(vec3(domeUVO - center, domeHeight));
    vec4 envRef = texture(u_env, domeNormal);
    float distortion = domeHeight * pow(1.0 - domeDist/domeRadius, 2.0);
    vec2 domeUV = mix(uv, center, distortion);
    vec4 color = texture(u_texture, domeUV); 
    color += envRef;
    //color.r += texture(u_texture, gausian(uv-.5, .54)).r;        
    fragColor = color;   
}