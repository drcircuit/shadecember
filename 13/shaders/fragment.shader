#version 300 es
precision highp float;

// Uniform variables for resolution, FFT texture, mouse position, and time
uniform vec2 u_resolution;
uniform sampler2D u_fftTexture;
uniform samplerCube u_env;
uniform vec2 u_mouse;
uniform float u_time;
#define MaxSteps 100
#define MAXDIST 100.0
#define MinimumDistance 0.001
#define normalDistance     0.0002

#define Iterations 7
#define PI 3.141592
#define Scale 5.0
#define FOV 1.78
#define NUDGE 0.0005
#define FFAC 0.7
#define PERS 3.0

#define AMB 0.1
#define DIFF 0.5
#define LD1 vec3(0.0,0,-1.)
#define LC1 vec3(.1,1.0,0.858824)
#define LD2 vec3(sin(iTime*4.),-1.0,1.0)
#define LC2 vec3(0.0,0.333333,1.0)
#define Offset vec3(0.995,0.995,0.384)
float iTime = 0.0;
vec2 rotate(vec2 v, float a) {
	return vec2(cos(a)*v.x + sin(a)*v.y, -sin(a)*v.x + cos(a)*v.y);
}

// Two light sources. No specular 
vec3 getLight(in vec3 color, in vec3 normal, in vec3 dir) {
	float diff = max(0.0,dot(-normal, LD1)); // Lambertian
	
	float diff2 = max(0.0,dot(-normal, LD2)); // Lambertian
	
	return
	(diff*DIFF)*(LC1*color) +
	(diff2*DIFF)*(LC2*color);
}


float map(in vec3 z)
{

	z  = abs(1.0-mod(z,2.));

	float d = 1000.0;
	for (int n = 0; n < Iterations; n++) {
		z.xy = rotate(z.xy,2.0+2.0*cos( iTime/10.0));		
        z.xz = rotate(z.xy,100.0+100.0*.04*cos( iTime/15.0));	

		z = abs(z);
		if (z.x<z.y){ z.xy = z.yx;}
		if (z.x< z.z){ z.xz = z.zx;}
		if (z.y<z.z){ z.yz = z.zy;}
		z = Scale*z-Offset*(Scale-1.0);
        if(length(z) < 0.5)
        {
            d = 0.002;
            break;
        }   
        float dd = length(z) * pow(Scale, float(-n)-1.0);
		d = min(d, dd) * .75;
	}
	
	return d - 0.0001;
}

// Finite difference normal
vec3 getNormal(in vec3 pos) {
	vec3 e = vec3(0.0,normalDistance,0.0);
	
	return normalize(vec3(
			map(pos+e.yxx)-map(pos-e.yxx),
			map(pos+e.xyx)-map(pos-e.xyx),
			map(pos+e.xxy)-map(pos-e.xxy)
			)
		);
}

// Solid color 
vec3 getColor(vec3 normal, vec3 pos) {
	return vec3(1.0);
}


// Pseudo-random number
// From: lumina.sourceforge.net/Tutorials/Noise.html
float rand(vec2 co){
	return fract(cos(dot(co,vec2(4.898,7.23))) * 234121.631);
}

vec4 rayMarch(in vec3 from, in vec3 dir, in vec2 fragCoord) {
	// Add some noise to prevent banding
	float totalDistance = NUDGE*rand(fragCoord.xy+vec2(iTime));
	vec3 dir2 = dir;
	float distance;
	int steps = 0;
	vec3 pos;
	for (int i=0; i < MaxSteps; i++) {
		// Non-linear perspective applied here.
		dir.zy = rotate(dir2.zy,totalDistance*cos( iTime/4.0)*PERS);
		
		pos = from + totalDistance * dir;
		distance = map(pos)*FFAC;
		totalDistance += distance;
		if (distance > MAXDIST || abs(distance) < MinimumDistance) break;
		steps = i;
	}
	
	float smoothStep =   float(steps) + distance/MinimumDistance;
	float ao = 1.1-smoothStep/float(MaxSteps);
	
	// Since our distance field is not signed,
	// backstep when calc'ing normal
	vec3 normal = getNormal(pos-dir*normalDistance*3.0);
	vec3 fogColor = vec3(1.0,1.0, 2.2);
    float fog = clamp(1.0 - exp(-totalDistance*1.), 0.0, 1.0);
	vec3 color = getColor(normal, pos);
	vec3 light = getLight(color, normal, dir);
	color = (color*AMB+light)*ao;
    color = mix(fogColor, color, 1.-fog);

	return vec4(color,1.0);
}
out vec4 fragColor;
void main( )
{
    vec2 fragCoord = gl_FragCoord.xy;
    iTime = u_time * 0.0001;
	// Camera position (eye), and camera target
	vec3 camPos = 0.5*iTime*vec3(1.0,0.0,0.0);
	vec3 target = camPos + vec3(1.0,0.0*cos(iTime),0.0*sin(0.4*iTime));
	vec3 camUp  = vec3(0.0,1.0,0.0);
	
	// Calculate orthonormal camera reference system
	vec3 camDir   = normalize(target-camPos); // direction for center ray
	camUp = normalize(camUp-dot(camDir,camUp)*camDir); // orthogonalize
	vec3 camRight = normalize(cross(camDir,camUp));
	
	vec2 coord =-1.0+2.0*fragCoord.xy/u_resolution.xy;
	coord.x *= u_resolution.x/u_resolution.y;
	
	// Get direction for this pixel
	vec3 rayDir = normalize(camDir + (coord.x*camRight + coord.y*camUp)*FOV);
	
	fragColor = rayMarch(camPos, rayDir, fragCoord );
}




