#version 300 es
precision highp float;
#define PI 3.1415926535897932384626433832795
#define PHI 1.6180339887498948482045868343656
// Uniform variables for resolution, FFT texture, mouse position, and time
uniform vec2 u_resolution;
uniform sampler2D u_fftTexture;
uniform vec4 u_mouse;
uniform float u_time;

mat2 rotate2d(float _angle) {
  return mat2(cos(_angle), -sin(_angle), sin(_angle), cos(_angle));
}
float noise(vec2 st) {
    // Implement your noise function here
    // For example, you can use a 2D simplex noise function
  return fract(sin(dot(st.xy, vec2(12.9898f, 78.233f))) * 43758.5453123f);
}
float perlinNoise(vec2 uv) {
  vec2 i = floor(uv);
  vec2 f = fract(uv);
  vec2 u = f * f * (3.0f - 2.0f * f);
  return mix(mix(noise(i + vec2(0.0f, 0.0f)), noise(i + vec2(1.0f, 0.0f)), u.x), mix(noise(i + vec2(0.0f, 1.0f)), noise(i + vec2(1.0f, 1.0f)), u.x), u.y);
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

vec2 spiral(vec2 uv, float radius) {
  float theta = atan(uv.y, uv.x);
  float r = length(uv);
  float a = theta / (2.0f * PI);
  float b = r / radius;
  return vec2(a, b);
}

float gaussian(float x, float sigma) {
  return exp(-(x * x) / (2.0f * sigma * sigma));
}

vec3 applyGlow(vec3 color, float distance, float glowStrength, float glowRadius) {
  float glow = gaussian(distance, glowRadius) * glowStrength;
  return color + glow;
}
out vec4 fragColor;
// Main function
void main() {
  // Normalize screen coordinates
  vec2 uv = (2.0f * gl_FragCoord.xy - u_resolution) / min(u_resolution.x, u_resolution.y);
  uv *= rotate2d(u_time * 0.1f);

  float bass = texture(u_fftTexture, vec2(0.00f, 0.0f)).r;
  float mid = texture(u_fftTexture, vec2(0.3f, 0.0f)).r;
  float treble = texture(u_fftTexture, vec2(0.2f, 0.0f)).r;
  float b = pow(bass, 6.0f);
  // Convert to polar coordinates
  float r = length(uv);
  float theta = atan(uv.y, uv.x) + u_time;

    // Apply golden ratio spiral
  float z = .5f;
  float sp = mod(theta + log(r) * PHI, z * PI) / (z * PI);
  sp *= ffbm(uv * 2.0f, 21.0f * sin(u_time * 0.1f), u_time * 0.001f);
  vec3 color = vec3(cos(sp * 12.f), b, r);
  color = 1.0f - vec3(0.2f / ffbm(uv * 5.f +sp, 4.4f, 0.01/(.6+sin(u_time)*0.5)));



    // Apply the glow to the color
  vec3 colorWithGlow = applyGlow(color, sp-0.5*circleGradient(uv, .2), b, 0.5f);

    // Use the gradient to modulate the strength of the glow
  float gradient = circleGradient(uv, 1.0f);
  vec3 finalColor = mix(vec3(0.0f), colorWithGlow, gradient);
  finalColor.g *= finalColor.r;
  finalColor.r *= b/ffbm(finalColor.g*colorWithGlow.g*uv+sp*b, 10.9f, 0.01/(.6+sin(u_time)*0.5)) *0.4;
  finalColor *= gradient+0.5f;
  finalColor.g *= spiral(uv*b, 1.0f).y;
    // Set the final fragment color
  fragColor = vec4(finalColor, 1.0f);
}