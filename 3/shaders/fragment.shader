#ifdef GL_ES
  precision mediump float;
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
mat2 Rot2d(float a){
    float c = cos(a);
    float s = sin(a);
    return mat2(c, -s, s, c);
}

// Function to generate Julia set fractal
vec3 Julia(vec2 uv, float t){
    // Initialize variables for Julia set
    vec2 z = uv;
    vec2 c = vec2(-.45 + sin(t), -.5 + cos(t));
    float d = 1e20;
    vec2 ddmin = vec2(10.0);
    
    // Iterate to generate Julia set
    for(int i = 0; i < 200; i++) {
        z = vec2(z.x * z.x - z.y * z.y, 2.0 * z.x * z.y) + c;
        d = min(d, dot(z, z));
        ddmin = min(ddmin, vec2(abs(0.0 + z.y + 0.5 * sin(z.x * 2.)), dot(z, z)));
    }
    
    // Convert to polar coordinates
    float r = sqrt(z.x * z.x + z.y * z.y);
    float theta = atan(z.y, z.x) + 3.0 * t;
    vec3 color = vec3(0.0);
    
    // Generate color based on polar coordinates
    for(int i = 0; i < 3; i++) {
        float h = (theta + 2.0 * 3.14159 * float(i) / 3.0) / (2.0 * 3.14159);
        h = fract(h + 0.5);
        float s = smoothstep(0.05, 0.35, r);
        float l = mix(0.4, 1.0, smoothstep(0.0, 0.15, d));
    }
    
    // Scale down color
    color /= 20.0;
    
    // Apply orbit traps and color modifications
    color = mix(color, vec3(0.1, .99, .2), pow(ddmin.x, 0.32)).xyy;
    color = mix(color, vec3(0.1, 0.5, 0.2), pow(ddmin.y, 0.22)).yzx;
    
    // Add a background color based on time
    color += hsl2rgb(vec3(sin(t), .5, .4));
    return color;
}

// Main function
void main() {
  // Time parameter for animation
  float t = u_time * 0.1;
  
  // Extract bass, mid, and treble values from the FFT texture
  float bass = texture2D(u_fftTexture, vec2(0.0, 0.0)).r;
  float mid = texture2D(u_fftTexture, vec2(0.2, 0.0)).r;
  float treble = texture2D(u_fftTexture, vec2(.35, 0.0)).r;

  // Normalized screen coordinates
  vec2 uv = (2.0 * gl_FragCoord.xy - u_resolution.xy) / u_resolution.y;
  
  // Apply rotation to uv coordinates based on treble and time
  uv *= Rot2d(treble * 0.1 + t);
  
  // Generate Julia fractal with uv coordinates and time
  vec3 col = Julia(uv * 2.0, t);
  
  // Adjust red channel based on bass intensity
  col.r *= 0.4 + bass * 0.5;
  
  // Set the final fragment color
  gl_FragColor = vec4(col, 1.0);
}