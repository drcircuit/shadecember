#version 300 es
precision highp float;
// Uniform variables for resolution, FFT texture, mouse position, and time
uniform vec2 u_resolution;
uniform sampler2D u_fftTexture;
uniform vec4 u_mouse;
uniform float u_time;
#define PI 3.1415926535897932384626433832795
mat2 rotate2d(float _angle) {
  return mat2(cos(_angle), -sin(_angle), sin(_angle), cos(_angle));
}
float noise(vec2 st) {
  return fract(sin(dot(st.xy, vec2(12.9898f, 78.233f))) * 43758.5453123f);
}

float perlinNoise(vec2 uv) {
  vec2 i = floor(uv);
  vec2 f = fract(uv);
  vec2 u = f * f * (3.0f - 2.0f * f);
  return mix(mix(noise(i + vec2(0.0f, 0.0f)), noise(i + vec2(1.0f, 0.0f)), u.x), mix(noise(i + vec2(0.0f, 1.0f)), noise(i + vec2(1.0f, 1.0f)), u.x), u.y);
}

vec2 perlinNoise22(vec2 uv){
  vec2 i = floor(uv);
  vec2 f = fract(uv);
  vec2 u = f * f * (3.0f - 2.0f * f);
  return mix(mix(i + vec2(0.0f, 0.0f), i + vec2(1.0f, 0.0f), u.x), mix(i + vec2(0.0f, 1.0f), i + vec2(1.0f, 1.0f), u.x), u.y);
}



float ffbm(vec2 uv, float scale, float offset) {
  float n = 0.0f;
  float amp = 1.0f;
  for(int i = 0; i < 4; i++) {
    n += perlinNoise(uv * scale) * amp;
    uv *= 2.0f;
    amp *= 0.5f;
  }
  return n + offset;
}

float circleGradient(vec2 uv, float blur) {
  float dist = length(uv);
  return smoothstep(0.5f + blur, 0.5f - blur, dist);
}

// Function to apply a blur to a color
vec3 applyBlur(vec3 color, float blurAmount, vec2 uv) {
  vec3 accumulatedColor = vec3(0.0f);
  float totalWeight = 0.0f;
  for(int x = -1; x <= 1; x++) {
    for(int y = -1; y <= 1; y++) {
      vec2 sampleUv = uv + vec2(x, y) * blurAmount;
      accumulatedColor += texture(u_fftTexture, sampleUv).rgb;
      totalWeight += 1.0f;
    }
  }
  return accumulatedColor / totalWeight;
}

float gaussian(float x, float sigma) {
  return exp(-(x * x) / (2.0f * sigma * sigma));
}

vec2 lissajous(float t, float a, float b, float delta) {
  return vec2(sin(a * t + delta), sin(b * t));
}

vec3 applyGlow(vec3 color, float distance, float glowStrength, float glowRadius) {
  float glow = gaussian(distance, glowRadius) * glowStrength;
  return color + glow;
}
out vec4 fragColor;
// Main function
void main() {
  // Normalize screen coordinates
  float scale = (sin(u_time)*.5+.5)+3.5;
  vec2 uv = scale * (2.0f * gl_FragCoord.xy - u_resolution) / min(u_resolution.x, u_resolution.y);
  float t = u_time * 0.1f;
  float bass = texture(u_fftTexture, vec2(0.00f, 0.0f)).r;
  float mid = texture(u_fftTexture, vec2(0.3f, 0.0f)).r;
  float treble = texture(u_fftTexture, vec2(0.2f, 0.0f)).r;
  float b = pow(bass, 6.0f);
  uv += lissajous(t, 1.0f, 2.0f, PI/2.0) ;
  uv *= rotate2d(mod(t*2., PI*2.0));
  vec2 ouv = uv;

  float ilength = 1.0f / length(uv);
  uv = uv * ilength - vec2(ilength+t, 0.5f);
  // Convert to polar coordinates
  vec3 finalColor = vec3(0.0f);
  float noise = 0.0f;
  for(int i = 0; i < 5; i++) {
    float scale = 5.5f + float(i) * 0.5f;
    float offset = float(i) * 0.5f;
    uv *= rotate2d(mod(t*offset*.2, PI*2.0));
    noise = ffbm(uv-t*0.7*float(i)-vec2(float(i*i), float(i)/2.0), scale, offset*2.) * ilength * 0.2f;
    finalColor += vec3(noise/5.0);

  }
    // finalColor.b /= 2.0f;

  finalColor.rg *= b;
  finalColor.b += 0.4/(ffbm(uv*sin(mod(t, 3.0)*3.0)*0.5, 5.0f, 0.0f) * 0.5f + 0.5f);
  finalColor.r += 0.2/(ffbm(uv*cos(mod(t, 4.0)*3.0)*0.5, 5.0f, 0.0f) * 0.5f + 0.5f);
  finalColor = applyGlow(finalColor, length(uv), 0.5f, 0.5f);

  float grad = circleGradient(uv, 0.5f);
  finalColor -= (0.0001/length(uv)*0.5f + 0.5f)*sin(b*4.5f)*0.1f * grad;
  finalColor -= (length(ouv))*.1;
  // finalColor.g -= (ffbm(uv-t*2., b*5.0, t))*0.2;
  fragColor = vec4(finalColor, 1.0f);
}