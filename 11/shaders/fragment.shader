#version 300 es
precision highp float;
// Uniform variables for resolution, FFT texture, mouse position, and time
uniform vec2 u_resolution;
uniform sampler2D u_fftTexture;
uniform vec2 u_mouse;
uniform float u_time;
#define PI 3.1415926535897932384626433832795

#define MAX_STEPS 200
#define MAX_DIST 10.
#define SURF_DIST 0.0001
#define TRANSITION_DURATION 20.0 // in seconds
#define GLOW_SIZE 50

struct CameraRotation {
    float phi;
    float theta;
    float transitionEndTime;
};

struct Camera {
    vec3 pos;
    vec3 target;
    vec3 dir;
    vec3 up;
    vec3 right;
    float fov;
};

struct Light {
    vec3 dir;
    vec3 color;
    float intensity;
};

struct March {
    float dist;
    int steps;
    float glow;
};

float t;

vec2 rotateAroundPoint(vec2 point, vec2 origin, float angle) {
    float s = sin(angle);
    float c = cos(angle);
    point -= origin;
    point = vec2(point.x * c - point.y * s, point.x * s + point.y * c);
    point += origin;
    return point;
}
// Initialize the camera
Camera initCamera(vec3 pos, vec3 target, vec3 up, float fov) {
    Camera cam;
    cam.pos = pos;
    cam.target = target;
    cam.dir = normalize(target - pos);
    cam.up = normalize(cross(cam.dir, up));
    cam.right = normalize(cross(cam.dir, cam.up));
    cam.fov = fov;
    return cam;
}

// Initialize the light
Light initLight(vec3 dir, vec3 color, float intensity) {
    Light light;
    light.dir = normalize(dir);
    light.color = color;
    light.intensity = intensity;
    return light;
}

// Compute the ray direction
vec3 getRay(Camera cam, vec2 uv) {
    mat3 m = mat3(cam.up, cam.right, cam.dir);
    return m * normalize(vec3(uv, cam.fov));
}

float sdTorus( vec3 p, vec2 t )
{
  vec2 q = vec2(length(p.xz)-t.x,p.y);
  return length(q)-t.y;
}

// Box SDF (Signed Distance Function)
float sdBox(vec3 p, vec3 b) {
    vec3 q = abs(p) - b;
    return length(max(q, 0.0)) + min(max(q.x, max(q.y, q.z)), 0.0);
}


// From IQ: https://iquilezles.org/articles/distfunctions/

float smUnion( float d1, float d2, float k )
{
    float h = clamp( 0.5 + 0.5*(d2-d1)/k, 0.0, 1.0 );
    return mix( d2, d1, h ) - k*h*(1.0-h);
}


float sdSphere(vec3 p, vec4 sphere) {
    return length(p-sphere.xyz)-sphere.w;
}


vec3 repeat(vec3 p, vec3 c) {
    return mod(p + 0.5 * c, c) - 0.5 * c;
}

// Scene distance estimator
float mapScene(vec3 p) {
  float bass = texture(u_fftTexture, vec2(0.0, 0.0)).r*.33;
  float mid = texture(u_fftTexture, vec2(0.3, 0.0)).r * .33;
  float invBass = 1.4 - bass;
  float invMid = 1.5 - mid;
    p.x += (1.-cos(p.z*5.*invBass+t)*.2 + 1.-sin(p.y*3.*invMid+t)*.3)*.5+.5;
    p.y += (1.-cos(p.x*5.*invMid+t)*.2 + 1.-sin(p.z*3.*invBass+t)*.3)*.5-.5;
    float d = sdSphere(p, vec4(0,0,0,3.0+bass*2.));//sdMengerSponge(p, 5, 2.0);
    p.x += (1.-cos(p.z*5.*invMid+t)*.2 + 1.-sin(p.y*3.*invBass+t)*.3)*.5+.5;
    p.y += (1.-cos(p.x*5.*invBass+t)*.2 + 1.-sin(p.z*3.*invMid+t)*.3)*.5-.5;
    float d2 = sdSphere(p, vec4(4.0,1.0,0,2.4 -sin(mid)));//sdMengerSponge(p, 5, 2.0);
    p += vec3(-4.0,0,0);
    //float d3 = sdTorus(p, vec2(3.4, .5));
    return max(0.,smUnion(smUnion(d, d2*.6, .2), 110.0, .5));
    //return d3;
}

