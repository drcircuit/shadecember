#ifdef GL_ES
precision highp float;
#endif

// Uniform variables for resolution, FFT texture, mouse position, and time
uniform vec2 u_resolution;
uniform sampler2D u_fftTexture;
uniform vec4 u_mouse;
uniform float u_time;

// Function to create a 2D rotation matrix
mat2 rotate2D(float angle) {
  float cosAngle = cos(angle);
  float sinAngle = sin(angle);
  return mat2(cosAngle, -sinAngle, sinAngle, cosAngle);
}

vec2 cardioid(vec2 uv, float r, float n) {
  float angle = atan(uv.y, uv.x);
  float radius = length(uv);
  float theta = angle * n;
  float x = radius * cos(theta);
  float y = radius * sin(theta);
  return vec2(x, y);
}

vec3 kaleidoscope(vec2 uv, float n) {
  float angle = atan(uv.y, uv.x);
  float radius = length(uv);
  float theta = angle * n;
  float x = radius * cos(theta);
  float y = radius * sin(theta);
  return vec3(x, y, 0.0);
}

vec2 rippleDistort(vec2 uv, float time) {
  float angle = atan(uv.y, uv.x);
  float radius = length(uv);
  float theta = angle + sin(time * 10.) * 0.5;
  float x = radius * cos(theta);
  float y = radius * sin(theta);
  return vec2(x, y);
}
// gausian blur
vec3 blur(vec2 uv, float time) {
  vec3 color = vec3(0.0);
  float total = 0.0;
  for (float x = -4.0; x <= 4.0; x++) {
    for (float y = -4.0; y <= 4.0; y++) {
      vec2 offset = vec2(x, y);
      float weight = 1.0 - length(offset) / 4.0;
      color += kaleidoscope(uv + offset, 10.0) * weight;
      total += weight;
    }
  }
  return color / total;
}
vec3 scope2(vec2 uv, float time) {
  uv *= rotate2D(time * 5.);
  vec3 color = vec3(1.0);
  uv -= cardioid(uv + sin(time * 10.) + cos(uv * time * 10.), 0.5, 10.0);
  uv *= 1.0 + 0.5 * sin(time);
  color = vec3(uv, 0.5 + 0.5 * sin(time));
  return color;
}
// Main function
void main() {
  // Normalize the pixel coordinates to [-1, 1]
  vec2 uv = (gl_FragCoord.xy - 0.5 * u_resolution.xy) / u_resolution.y;
  float time = mod(u_time * 0.1, 6.28);
  // ripple
  // uv = rippleDistort(uv, time);
  uv *= rotate2D(time * 2.);
  vec3 color = scope2(uv, time);
  uv *= rotate2D(time * 2.);
  color *= kaleidoscope(uv, 10.0);
  uv *= rotate2D(time * 2.);
  color -= 0.01/kaleidoscope(-uv, 5.0);
  // blur kaleidoscope
  color *= blur(uv, time);
  gl_FragColor = vec4(color, 1.0);
}