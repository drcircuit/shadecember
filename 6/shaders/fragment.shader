#ifdef GL_ES
  precision highp float;
#endif

// Uniform variables for resolution, FFT texture, mouse position, and time
uniform vec2 u_resolution;
uniform sampler2D u_fftTexture;
uniform vec4 u_mouse;
uniform float u_time;

float hue2rgb(float p, float q, float t) {
  if(t < 0.0) t += 1.0;
  if(t > 1.0) t -= 1.0;
  if(t < 1.0/6.0) return p + (q - p) * 6.0 * t;
  if(t < 1.0/2.0) return q;
  if(t < 2.0/3.0) return p + (q - p) * (2.0/3.0 - t) * 6.0;
  return p;
}
vec3 hsl2rgb(float h, float s, float l) {
  float r, g, b;

  if (s == 0.0) {
    r = g = b = l; // Achromatic
    } else {
    float q = l < 0.5 ? l * (1.0 + s) : l + s - l * s;
    float p = 2.0 * l - q;
    r = hue2rgb(p, q, h + 1.0/3.0);
    g = hue2rgb(p, q, h);
    b = hue2rgb(p, q, h - 1.0/3.0);
  }

  return vec3(r, g, b);
}


// Function to create a 2D rotation matrix
mat2 rotate2D(float angle){
  float cosAngle = cos(angle);
  float sinAngle = sin(angle);
  return mat2(cosAngle, -sinAngle, sinAngle, cosAngle);
}

float noise(vec2 uv) {
  return fract(sin(dot(uv.xy, vec2(112.9898, 78.233))) * 43758.5453);
}
float noise23(vec2 uv) {
  return fract(sin(dot(uv.xy, vec2(13.9898, 121783.233))) * 1758.5453);
}
vec2 noise2(vec2 uv){
  return vec2(noise(uv), noise23(fract(uv*12312.123123)+vec2(11234.2, 112123.4343110)));
}

float perlinNoise(vec2 c){
  vec2 i = floor(c);
  vec2 f = fract(c);
  vec2 u = f * f * (3.0 - 2.0 * f);
  return mix(mix(dot( noise2(i + vec2(0.0, 0.0) ), f - vec2(0.0, 0.0)), 
  dot( noise2(i + vec2(1.0, 0.0) ), f - vec2(1.0, 0.0)), u.x),
  mix( dot( noise2(i + vec2(0.0, 1.0) ), f - vec2(0.0, 1.0)), 
  dot( noise2(i + vec2(1.0, 1.0) ), f - vec2(1.0, 1.0)), u.x), u.y);
}
// Modified FBM function for smoother output
float fbm(vec2 p) {
  float total = 0.0;
  float persistence = 0.5;
  float amplitude = 1.0;
  float maxValue = 0.0;  // Used for normalizing result to 0.0 - 1.0
  for(int i = 0; i < 12; i++) {
    total += perlinNoise(p) * amplitude;
    maxValue += amplitude;
    
    amplitude *= persistence;
    p *= 2.0;
  }
  return total/maxValue;
}

// Function to calculate brightness factor based on distance to event horizon
float calculateBrightnessFactor(float distance, float eventHorizonRadius, float influenceZoneRadius) {
  if (distance <= eventHorizonRadius) {
    return 1.0; // Maximum brightness inside event horizon
    } else if (distance <= influenceZoneRadius) {
    float normalizedDistance = (distance - eventHorizonRadius) / (influenceZoneRadius - eventHorizonRadius);
    return pow(1.0 - normalizedDistance, 3.0); // Cubic falloff for smoothness
    } else {
    return 0.0; // No additional brightness outside influence zone
  }
}