// Perform ray marching and calculate glow
March rayMarch(vec3 rayOrigin, vec3 rayDir) {
    float t = 0.0;
    float glow = 0.0;
    int i = 0;
    for (i = 0; i < MAX_STEPS; i++) {
        vec3 pos = rayOrigin + t * rayDir;
        float dist = mapScene(pos);

        if (abs(dist) < SURF_DIST || dist > MAX_DIST) {
            if(dist < SURF_DIST) dist -= SURF_DIST * 0.5;
            break;
        }
        t += dist;
        // Adjust the glow calculation here. We need to ensure that the glow is noticeable.
        // You can adjust the multiplier and the exponent based on your scene's scale and aesthetics.
        glow += exp(-dist * dist * .3); // Increase the multiplier if glow is not visible.
    }
    March march;
    march.dist = t;
    march.steps = i;
    float treble = texture(u_fftTexture, vec2(0.36, 0.0)).r;
    // Adjust the normalization of glow factor based on the range of steps where glow is significant.
    march.glow = glow / float(GLOW_SIZE)-treble;
    return march;
}

out vec4 fragColor;
// Main function
void main() {
 // Normalize UV coordinates
    vec2 uv = (gl_FragCoord.xy - u_resolution.xy * 0.5) / u_resolution.y;
    float iTime = u_time * 0.001;
    t = mod(iTime, 6.28);
    float bass = texture(u_fftTexture, vec2(0.1, 0.0)).r*.33;
    // Update camera rotation based on mouse input and time
    
    // Calculate camera position 
    vec3 camPos = vec3(1.,0,-6.5);
    camPos.xz = rotateAroundPoint(camPos.xz, vec2(0.0, 0.0), mod(iTime*.2, 2.*PI));
    camPos.xy = rotateAroundPoint(camPos.xy, vec2(0.0, 0.0), mod(iTime*.12, 2.*PI));
    // Initialize camera and light
    Camera cam = initCamera(camPos, vec3(0.0, 0.0, 0.0), vec3(0.0, -1.0, 0.0), 0.5);
    Light light = initLight(vec3(1.0, 1.0, -1.0), vec3(1.0, 1.0, 1.0), 1.0);
    // Construct ray using camera and UV coordinates

    // orbit camera around 0,0,0 origin
    

    vec3 rayOrigin = cam.pos;
    vec3 rayDir = getRay(cam, uv);
    // Ray marching
    March m = rayMarch(rayOrigin, rayDir);
    float t = m.dist;
    vec3 col = vec3(0.1, 0.2, 0.3);
    vec3 vigCol = vec3(.0, .5, .4);
    vec3 vignette = (1. - vigCol * vec3(length(uv)))+.5;
    col *= vignette;

    // If the ray hits the surface, calculate the color and lighting
    if (m.dist < MAX_DIST) {
        vec3 normal = normalize(rayOrigin + m.dist * rayDir); // Approximate normal
        float diff = max(dot(normal, light.dir), 0.0); // Diffuse lighting
        col = mix(vec3(0.1+bass, 0.12, 0.3), vec3(1.0, .8, 1.0) * light.intensity, diff); // Surface color
    }
    
     // Apply glow effect with smooth interpolation
    float glowFactor = smoothstep(0.0, 1.0, m.glow);
    col += vec3(.8-bass, 0.2, 0.7) * glowFactor; // Additive glow
    float tt = t / 6.28;
    //col.y = tt/20. - uv.x*sin(t*10.);
    //col.x *= 2.1-(1.-t/6.28);
    //col *= 1.-col;
    col *= 1.2;
    col.x *= 1.2-(uv.x*.5+.5);
    fragColor = vec4(col, 1.0);
}