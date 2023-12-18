#version 300 es
precision highp float;
precision mediump sampler3D;
// Uniform variables for resolution, FFT texture, mouse position, and time
uniform vec2 u_resolution;
uniform sampler2D u_fftTexture;
uniform samplerCube u_env;
uniform vec2 u_mouse;
uniform float u_time;
#define PI 3.1415926535897932384626433832795
vec3 sceneMovement = vec3(0.0);
#define BOUNCES 2
#define MAX_STEPS 400
#define MAX_DIST 10000.
#define SURF_DIST 0.001
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
    float matId;
};

float t;

float rand(vec2 co){
    return fract(sin(dot(co.xy ,vec2(12.9898,78.233))) * 43758.5453);
}

vec2 noise(vec2 p){
    vec2 ip = floor(p);
    vec2 u = fract(p);
    u = u*u*(3.0-2.0*u);
    float res = mix(
    mix(rand(ip),rand(ip+vec2(1.0,0.0)),u.x),
    mix(rand(ip+vec2(0.0,1.0)),rand(ip+vec2(1.0,1.0)),u.x),
    u.y
    );
    return vec2(res,res);
}
vec3 random3(vec3 c) {
    float j = 4096.0*sin(dot(c,vec3(17.0, 59.4, 15.0)));
    vec3 r;
    r.z = fract(512.0*j);
    j *= .125;
    r.x = fract(512.0*j);
    j *= .125;
    r.y = fract(512.0*j);
    return r-0.5;
}
float noise(vec3 p){
    const vec3 F3 = vec3(0.3333333, 0.3333333, 0.3333333);
    const vec3 G3 = vec3(0.1666667, 0.1666667, 0.1666667);
    vec3 s = floor(p + dot(p, F3));
    vec3 x = p - s + dot(s, G3);
    
    vec3 e = step(vec3(0.0), x - x.yzx);
    vec3 i1 = e * (1.0 - e.zxy);
    vec3 i2 = 1.0 - e.zxy*(1.0 - e);
    
    vec3 x1 = x - i1 + G3;
    vec3 x2 = x - i2 + 2.0 * G3;
    vec3 x3 = x - 1.0 + 3.0 * G3;
    
    vec4 w, d;
    
    w.x = dot(x, x);
    w.y = dot(x1, x1);
    w.z = dot(x2, x2);
    w.w = dot(x3, x3);
    
    w = max(0.6 - w, 0.0);
    
    d.x = dot(random3(s), x);
    d.y = dot(random3(s + i1), x1);
    d.z = dot(random3(s + i2), x2);
    d.w = dot(random3(s + 1.0), x3);
    
    w *= w;
    w *= w;
    d *= w;
    
    return dot(d, vec4(52.0));
}



// Simplex noise through octaves
float simplexNoise(vec3 p, float t){
    float f = 0.0;
    float a = 0.5;
    float frequency = 1.0;
    for(int i = 0; i < 4; i++){
        f += a * noise(p * frequency + t);
        frequency *= 2.0; // Increasing frequency for each octave
        a *= 0.5; // Decreasing amplitude for each octave
    }
    return f;
}

