#ifdef GL_ES
precision mediump float;
#endif
uniform vec2 u_resolution;
uniform vec4 u_mouse;
uniform float u_time;
uniform sampler2D u_fftTexture;

#define PI 3.1415926535897932384626433832795

float t;

mat2 Rot2d(float a) {
  float s = sin(a);
  float c = cos(a);
  return mat2(c, - s, s, c);
}

float map(float a, float b, float x, float y, float n) {
  return (a - b) * (n - x) / (y - x) + b;
}
void main(){
  t = mod(u_time / 1.0, 2.0*PI);
  vec2 uv = (gl_FragCoord.xy-0.5 * u_resolution) / u_resolution.y;
  vec2 uv2 = uv;
    // give color a dark blue winter evening sky gradient based on uv length
  vec3 color = vec3(0.05, 0.1, 0.2) * (1.0 - length(uv));
       color += vec3(0.0, 0.2, 0.2) * (pow(1.-length(uv),2.0));
       color += vec3(0.9, 0.65, 0.0) * (pow(1.-length(uv),20.0));
  
  float bass = 0.0;
  float mid = 0.0;
  float transient = 0.0;
  for(float i = 0.0;i<0.3;i+=0.05){
    bass += texture2D(u_fftTexture, vec2(i+0.18, 0.0)).r;
    transient += texture2D(u_fftTexture, vec2(i+0.37, 0.0)).r;
    mid += texture2D(u_fftTexture, vec2(i+0.25, 0.0)).r;
  }
  bass = pow(bass, 2.0);
  mid *= 1.5;
  transient *= 5.0;

  uv *= -Rot2d(PI/2.0);
  uv += vec2(-0.08,0);
  uv *= map(0.9, 1.02, -1.0, 1.0,cos(t*bass*0.5));
  float r = 0.12;
  for(float i = 0.0; i<60.0;i++){
    /// add peudorandom offset to the uv
    vec2 off = vec2(sin(i*0.1*t)*0.1, cos(i*0.1*t)*0.1)*t;
    uv = uv + off*0.01;
    float f = (sin(t*transient/2.0)*0.5+0.5) + 0.25;
    float i2 = i + f;
    float a = i2 / 3.0;
    float dx = 2.0 * r * cos(a) - r * cos(2.0 * a);
    float dy = 2.0 * r * sin(a) - r * sin(2.0 * a);
    float dy2 = 2.0 * r * sin(a) + r * sin(2.0 * a);
    color += 0.001 * f / length(uv - vec2(dx, mix(dy, dy2, sin(t)*.5+.5))); 
  }
  // draw 60 points following a lissajous curve with radius r
  
  for(float i = 0.0; i<50.0;i++){
    float size = 0.001;
    float r2 = 0.22;
    vec2 off = vec2(sin(i*0.1*t)*0.1, cos(i*0.1*t)*0.1)*t;
    uv = uv + off*0.001;
    float a = (i*0.02+t)*3.0;
    float b = (i*0.02+t)*4.0;
    float x = r2 * cos(a+PI/2.0);
    float y = r2 * sin(b);
    float p = size / length(uv+vec2(x,y));
    color += vec3(p,normalize(p*i),p*p);
  }
  color *= sin(vec3(bass, mid, transient))*0.5+0.5;
  color = 1.0-color;
  // color *= 1.0 - pow(length(uv), 1.5);
  // color *= vec3(normalize(bass*2.0), normalize(mid), normalize(transient/5.0));

  color = mix(color, 1.0-color, sin(t*.5)*0.5+0.5);
  gl_FragColor=vec4(color,1.0);
}