#ifdef GL_ES
precision mediump float;
#endif
uniform vec2 u_resolution;
uniform sampler2D u_fftTexture;
uniform vec4 u_mouse;
uniform float u_time;

float t;

mat2 Rot2d(float a) {
  float s = sin(a);
  float c = cos(a);
  return mat2(c, - s, s, c);
}


void main(){
  t = mod(u_time / 5.0, 6.28318530718);
  // normalize uv to go between -1 and 1
  vec2 uv = (gl_FragCoord.xy - 0.5 * u_resolution.xy) / min(u_resolution.x, u_resolution.y);

  
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

  for(float i = 0.0;i<50.0;i+=1.0){
    uv *= 1.02;    
    uv = Rot2d(sin(t*.02) * i) * uv;
    float r = 0.5 + 0.5 * sin(0.1 * i + t);
    r /= 2.0;
    float a = 6.28318530718 * fract(sin(t*0.02*transient) * i);
    vec2 p = r * vec2(cos(a), sin(a));
    float d = length(uv - p);
    float idx = fract(abs(sin(t) * i));
    if(idx < 0.33){
      color += 0.001 / d * bass;
      color.b += 0.001 / d * transient;
    }else if(idx < 0.66){
      color += 0.001 / d * transient;
      color.r += 0.001 / d * bass;
    }else{
      color += 0.001 / d * mid;
      color.g += 0.001 / d * bass;
      
    }
    
  }
  color += 0.01 / length(uv) * bass;
  
  gl_FragColor = vec4(color, 1.0);
}