mat2 rotate2d(float _angle){
    return mat2(cos(_angle),-sin(_angle),
    sin(_angle),cos(_angle));
}

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
// Initialize the light with a direction pointing towards the scene from the horizon
Light initLight(vec3 pos, vec3 target, vec3 color, float intensity) {
    Light light;
    light.dir = normalize(target - pos);
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

float sdPlane(vec3 p, vec3 n, float h) {
    return dot(p, n) + h;
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



float sdOctahedron( vec3 p, float s)
{
    p = abs(p);
    return (p.x+p.y+p.z-s)*0.57735027;
}

// terrain distanace field
float sdMountainRange(vec3 p, float scale, float height, float dist) {
    p *= scale;
    p.y -= height;
    // use simplexNoise
    float n = simplexNoise(p, dist) * height;
    // distort a plane using noise in the up direction 
    
    p.y += n * height;
    float plane = sdPlane(p, vec3(0.0, 1.0, 0.0), -height);
    return plane;

}
// Scene distance estimator
vec2 mapScene(vec3 p) {
    vec3 po = p - sceneMovement;
    po = repeat(po, vec3(20.0, 15.0, 5.0));

    // rotate repeated octahedrons individually around their center, offset by grid position
    

    po.xz *= rotate2d(u_time*.001);
    po += vec3(0.0, -1.75, 0.0);


    float d = sdOctahedron(po, .05);
    float water = sdMountainRange(p, 2.2, .1, t);
    p.y += 1.0;
    p.y += simplexNoise(p*0.04, 200.1)*5.;  

    // only render mountains far away, use a box to cut away near mountains
    // return minimum distance and material id water = 0, octahedron = 1
    if(water < d){
        return vec2(water, 0.);
        } else {
        return vec2(d, 1.);
    }

}

// Perform ray marching and calculate glow
March rayMarch(vec3 rayOrigin, vec3 rayDir) {
    float t = 0.0;
    float glow = 0.0;
    int i = 0;
    March march;
    for (i = 0; i < MAX_STEPS; i++) {
        vec3 pos = rayOrigin + t * rayDir;
        vec2 res = mapScene(pos);
        float dist = res.x-.7;

        if (abs(dist) < SURF_DIST || dist > MAX_DIST) {
            if(dist < SURF_DIST) dist -= SURF_DIST * 0.5;
            march.matId = res.y;
            break;
        }
        t += dist;
        // Adjust the glow calculation here. We need to ensure that the glow is noticeable.
        // You can adjust the multiplier and the exponent based on your scene's scale and aesthetics.
        glow += exp(-dist * dist * .3); // Increase the multiplier if glow is not visible.
    }
    march.dist = t;
    march.steps = i;
    float treble = texture(u_fftTexture, vec2(0.36, 0.0)).r;
    // Adjust the normalization of glow factor based on the range of steps where glow is significant.
    // march.glow = glow / float(GLOW_SIZE)-treble;
    return march;
}

vec3 getNormal(vec3 pos) {
    vec2 e = vec2(0.001, 0.0);
    return normalize(vec3(
    mapScene(pos + e.xyy).x - mapScene(pos - e.xyy).x,
    mapScene(pos + e.yxy).x - mapScene(pos - e.yxy).x,
    mapScene(pos + e.yyx).x - mapScene(pos - e.yyx).x
    ));
}   

vec3 getReflection(vec3 rayDir, vec3 normal) {
    return normalize(rayDir - 2.0 * dot(rayDir, normal) * normal);
}


float getAO(vec3 pos, vec3 normal) {
    float ao = 0.0;
    float total = 0.0;
    float r = 0.1;
    for (float phi = 0.0; phi < 2.0 * PI; phi += 0.5) {
        for (float theta = 0.0; theta < PI; theta += 0.5) {
            vec3 dir = vec3(cos(phi) * sin(theta), sin(phi) * sin(theta), cos(theta));
            ao += (r - mapScene(pos + r * dir)).x / r;
            total += 1.0;
        }
    }
    return clamp(1.0 - ao / total, 0.0, 1.0);
}

vec3 getSoftShadowsWithPenumbra(vec3 pos, vec3 normal, Light light) {
    float shadow = 1.0;
    float total = 0.0;
    float r = 0.1;
    for (float phi = 0.0; phi < 2.0 * PI; phi += 0.5) {
        for (float theta = 0.0; theta < PI; theta += 0.5) {
            vec3 dir = vec3(cos(phi) * sin(theta), sin(phi) * sin(theta), cos(theta));
            float dist = mapScene(pos + r * dir).x;
            if (dist < r) {
                shadow -= 1.0 - smoothstep(0.0, 1.0, dist / r);
            }
            total += 1.0;
        }
    }
    return clamp(shadow / total, 0.0, 1.0) * light.color;
}


vec3 render(vec3 ro, vec3 rd, Light light){
    // Ray marching
    vec3 accColor = vec3(0.0);
    vec3 currentRO = ro;
    vec3 currentRD = rd;
    float reflectivity = 0.8;

    // do bounces for scene reflections

    for(int bounce = 0; bounce < BOUNCES; bounce++){
        March m = rayMarch(ro, rd);
        float t = m.dist;
        vec3 bg = texture(u_env, rd).rgb;
        //colorize bg

        bg = mix(bg, vec3(1.0, .8, 1.0) * light.intensity+bg*.4, max(dot(rd, light.dir), 0.0));
        vec3 col = bg;
        // If the ray hits the surface, calculate the color and lighting
        if (m.dist < MAX_DIST) {
            vec3 normal = getNormal(currentRO + currentRD * t);
            float diff = max(dot(normal, light.dir), 0.0); // Diffuse lighting
            vec3 reflection = getReflection(rd, normal);
            float spec = pow(max(dot(reflection, light.dir), 0.0), 16.0); // Specular lighting
            float ao = getAO(currentRO + currentRD * t, normal); // Ambient occlusion
            vec3 shadow = getSoftShadowsWithPenumbra(ro + rd * t, normal, light); // Soft shadows
            vec3 cubeMapref = texture(u_env, reflection).rgb;
            vec3 diffuseColor = vec3(0.0);
            if(m.matId == 1.0){
                diffuseColor = vec3(0.4, 0.12, 0.0);
            }
            col = mix(diffuseColor, vec3(1.0, .8, 1.0) * light.intensity, diff); // Surface color
            //col = mix(vec3(0.1, 0.12, 0.3), vec3(1.0, .8, 1.0) * light.intensity, diff); // Surface color
            col += vec3(1.0, 0.9, 0.8) * spec; // Add specular lighting
            col *= cubeMapref;
            col += shadow * ao * (1.0 - t / MAX_DIST);
            currentRD = reflection;
            currentRO = ro + rd * t + normal * SURF_DIST;
            accColor += col * reflectivity;
            reflectivity *= 0.5;


            } else {
            accColor = vec3(0);
        }
        // as the distance increases, the color fades to background color
        col = clamp(col, vec3(0.0), vec3(1.0));
        float fog = clamp(1.0 - exp(-t * t * 0.01), 0.0, 1.0);
        float fog2 = clamp(1.0 - exp(-t * t * 0.00003), 0.0, 1.0);
        if(m.matId == 0.0)
            col = mix(col, bg, fog);
        else 
            col = mix(col, vec3(0.8, 0.8, 1.), fog2);
        accColor += col*reflectivity;
    }
    
    return accColor;

}
out vec4 fragColor;
// Main function
void main() {
    // Normalize UV coordinates
    vec2 uv = (gl_FragCoord.xy - u_resolution.xy * 0.5) / u_resolution.y;
    float iTime = u_time * 0.001;

    // Static camera position and target
    vec3 camPos = vec3(0.0, 1.0, -11.5);
    vec3 camTarget = vec3(0.0, 0.0, 0.0); 
    vec3 camDirTarget = vec3(0.0, 1.0, 0.0);
    // Calculate Lissajous curve position for X and Y
 
    float camAngle = 2.11;
    camPos.xz = rotateAroundPoint(camPos.xz, vec2(0.0, 0.0),camAngle);
    // Initialize camera and light
    Camera cam = initCamera(camPos, camTarget, vec3(0.0, -1.0, 0.0), 1.5);

       float A = 3.0; // Amplitude of the X axis
    float B = 1.0; // Amplitude of the Y axis
    float a = .3; // Frequency of the X axis
    float b = .2; // Frequency of the Y axis
    float lissajousX = A * sin(a * iTime + PI * 0.5);
    float lissajousY = B * sin(b * iTime);

    // Get the water surface height at the camera's XY position

    // Ensure the camera's Y position is above the water surface
    float minimumHeightAboveWater = .5; // Minimum height above the water surface
    float camY = abs(lissajousY) + minimumHeightAboveWater;
    float camX = lissajousX;
    // Set the camera position
    float sunPhi = 0.75; // Change this to control the sun's position along the horizon
    
    // Position the light source at the horizon and point it towards the center of the scene
    vec3 lightPos = vec3(10.0 * cos(sunPhi), -1000.0, 10000.0 * sin(sunPhi)); // Position the light source far away
    vec3 lightTarget = vec3(0.0, 0.0, 0.0); // Target the center of the scene
    Light light = initLight(lightPos, lightTarget, vec3(1.0, 0.8, 0.6), 1.0); // Use a warm color for the light
    // Construct ray using camera and UV coordinates
    cam.pos.y = camY;
    cam.pos.x = camX;
vec3 camDir = normalize(camDirTarget - camPos);
    
    // orbit camera around 0,0,0 origin
    vec3 rayOrigin = cam.pos;
    vec3 rayDir = getRay(cam, uv);
    // Simulate movement by translating the scene towards the camera
    float movementSpeed = .5; // Adjust the speed of movement
    sceneMovement = camDir * movementSpeed * iTime;
    // Render the scene with translated coordinates
    vec3 col = render(rayOrigin + sceneMovement, rayDir, light);
    // col = vec3(simplexNoise(vec3(uv, iTime*0.01)*10., 0.1));  
    fragColor = vec4(col, 1.0);
}