#ifdef GL_ES
  precision mediump float;
#endif

// Uniform variables for resolution, FFT texture, mouse position, and time
uniform vec2 u_resolution;
uniform sampler2D u_fftTexture;
uniform vec4 u_mouse;
uniform float u_time;

vec3 hsl2rgb(vec3 hsl) {
  float hue = hsl.x;
  float lightness = hsl.z;
  float saturation = hsl.y;
  
  float chroma = (1.0 - abs(2.0 * lightness - 1.0)) * saturation;
  float hue_ = hue * 6.0;
  float x = chroma * (1.0 - abs(mod(hue_, 2.0) - 1.0));
  float m = lightness - 0.5 * chroma;
  
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
  
  rgb = rgb + m;
  return rgb;
}

mat2 Rot2d(float a){
    float c = cos(a);
    float s = sin(a);
    return mat2(c, -s, s, c);
}
vec3 Julia(vec2 uv, float t){
    vec2 z = uv;
    vec2 c = vec2(-.45+sin(t), -.5+cos(t));
    float d = 1e20;
    vec2 ddmin = vec2(10.0);
    for(int i = 0; i < 200; i++) {
        z = vec2(z.x*z.x - z.y*z.y, 2.0*z.x*z.y) + c;
        d = min(d, dot(z, z));
        ddmin = min(ddmin, vec2(abs(0.0+z.y + 0.5*sin(z.x*2.)), dot(z, z)));
    }
    float r = sqrt(z.x * z.x + z.y * z.y);
    float theta = atan(z.y, z.x) + 3.0 * t;
    vec3 color = vec3(0.0);
    for(int i = 0; i < 3; i++) {
        float h = (theta + 2.0 * 3.14159 * float(i) / 3.0) / (2.0 * 3.14159);
        h = fract(h + 0.5);
        float s = smoothstep(0.05, 0.35, r);
        float l = mix(0.4, 1.0, smoothstep(0.0, 0.15, d));
        //color += hsl2rgb(vec3(h, s, l));
    }
    color /= 20.0;
    color = mix(color, vec3(0.1,.99,.2), pow(ddmin.x, 0.32)).xyy;
    color = mix(color, vec3(0.1, 0.5, 0.2), pow(ddmin.y, 0.22)).yzx;
    color += hsl2rgb(vec3(sin(t), .5, .4));
    return color;
}

#define GRID_SIZE 1.0
void main() {
  float t = u_time * 0.1;
  float bass = texture2D(u_fftTexture, vec2(0.0, 0.0)).r;
  float mid = texture2D(u_fftTexture, vec2(0.2, 0.0)).r;
  float treble = texture2D(u_fftTexture, vec2(.35, 0.0)).r;

  vec2 uv = (2.0*gl_FragCoord.xy - u_resolution.xy)/u_resolution.y;
  uv *= Rot2d(treble*0.1+t);
  vec3 col = Julia(uv*2.0, t);
  col.r *= .4 + bass * 0.5;
  gl_FragColor = vec4(col, 1.0);
}
