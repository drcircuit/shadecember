#version 300 es
precision mediump float;
precision mediump sampler3D;

#define AA 2
#define MAXDIST 130.0
#define SURFDIST 0.0001
#define MAXSTEPS 100
#define MOTION_BLUR_SAMPLES 1
vec4 orb;
// Uniform variables for resolution, FFT texture, mouse position, and time
uniform vec2 u_resolution;
uniform sampler2D u_fftTexture;
uniform samplerCube u_env;
uniform vec2 u_mouse;
uniform float u_time;
#define PI 3.1415926535897932384626433832795

float rand(vec2 co){
    return fract(sin(dot(co.xy ,vec2(12.9898,78.233))) * 43758.5453);
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

float map(vec3 p, float s) {
    float scale = 1.0f;
    p.y += simplexNoise(p, s) * .4f;
    p.xz *= mat2(cos(0.5f * s), sin(0.5f * s), -sin(0.5f * s), cos(0.5f * s));
    p.z += simplexNoise(p, s) * .15f;
    orb = vec4(1000.0f);

    for(int i = 0; i < 8; i++) {
        p = -1.0f + 2.0f * fract(0.5f * p + 0.5f);

        float r2 = dot(p, p);

        orb = min(orb, vec4(abs(p), r2));

        float k = s / r2;
        p *= k;
        scale *= k;
    }
    p *= 0.75f;
    return 0.25f * abs(1.f - p.z * p.y * p.x) / scale;
}

vec3 calcNormal(in vec3 pos, in float t, in float s) {
    float precis = 0.001f * t;

    vec2 e = vec2(1.0f, -1.0f) * precis;
    return normalize(e.xyy * map(pos + e.xyy, s) +
        e.yyx * map(pos + e.yyx, s) +
        e.yxy * map(pos + e.yxy, s) +
        e.xxx * map(pos + e.xxx, s));
}

float trace(in vec3 ro, in vec3 rd, float s) {
    float distAcc = 0.01f;
    for(int i = 0; i < MAXSTEPS; i++) {
        float minPrecission = SURFDIST * distAcc;

        float dist = map(ro + rd * distAcc, s);
        if(abs(dist) < minPrecission || distAcc > MAXDIST)
            break;
        distAcc += dist;
    }

    if(distAcc > MAXDIST)
        distAcc = -1.0f;
    return distAcc;
}

vec3 render(in vec3 ro, in vec3 rd, in float anim) {
    // trace	
    vec3 col = vec3(1.0f);
    float t = trace(ro, rd, anim);
    vec3 fogColor = vec3(0.8f, 0.9f, 1.0f);

    if(t > 0.0f) {
        vec4 trap = orb;
        vec3 pos = ro + t * rd;
        vec3 normal = calcNormal(pos, t, anim);

        // lighting
        vec3 light1 = vec3(0.6f, 0.8f, -2.2f);
        vec3 light2 = vec3(-1.5f, -1.000f, 1.4f);
        float key = clamp(dot(light1, normal), 0.0f, 1.0f);
        float bac = clamp(0.2f + 1.8f * dot(light2, normal), 0.0f, 1.0f);
        float amb = (2.0f + 0.4f * normal.y);
        float ao = pow(clamp(trap.w * 2.0f, 0.0f, 1.0f), 1.2f);

        vec3 brdf = 1.0f * vec3(0.40f, 0.40f, 0.40f) * amb * ao;
        brdf += 1.0f * vec3(1.00f, 1.00f, 1.00f) * key * ao;
        brdf += 1.0f * vec3(0.40f, 0.40f, 0.40f) * bac * ao;

        // material		
        vec3 rgb = vec3(1.0f, 1.0f, 1.0f);
        rgb = mix(rgb, vec3(.4f, 0.80f, 1.0f), clamp(6.0f * cos(trap.y * 50.f), 0.0f, 1.0f));
        rgb = mix(rgb, vec3(.2f, 0.55f, 1.0f), pow(clamp(1.0f - 2.0f * sin(trap.z * 10.f), 0.0f, 1.0f), 8.0f));
        float fogAmount = clamp(1.0f - exp(-t * t * 0.01f), 0.0f, 1.0f);
        rgb = mix(rgb, fogColor, fogAmount);
        col = rgb * brdf;
    }
    float fogAmount = clamp(1.0f - exp(-t * t * 0.05f), 0.0f, 1.0f);
    col = mix(col, fogColor, fogAmount);
    return sqrt(col);
}

vec3 rotateVectorAroundAxis(vec3 v, vec3 axis, float angle) {
    float cosAngle = cos(angle);
    float sinAngle = sin(angle);
    return v * cosAngle + cross(axis, v) * sinAngle + axis * dot(axis, v) * (1.0f - cosAngle);
}

out vec4 fragColor;
void main() {
    vec4 fragCoord = gl_FragCoord;
    float iTime = u_time * 0.0002f;
    float time = iTime * 0.25f;
    float anim = 1.1f + 0.5f * smoothstep(-0.3f, 0.3f, cos(0.1f * iTime));
     // Motion blur variables
    float blurTimeStep = .001f; // Time step for motion blur samples

    vec3 tot = vec3(0.0f);
    vec3 motionBlurTot = vec3(0.0f);
    for(int jj = 0; jj < AA; jj++) for(int ii = 0; ii < AA; ii++) {
            vec2 q = fragCoord.xy + vec2(float(ii), float(jj)) / float(AA);
            vec2 p = (2.0f * q - u_resolution.xy) / u_resolution.y;

            // camera
            vec3 ro = vec3(2.8f * cos(0.1f + .33f * time), 0.4f + 0.30f * cos(0.37f * time), 2.8f * cos(0.5f + 0.35f * time));
            vec3 ta = vec3(1.9f * cos(1.2f + .41f * time), 0.4f + 0.10f * cos(0.27f * time), 1.9f * cos(2.0f + 0.38f * time));
            float roll = 0.2f * cos(0.1f * time);
            vec3 cw = normalize(ta - ro);
            vec3 cp = vec3(sin(roll), cos(roll), 0.0f);
            vec3 cu = normalize(cross(cw, cp));
            vec3 cv = normalize(cross(cu, cw));
            // Angle of rotation
            float rotationAngle = sin(iTime * 0.5f); // or any other function of time

            // Rotate up and right vectors around the direction vector
            cu = rotateVectorAroundAxis(cu, cw, rotationAngle);
            cv = rotateVectorAroundAxis(cv, cw, rotationAngle);
            vec3 rd = normalize(p.x * cu + p.y * cv + 2.0f * cw);
            tot += render(ro, rd, anim);
             // Motion blur effect over previous frames
            for(int blurSample = 0; blurSample < MOTION_BLUR_SAMPLES; blurSample++) {
                float blurTimeOffset = anim - float(blurSample) * blurTimeStep;
                motionBlurTot += render(ro, rd, blurTimeOffset);
            }
        }

    // Combine current frame and motion blur frames
    vec3 finalColor = (tot + motionBlurTot) / float(AA * AA + MOTION_BLUR_SAMPLES * AA * AA);
    fragColor = vec4(finalColor, 1.0f);

}