#ifdef GL_ES
  precision mediump float;
#endif

uniform vec2 u_resolution;
uniform vec4 u_mouse;
uniform float u_time;
uniform sampler2D u_fftTexture;

#define PI 3.1415926535897932384626433832795

float t;

// Function to rotate a 2D vector by an angle 'a'
mat2 Rot2d(float a) {
  float s = sin(a);
  float c = cos(a);
  return mat2(c, -s, s, c);
}

// Function to generate a pseudo-random value based on a seed
float rand(float seed) {
  return fract(seed * 33433.1);
}

// Function to map a value from one range to another
float map(float a, float b, float x, float y, float n) {
  return (a - b) * (n - x) / (y - x) + b;
}

void main() {
  // Calculate normalized time within a period of 2*PI
  t = mod(u_time / 1.0, 2.0 * PI);

  // Calculate normalized screen coordinates
  vec2 uv = (gl_FragCoord.xy - 0.5 * u_resolution) / u_resolution.y;
  vec2 uv2 = uv;

  // Initialize variables for FFT values
  float bass = 0.0;
  float mid = 0.0;
  float transient = 0.0;

  // Accumulate FFT values over a range
  for (float i = 0.0; i < 0.3; i += 0.05) {
    transient += texture2D(u_fftTexture, vec2(i + 0.37, 0.0)).r;
    mid += texture2D(u_fftTexture, vec2(i + 0.25, 0.0)).r;
  }

  // Smooth the mid value
  float smoothmid = smoothstep(0.0, 0.1, mid);

  // Transform and scale bass value
  bass = texture2D(u_fftTexture, vec2(0.00, 0.0)).r;
  bass = pow(bass, 4.0);

  // Adjust mid and transient values
  mid *= 1.5;
  transient *= 5.0;

  // Initialize base color with a gradient
  vec3 color = vec3(-0.5 * (cos(smoothmid) * 0.5 + 0.5), 0.1, 0.1);
  color += vec3(0.0, 0.2, 0.2) * (pow(1.0 - length(uv), 2.0));
  color += vec3(0.9, 0.65, 0.0) * (pow(1.0 - length(uv), 20.0)) * bass;

  // Rotate and transform uv coordinates
  uv *= -Rot2d(PI / 2.0);
  uv += vec2(-0.08, 0);
  uv *= map(0.9, 1.02, -1.0, 1.0, cos(t * bass * 0.5));

  // Calculate radius based on mid value
  float r = 0.12 * (map(0.9, 0.75, -1.0, 1.0, mid));

  // Draw particles along a cardioid and Steiner curve
  for (float i = 0.0; i < 60.0; i++) {
    // Add pseudo-random offset to the uv
    vec2 off = vec2(sin(i * 0.1 * t) * 0.1, cos(i * 0.1 * t) * 0.1) * t;
    uv = uv + off * 0.01;

    // Calculate cardioid and Steiner curve coordinates
    float f = (sin(t * bass / 2.0) * 0.5 + 0.5) + 0.25;
    float i2 = i + f;
    float a = i2 / 3.0;
    float dx = 2.0 * r * cos(a) - r * cos(2.0 * a);
    float dy = 2.0 * r * sin(a) - r * sin(2.0 * a);
    float dy2 = 2.0 * r * sin(a) + r * sin(2.0 * a);

    // Update color based on particle position
    color += 0.001 * f / length(uv - vec2(dx, mix(dy, dy2, sin(t) * 0.5 + 0.5)));
  }

  // Shift uv coordinates and draw another set of particles with varying color
  uv.x += 0.1;
  uv = uv2;
  float speed = 0.005;
  float t2 = mod(u_time * 0.05, 2.0 * PI);
  uv = uv * Rot2d(t2 * 4.0);

  // Initialize additional colors
  vec3 color2 = color;
  vec3 color3 = color;

  // Draw particles along a different lissajous curve
  for (float i = 0.0; i < 250.0; i++) {
    float size = 0.003;
    float r2 = 0.32;
    float a = (i * 0.02 + t2) * 3.0 + 0.3 * (rand(i * mid * (i + 0.5)) * 0.1);
    float b = (i * 0.02 + t2) * 4.0 + 0.3 * (rand(transient * i) * 0.1);

    a += i * speed;
    b += i * speed;
    float dx = r2 * cos(a + PI / 2.0);
    float dy = r2 * sin(b);
    float p = size / length(uv + vec2(dx, dy));
    vec3 c2 = vec3(p, normalize(p * i), p * p);

    // Update colors
    color2 += c2 * 0.14;
    color3 += c2 * 0.14;
    color2 *= 0.2 + vec3(0.5, 0.5, 0.5) + 0.5 * vec3(sin(i * 0.1 + t), sin(i * 0.15 + t), sin(i * 0.2 + t));
  }

  // Combine and mix colors
  color = mix(color3, color2, sin(bass) * 0.5 + 0.5) + color;

  // Output final color
  gl_FragColor = vec4(color, 1.0);
}
