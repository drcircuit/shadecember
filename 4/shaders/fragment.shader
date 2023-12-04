#ifdef GL_ES
  precision highp float;
#endif

// Uniform variables for resolution, FFT texture, mouse position, and time
uniform vec2 u_resolution;
uniform sampler2D u_fftTexture;
uniform vec4 u_mouse;
uniform float u_time;

// Structure representing a camera ray
struct CameraRay {
  vec3 origin;
  vec3 direction;
};

// Function to create a 2D rotation matrix
mat2 rotate2D(float angle){
  float cosAngle = cos(angle);
  float sinAngle = sin(angle);
  return mat2(cosAngle, -sinAngle, sinAngle, cosAngle);
}

// Function to create a 3D rotation matrix around an axis
mat3 rotate3D(vec3 axis, float angle){
  float cosAngle = cos(angle);
  float sinAngle = sin(angle);
  float oneMinusCos = 1.0 - cosAngle;
  
  return mat3(
    oneMinusCos * axis.x * axis.x + cosAngle, oneMinusCos * axis.x * axis.y - axis.z * sinAngle, oneMinusCos * axis.z * axis.x + axis.y * sinAngle,
    oneMinusCos * axis.x * axis.y + axis.z * sinAngle, oneMinusCos * axis.y * axis.y + cosAngle, oneMinusCos * axis.y * axis.z - axis.x * sinAngle,
    oneMinusCos * axis.z * axis.x - axis.y * sinAngle, oneMinusCos * axis.y * axis.z + axis.x * sinAngle, oneMinusCos * axis.z * axis.z + cosAngle
  );
}

// Function to calculate a camera ray
CameraRay getCameraRay(vec2 uv, vec3 position, vec3 lookAt, float fieldOfView, float spinAngle){
  CameraRay camera;
  camera.origin = position;
  vec3 forward = normalize(lookAt - position);
  
  // Rotate the 'up' vector around the 'forward' direction
  vec3 up = cross(vec3(0.0, 1.0, 0.0), forward);
  vec3 right = cross(forward, up);
  mat3 spinRotation = rotate3D(forward, spinAngle);
  right = spinRotation * right;
  up = cross(right, forward);
  
  vec3 imagePlane = position + forward * fieldOfView;
  vec3 point = imagePlane + right * uv.x + up * uv.y;
  camera.direction = normalize(point - position);
  return camera;
}

// Function to find the closest point on the ray to a given point
vec3 closestPointOnRay(CameraRay ray, vec3 point){
  float t = dot(point - ray.origin, ray.direction);
  return ray.origin + ray.direction * t;
}

// Function to calculate the distance from a point to a camera ray
float distanceToCameraRay(CameraRay ray, vec3 point){
  return length(closestPointOnRay(ray, point) - point);
}

// Lorenz Attractor function
vec3 lorenzAttractor(vec3 position, float deltaTime){
  float sigma = 10.0;
  float beta = 28.0;
  float rho = 8.0 / 3.0;

  float dx = sigma * (position.y - position.x);
  float dy = position.x * (beta - position.z) - position.y;
  float dz = position.x * position.y - rho * position.z;

  return vec3(position.x + dx * deltaTime, position.y + dy * deltaTime, position.z + dz * deltaTime);
}

// Main function
void main() {
  // Time parameter for animation
  float time = u_time * 0.1;

  // Extract bass, mid, and treble values from the FFT texture
  float bass = texture2D(u_fftTexture, vec2(0.0, 0.0)).r;
  float mid = texture2D(u_fftTexture, vec2(0.1, 0.0)).r;
  float treble = texture2D(u_fftTexture, vec2(0.2, 0.0)).r;

  // Normalized screen coordinates
  vec2 uv = (2.0 * gl_FragCoord.xy - u_resolution.xy) / u_resolution.y;

  // Camera setup
  float orbitRadius = 80.0 * (sin(time) * 0.5 + 0.5) + 10.0;
  float fieldOfView = 1.0 + 0.2 * (sin(time) * 0.5 + 0.5);
  vec3 butterflyCenter = vec3(0.0, 0.0, 20.0);

  // Orbiting camera position
  vec3 orbitAxis = normalize(vec3(1.0, 1.0, 0.0));
  vec3 baseCameraPosition = vec3(orbitRadius, 0.0, 0.0);
  vec3 cameraPosition = rotate3D(orbitAxis, time) * baseCameraPosition;
  vec3 cameraLookAt = butterflyCenter;

  // Calculate the camera ray
  CameraRay ray = getCameraRay(uv, cameraPosition, cameraLookAt, fieldOfView, time);

  // Initial position for the Lorenz Attractor
  vec3 attractorPosition = vec3(0.1, 0.1, 0.1);
  vec3 accumulatedColor = vec3(0.0);

  // Smaller, constant time step for particle movement
  float deltaTime = 0.009;
  vec3 offset2 = vec3(-2.0 * sin(0.0), 1.0 * cos(0.0), 10.0 * sin(0.0));
  
  // Iterate over particles for the first component
  for(float i = 0.0; i < 1000.0; i++) {
    attractorPosition = lorenzAttractor(attractorPosition, deltaTime + time * 0.00001);
    float distance = 2.0 / (0.1 + distanceToCameraRay(ray, attractorPosition + offset2));
    accumulatedColor += vec3(distance);
  }
  
  vec3 offset = vec3(-3.0 * sin(mid), 5.0 * cos(treble), -4.0 * sin(bass));
  vec3 attractorPosition2 = vec3(0.1, -1.1, 0.1);
  accumulatedColor *= accumulatedColor/250.0;
  // Iterate over particles for the second component
  for(float i = 0.0; i < 1000.0; i++) {
    attractorPosition2 = lorenzAttractor(attractorPosition2, deltaTime + time * 0.000011);
    float distance = 1.5 / (distanceToCameraRay(ray, attractorPosition2 + offset * 0.5));
    accumulatedColor.b += distance * 2.0;
    accumulatedColor.g += distance * 0.5;
  }

  vec3 offset3 = vec3(2.0 * sin(mid), -1.0 * cos(bass), -4.0 * sin(treble));
  vec3 attractorPosition3 = vec3(0.1, -1.1, 0.1);
  // Iterate over particles for the third component
  for(float i = 0.0; i < 500.0; i++) {
    attractorPosition3 = lorenzAttractor(attractorPosition3, 0.1 * deltaTime + (sin(time) * 0.5 + 0.5) * 0.0061);
    float distance = 1.5 / (distanceToCameraRay(ray, attractorPosition3 + offset3 * 0.2));
    accumulatedColor.r += distance;
    accumulatedColor.b += 0.6 * distance;
    accumulatedColor.b += 0.2 * (cos(distance) * 0.5 + 0.5);
  }

  // Normalize the accumulated color
  accumulatedColor /= 750.0 ;  
  accumulatedColor *= 1.0 - length(uv) * 0.4;
  // Set the final fragment color
  gl_FragColor = vec4(accumulatedColor, 1.0);
}
