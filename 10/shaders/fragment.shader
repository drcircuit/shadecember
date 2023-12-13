#version 300 es
precision highp float;
// Uniform variables for resolution, FFT texture, mouse position, and time
uniform vec2 u_resolution;
uniform sampler2D u_fftTexture;
uniform sampler2D u_texture;
uniform vec2 u_mouse;
uniform float u_time;
#define TAU 6.28318530718
#define MAX_ITER 8
float rand(vec2 p){
  return fract(sin(dot(p.xy, vec2(12.9898,78.233))) * 43758.5453);

}
float turbulence(vec2 uv, float c, float intensity, float time){
  vec2 p = 6.*uv-250.;
  vec2 i = vec2(p);
  for (int n = 0; n < MAX_ITER; n++) 
  {
    float t = time * (1.0 - (3.5 / float(n+1)));
    i = p + vec2(cos(t - i.x) + sin(t + i.y), sin(t - i.y) + cos(t + i.x));
    c += 1.0/length(vec2(p.x / (sin(i.x+t)/intensity),p.y / (cos(i.y+t)/intensity)));
  }
  c /= float(MAX_ITER);
  c = 1.2-pow(c, 1.4);
  return c;
}
vec3 plasma(vec2 uv, float time, vec3 colorizer){
  float c = turbulence(uv, 1.0, .005, time);
  float c2 = turbulence(uv, 4.0, .0011, time);
  
  vec3 colour = vec3(pow(abs(c), 3.0), c2, c2+sin(c));
  return clamp(colour + colorizer, 0.0, 1.0);
}

out vec4 fragColor;
// Main function
void main() {
  // Normalized pixel coordinates (from 0 to 1)
  float iTime = u_time*.01;
  float time = iTime*.2+sin(iTime*.1);
  vec2 uv = (gl_FragCoord.xy-u_resolution.xy*.5)/u_resolution.y;
  uv *= 2.0;
  vec3 color = plasma(uv, time, vec3(-1.0, 1.4, 1.0));
  vec3 color2 = plasma(uv-.25, time, vec3(-.1, -1., .5));
  float bass = texture(u_fftTexture, vec2(0.2, 0.0)).r;
  color += 0.5*color2;
  color = clamp(color, 0.0, 1.0); 
  color.r *= 3.*bass;
  fragColor = vec4(color.rgb, 1.0);
}