// Modified nebulaColor function to include brightness factor calculation
vec3 nebulaColor(float fbmValue, float hue, float distanceToEventHorizon, float eventHorizonRadius) {
  // Define the radius of the influence zone where the nebula will start to brighten
  float influenceZoneRadius = eventHorizonRadius + 2.1; // Adjust this value as needed

  // Calculate the brightness factor
  float brightnessFactor = calculateBrightnessFactor(distanceToEventHorizon, eventHorizonRadius, influenceZoneRadius);

  // Calculate the final lightness based on FBM value and brightness factor
  float lightness = mix(fbmValue/1.4, 2.5, fbmValue * brightnessFactor); // Mix to avoid exceeding 1.0


  // Convert HSL to RGB using the given hue and calculated lightness
  vec3 color = hsl2rgb(hue, 1.0, lightness);
  color += brightnessFactor * 0.1; // Add a bit of brightness to the nebula
  return color;
}

// Function to create an anisotropic scaling matrix
mat2 anisotropicScale(float xScale, float yScale) {
  return mat2(xScale, 0.0, 0.0, yScale);
}

float Star(vec2 uv, float flare){
  float d = length(uv);
  float m = .02/d;
  float rays = max(0., 1.-abs(uv.x*uv.y*1000.))*0.1;
  m+=rays * flare;
  uv *= rotate2D(3.1415/4.);
  rays = max(0., 1.-abs(uv.x*uv.y*100000.))*0.9;
  m += rays*0.3*flare;
  m *= smoothstep(0.6,.01, d);
  return m;
}

vec3 starLayer(vec2 uv, float time, float scale, vec2 off){
  
  uv += off;
  uv *= scale;
  vec3 color = vec3(0);
  vec2 gv = fract(uv) - 0.5;
  vec2 id = floor(uv);
  for (int y = -1; y <= 1; y++) {
    for (int x = -1; x <= 1; x++) {
      vec2 offset = vec2(x, y);
      float n = noise(id + offset);
      float size = fract(n * 1343.32*250.);
      float star = Star(gv - offset - vec2(n, fract(n * 3334.)) + 0.5, smoothstep(.3, 0.9, size));
      vec3 starColor = sin(vec3(0.5, 0.5, .5) * fract(n * 2345.2) * 123.12) * .5 + .5;
      starColor *= vec3(.4, 0.4, .1 + size);
      star *= sin(time * n * 6.3) * 0.5 + 1.;
      color += star * size * starColor;
    }
  }
  return color;
}

vec2 lensingEffect(vec2 uv, vec2 center, float radius, float strength) {
  vec2 toCenter = center - uv;
  float distance = length(toCenter);
  float effect = smoothstep(radius, radius * 0.5, distance) * strength;

  // This will distort the UVs to create a stretching effect towards the center
  toCenter = normalize(toCenter) * effect;
  uv += toCenter;

  return uv;
}

vec2 gravitationalLensing(vec2 uv, vec2 blackHoleCenter, float mass) {
  vec2 delta = uv - blackHoleCenter;
  float r = length(delta)*2.0;
  float lensingStrength = mass / (r * r);
  return uv + lensingStrength * normalize(delta);
}

vec3 goldenGlow(vec2 uv, vec2 center, float innerRadius, float outerRadius, float distortionStrength, float time) {
  // Calculate radial distance from the center
  float dist = distance(uv, center);
  
  // Create a radial gradient
  float glow = smoothstep(outerRadius, innerRadius, dist);
  
  // Apply a golden color to the glow
  vec3 color = vec3(1.0, 0.843, 0.0); // Gold color
  
  // Distort the glow using noise
  float noiseValue = noise(uv * 10.0 + time);
  glow *= (1.0 + distortionStrength * noiseValue);
  
  // Return the colored and distorted glow
  return glow * color;
}


