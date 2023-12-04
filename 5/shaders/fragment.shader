#ifdef GL_ES
  precision highp float;
#endif

// Uniform variables for resolution, FFT texture, mouse position, and time
uniform vec2 u_resolution;
uniform sampler2D u_fftTexture;
uniform vec4 u_mouse;
uniform float u_time;

// Function to convert HSL color to RGB color
vec3 hsl2rgb(vec3 hsl) {
  // Extract HSL components
  float hue = hsl.x;
  float lightness = hsl.z;
  float saturation = hsl.y;
  
  // Calculate chroma, hue_, x, and m
  float chroma = (1.0 - abs(2.0 * lightness - 1.0)) * saturation;
  float hue_ = hue * 6.0;
  float x = chroma * (1.0 - abs(mod(hue_, 2.0) - 1.0));
  float m = lightness - 0.5 * chroma;
  
  // Determine RGB values based on hue_
  vec3 rgb;
  if (hue_ < 1.0) {
    rgb = vec3(chroma, x, 0.0);
  } else if (hue_ < 2.0) {
    rgb = vec3(x, chroma, 0.0);
  } else if (hue_ < 3.0) {
    rgb = vec3(0.0, chroma, x);
  } else if (hue_ < 4.0) {
    rgb = vec3(0.0, x, chroma);
  } else if (hue_ < 5.0) {
    rgb = vec3(x, 0.0, chroma);
  } else {
    rgb = vec3(chroma, 0.0, x);
  }
  
  // Add m to RGB and return
  rgb = rgb + m;
  return rgb;
}

// Function to create a 2D rotation matrix
mat2 rotate2D(float angle){
  float cosAngle = cos(angle);
  float sinAngle = sin(angle);
  return mat2(cosAngle, -sinAngle, sinAngle, cosAngle);
}

// Main function
void main() {
  // Normalize screen coordinates
  vec2 uv = (2.0 * gl_FragCoord.xy - u_resolution) / min(u_resolution.x, u_resolution.y);
  vec2 originalUv = uv;

  // Time parameter for animation
  float time = mod(u_time * 0.2, 6.28);

  // Extract bass, mid, and treble values from the FFT texture
  float bass = texture2D(u_fftTexture, vec2(0.00, 0.0)).r;
  float mid = texture2D(u_fftTexture, vec2(0.3, 0.0)).r;
  float treble = texture2D(u_fftTexture, vec2(0.2, 0.0)).r;
  float b = pow(bass, 6.0);

  // Rotate UV coordinates based on time and bass intensity
  uv *= rotate2D(mod(time + b * b * b, 6.28));

  // Define parameters for the Kleinian Group
  vec2 c = vec2(abs(sin(time)) * cos(time), abs(cos(time)) * sin(time)); // Translation
  float s = -abs(sin(time)); // Scaling
  float r = cos(mod(time, 0.28)) + 0.02 * sin(time + pow(bass, 8.0)); // Reflection
  
  // Iterate the Kleinian Group transformation
  vec2 z = uv + time * 0.1;
  for (int i = 0; i < 50; i++) {
    // Apply a transformation to the complex number z
    z = (z - c) * s * 0.2;
    
    // Apply reflection
    if (length(z) < r) {
      z /= dot(z, z);
    }
  }
  
  // Map the resulting complex number to a color
  vec3 color = vec3(0.5 + 0.5 * cos(z.y + time), 0.5 + 0.5 * sin(z.x * 0.02 + time), 0.5 + 0.5 * cos(z.x + z.y + time));

  // Adjust color based on audio input
  color *= vec3(2.0 - b, b * b, treble) / vec3(2.1, 1.0, 1.2);

  // Colorize in electric purple and blue tones
  color += mix(color, vec3(0.5, -1.0, 0.5), cos(z.x * time) * 0.5 + 0.5);
  color -= vec3(0.4, 2.0, -0.4);
  color *= color.xzx;

  // Shift color hue over time
  color = color * hsl2rgb(vec3(mod(time, 6.28) / 6.28, 1.0, b));

  // Set the final fragment color
  gl_FragColor = vec4(color, 1.0);
}