#version 300 es
precision highp float;
// Uniform variables for resolution, FFT texture, mouse position, and time
uniform vec2 u_resolution;
uniform sampler2D u_fftTexture;
uniform vec2 u_mouse;
uniform float u_time;
#define PI 3.1415926535897932384626433832795

out vec4 fragColor;
// Main function
void main() {
  float t = u_time * 0.0001f;
  // Normalize screen coordinates -1.0 to 1.0
  vec2 uv = (gl_FragCoord.xy - 0.5f * u_resolution.xy) / u_resolution.y;
  vec3 color = vec3(0.0f);
  float bass = texture(u_fftTexture, vec2(0.0f, 0.0f)).r;
  // create a HAL 9000 eye effect
  // draw hot yellow circle in the middle
  // normalize bass to be between 1.0 and 2.0
  bass = 1.0f + bass; 
  float dist = length(uv)*1.0/bass;
  float r = 0.004/dist;
  float r2 = 0.015/dist;
  float c2 = 1.-smoothstep(0.007f, 0.01f, dist);
  color += vec3(1.0f, 1.f, 1.0f) * c2;
  color += vec3(1.0f, .8f, 0.2f) * r;
  color += vec3(1.0f, .1f, .0f) * r2;
  fragColor = vec4(color, 1.0f);
}