// Main function
void main() {
  // Normalize screen coordinates
  vec2 uv = (2.0 * gl_FragCoord.xy - u_resolution) / min(u_resolution.x, u_resolution.y);
  uv *= rotate2D(3.14159/3.0);
  // Time parameter for animation
  float time = u_time * 0.2;
  // Set the black hole parameters
  vec2 blackHoleCenter = vec2(0.0, 0.0); // Center of the black hole in UV space
  float blackHoleRadius = 0.5; // Radius of black hole effect in UV space
  float lensStrength = 2.0; // Strength of the lensing effect

  // Apply gravitational lensing to UV coordinates
  vec2 lensedUv = uv;
  lensedUv = lensingEffect(uv, blackHoleCenter, blackHoleRadius, lensStrength);
  lensedUv += gravitationalLensing(uv, blackHoleCenter, 0.42);

  lensedUv.y += time;
  blackHoleCenter.y += time;
  float distanceToEventHorizon = length(lensedUv - blackHoleCenter);
  // Calculate the distance from the center of the black hole
  float distanceFromCenter = length(lensedUv - blackHoleCenter);

  // Calculate the angle between the UV coordinates and a reference direction (e.g., x-axis)
  float angle = atan(lensedUv.y - blackHoleCenter.y, lensedUv.x - blackHoleCenter.x);

  // Define scaling factors for the X and Y axes (adjust as needed)
  float xScale = 1.0; // No stretching in the X-axis
  float yScale = 1.0; // No stretching in the Y-axis
  // Extract bass, mid, and treble values from the FFT texture
  float bass = texture2D(u_fftTexture, vec2(0.00, 0.0)).r;
  float mid = texture2D(u_fftTexture, vec2(0.3, 0.0)).r;
  float treble = texture2D(u_fftTexture, vec2(0.2, 0.0)).r;
  float b = pow(bass, 6.0);
  // Apply angle-based bias to the stretching (e.g., stretching more in the vertical direction)
  float angleBias = sin(angle * 5.0); // Adjust the factor for the desired bias
  vec2 nebulaUv = lensedUv;
  // Apply the anisotropic scaling to the UV coordinates
  nebulaUv = (anisotropicScale(xScale, yScale + angleBias) * (nebulaUv - blackHoleCenter)) + blackHoleCenter;

  float fbmValue = fbm(nebulaUv * 0.5 + u_time * 0.1); // You can play with these values
  vec3 nebula = nebulaColor(fbmValue, 1.0*.3+.8, distanceToEventHorizon, blackHoleRadius);
  fbmValue = fbm(nebulaUv * 0.25 + u_time * 0.05); // You can play with these values
  vec3 nebula2 = nebulaColor(fbmValue, .6, distanceToEventHorizon, blackHoleRadius);
  // red nebulae
  fbmValue = fbm(nebulaUv * 0.5 + u_time * 0.1+4.0); // You can play with these values
  vec3 nebula3 = nebulaColor(fbmValue, 0.01, distanceToEventHorizon, blackHoleRadius);
  vec3 color = vec3(0);
  color += nebula2*4.;
  color += starLayer(lensedUv*rotate2D(3.14159/4.0), time, 4.0, vec2(time * 0.1, 0.0))*vec3(1., 1.2, sin(time*0.1)*0.5+0.5);
  color += nebula;
  color += starLayer(lensedUv+vec2(0.5, 0.5), time*3.0, 8.0, vec2(time * 0.08, 0.0))*vec3(1.6, 1.1, 0.02*sin(time*0.1)*0.5+0.5);
  color += nebula3;
  color += starLayer(lensedUv, time*2.0, 12.0, vec2(time * 0.05, 0.0))*vec3(1.5, 1., sin(time*0.01)*0.5+0.5);
  //color = nebula3;
  // create black hole
  float hole = length(uv);
  hole = smoothstep(0.33, 0.34, hole);
  color *= vec3(hole);
  // create black hole ring
  // Set the glow parameters
  float innerGlowRadius = 0.35;
  float outerGlowRadius = 0.45;
  float distortionStrength = 0.05;
  

  // create black hole glow

  // create black hole glow ring

  // create accretion disk

  // Set the final fragment color
  gl_FragColor = vec4(color, 1.0);
}