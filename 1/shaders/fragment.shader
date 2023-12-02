#ifdef GL_ES
precision mediump float;
#endif

// Uniform variables for resolution, FFT texture, mouse position, and time
uniform vec2 u_resolution;
uniform sampler2D u_fftTexture;
uniform vec4 u_mouse;
uniform float u_time;

// Global variable for time
float t;

// Function to rotate a 2D vector by an angle 'a'
mat2 Rot2d(float a) {
  float s = sin(a);
  float c = cos(a);
  return mat2(c, -s, s, c);
}

void main() {
  // Calculate normalized time within a period of 6.28318530718 (2 * PI)
  t = mod(u_time / 5.0, 6.28318530718);

  // Normalize uv to go between -1 and 1
  vec2 uv = (gl_FragCoord.xy - 0.5 * u_resolution.xy) / min(u_resolution.x, u_resolution.y);

  // Initialize color with a dark blue winter evening sky gradient based on uv length
  vec3 color = vec3(0.05, 0.1, 0.2) * (1.0 - length(uv));
  color += vec3(0.0, 0.2, 0.2) * (pow(1. - length(uv), 2.0));
  color += vec3(0.9, 0.65, 0.0) * (pow(1. - length(uv), 20.0));

  // Initialize variables for FFT values
  float bass = 0.0;
  float mid = 0.0;
  float transient = 0.0;

  // Accumulate FFT values over a range
  for (float i = 0.0; i < 0.3; i += 0.05) {
    bass += texture2D(u_fftTexture, vec2(i + 0.18, 0.0)).r;
    transient += texture2D(u_fftTexture, vec2(i + 0.37, 0.0)).r;
    mid += texture2D(u_fftTexture, vec2(i + 0.25, 0.0)).r;
  }

  // Apply transformations to the FFT values
  bass = pow(bass, 2.0);
  mid *= 1.5;
  transient *= 5.0;

  // Draw particles in a circular pattern
  for (float i = 0.0; i < 50.0; i += 1.0) {
    uv *= 1.04;
    uv = Rot2d(sin(t * 0.02) * i) * uv;

    // Calculate polar coordinates
    float r = 0.5 + 0.5 * sin(0.1 * i + t);
    r /= 2.0;
    float a = 6.28318530718 * fract(sin(t * 0.02 * transient) * i);
    vec2 p = r * vec2(cos(a), sin(a));

    // Calculate distance and index based on sin(t)
    float d = length(uv - p);
    float idx = fract(abs(sin(t) * i));

    // Apply colors based on the index
    if (idx < 0.33) {
      color += 0.001 / d * bass;
      color.b += 0.001 / d * transient;
    } else if (idx < 0.66) {
      color += 0.001 / d * transient;
      color.r += 0.002 / d * bass;
    } else {
      color += 0.001 / d * mid;
      color.g += 0.002 / d * bass;
    }
  }
  color *= 0.5;
  // Add a radial gradient to the color
  color += 0.01 / length(uv) * bass;

  // Output final color
  gl_FragColor = vec4(color, 1.0);
}