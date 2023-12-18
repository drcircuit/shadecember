async function loadShader(url) {
    const response = await fetch(url)
    const text = await response.text()
    return text
}

function compileShader(gl, source, type) {
    const shader = gl.createShader(type)
    gl.shaderSource(shader, source)
    gl.compileShader(shader)
    if (gl.getShaderParameter(shader, gl.COMPILE_STATUS)) {
        return shader
    } else {
        console.log(gl.getShaderInfoLog(shader))
        gl.deleteShader(shader)
    }
}

function createProgram(gl, vertexShader, fragmentShader) {
    const program = gl.createProgram()
    gl.attachShader(program, vertexShader)
    gl.attachShader(program, fragmentShader)
    gl.linkProgram(program)
    if (gl.getProgramParameter(program, gl.LINK_STATUS)) {
        return program
    } else {
        console.log(gl.getProgramInfoLog(program))
        gl.deleteProgram(program)
    }
}

function createRenderQuad(gl) {
    const positionBuffer = gl.createBuffer()
    gl.bindBuffer(gl.ARRAY_BUFFER, positionBuffer)
    gl.bufferData(
        gl.ARRAY_BUFFER,
        new Float32Array([
            -1, -1, 1, -1, -1, 1,
            -1, 1, 1, -1, 1, 1
        ]),
        gl.STATIC_DRAW
    )
    const positionLocation = gl.getAttribLocation(program, 'a_position')
    gl.enableVertexAttribArray(positionLocation)
    gl.vertexAttribPointer(positionLocation, 2, gl.FLOAT, false, 0, 0)
}

function createTexture(gl, image) {
    const texture = gl.createTexture()
    gl.bindTexture(gl.TEXTURE_2D, texture)
    gl.texImage2D(
        gl.TEXTURE_2D,
        0,
        gl.RGBA,
        gl.RGBA,
        gl.UNSIGNED_BYTE,
        image
    )
    gl.generateMipmap(gl.TEXTURE_2D)
    return texture
}

function createFramebuffer(gl, width, height) {
    const framebuffer = gl.createFramebuffer()
    gl.bindFramebuffer(gl.FRAMEBUFFER, framebuffer)
    const texture = gl.createTexture()
    gl.bindTexture(gl.TEXTURE_2D, texture)
    gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_MIN_FILTER, gl.LINEAR);
    gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_MAG_FILTER, gl.LINEAR);
    gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_WRAP_S, gl.CLAMP_TO_EDGE);
    gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_WRAP_T, gl.CLAMP_TO_EDGE);

    gl.texImage2D(
        gl.TEXTURE_2D,
        0,
        gl.RGBA,
        width,
        height,
        0,
        gl.RGBA,
        gl.UNSIGNED_BYTE,
        null
    )
    gl.framebufferTexture2D(
        gl.FRAMEBUFFER,
        gl.COLOR_ATTACHMENT0,
        gl.TEXTURE_2D,
        texture,
        0
    )

    if (gl.checkFramebufferStatus(gl.FRAMEBUFFER) !== gl.FRAMEBUFFER_COMPLETE) {
        console.error("Framebuffer is not complete");
    }
    framebuffer.colorBufferTexture = texture;

    return framebuffer
}

function createRenderbuffer(gl, width, height) {
    const renderbuffer = gl.createRenderbuffer()
    gl.bindRenderbuffer(gl.RENDERBUFFER, renderbuffer)
    gl.renderbufferStorage(
        gl.RENDERBUFFER,
        gl.DEPTH_COMPONENT16,
        width,
        height
    )
    gl.framebufferRenderbuffer(
        gl.FRAMEBUFFER,
        gl.DEPTH_ATTACHMENT,
        gl.RENDERBUFFER,
        renderbuffer
    )
    return renderbuffer
}

function resize(gl, width, height) {
    canvas.width = width
    canvas.height = height
    gl.viewport(0, 0, width, height)
    gl.uniform2f(resolutionLocation, width, height)
}
// returns the two programs, one for the fragment shader, the other for the post-processing
async function setupPrograms() {
    const vertexShaderSource = await loadShader('./shaders/vertex.shader');
    const fragmentShaderSource = await loadShader('./shaders/fragment.shader');
    const postProcessingFragmentShaderSource = await loadShader('./shaders/postprocess.shader');
    const vertexShader = compileShader(gl, vertexShaderSource, gl.VERTEX_SHADER);
    const fragmentShader = compileShader(gl, fragmentShaderSource, gl.FRAGMENT_SHADER);
    const postProcessingFragmentShader = compileShader(gl, postProcessingFragmentShaderSource, gl.FRAGMENT_SHADER);
    const program = createProgram(gl, vertexShader, fragmentShader);
    const postProcessingProgram = createProgram(gl, vertexShader, postProcessingFragmentShader);
    return [program, postProcessingProgram];
}

function setupParameters(program) {
    const positionLocation = gl.getAttribLocation(program, 'a_position');
    gl.enableVertexAttribArray(positionLocation);
    gl.vertexAttribPointer(positionLocation, 2, gl.FLOAT, false, 0, 0);
    const resolutionLocation = gl.getUniformLocation(program, 'u_resolution');
    const timeLocation = gl.getUniformLocation(program, 'u_time');
    const mouseLocation = gl.getUniformLocation(program, 'u_mouse');
    const textureLocation = gl.getUniformLocation(program, 'u_texture');

    return [resolutionLocation, timeLocation, mouseLocation, textureLocation];
}

async function addCubeMapToProgram(program, urls, texUnit, uniformName) {
    const texture = await loadCubeMap(gl, urls);
    const location = gl.getUniformLocation(program, uniformName);
    gl.useProgram(program);
    gl.uniform1i(location, texUnit);
    gl.activeTexture(gl.TEXTURE0 + texUnit);
    gl.bindTexture(gl.TEXTURE_CUBE_MAP, texture);
}

function setupFramebuffer(width, height) {
    const framebuffer = createFramebuffer(gl, width, height);
    const renderbuffer = createRenderbuffer(gl, width, height);
    const copyBuffer = createFramebuffer(gl, width, height);
    return [framebuffer, renderbuffer, copyBuffer];
}

function setupCanvas(width, height) {
    const parent = document.getElementById('canvas-container');
    const canvas = document.createElement('canvas');
    canvas.width = width;
    canvas.height = height;
    parent.appendChild(canvas);
    return canvas;
}

function resizeCanvas(canvas, width, height) {
    canvas.width = width;
    canvas.height = height;
    gl.viewport(0, 0, width, height);
    gl.uniform2f(resolutionLocation, width, height);
}

async function loadCubeMap(gl, urls) {
    const texture = gl.createTexture();
    gl.bindTexture(gl.TEXTURE_CUBE_MAP, texture);
    const targets = [
        gl.TEXTURE_CUBE_MAP_POSITIVE_X, gl.TEXTURE_CUBE_MAP_NEGATIVE_X,
        gl.TEXTURE_CUBE_MAP_POSITIVE_Y, gl.TEXTURE_CUBE_MAP_NEGATIVE_Y,
        gl.TEXTURE_CUBE_MAP_POSITIVE_Z, gl.TEXTURE_CUBE_MAP_NEGATIVE_Z
    ];
    for (let i = 0; i < targets.length; i++) {
        const response = await fetch(urls[i]);
        const blob = await response.blob();
        const image = await createImageBitmap(blob);
        gl.texImage2D(targets[i], 0, gl.RGBA, gl.RGBA, gl.UNSIGNED_BYTE, image);
    }
    gl.generateMipmap(gl.TEXTURE_CUBE_MAP);
    gl.texParameteri(gl.TEXTURE_CUBE_MAP, gl.TEXTURE_MIN_FILTER, gl.LINEAR_MIPMAP_LINEAR);
    return texture;
}

function setupWebGL2(canvas) {
    const gl = canvas.getContext('webgl2', {antialias: true});
    return gl;
}

async function loadMP3(url) {
    const response = await fetch(url);
    const arrayBuffer = await response.arrayBuffer();
    const audioBuffer = await audioContext.decodeAudioData(arrayBuffer);
    return audioBuffer;
}

function setupAudioContext() {
    const audioContext = new AudioContext();
    return audioContext;
}

function setupAudioContextSource(buffer, loopPoint) {
    const source = audioContext.createBufferSource();
    source.buffer = buffer;
    source.loop = true;
    source.loopStart = loopPoint[0];
    source.loopEnd = loopPoint[1];
    return source;
}

function setupAudioContextAnalyser() {
    const analyser = audioContext.createAnalyser();
    analyser.fftSize = 2048;
    return analyser;
}

function setupAudioContextGain() {
    const gain = audioContext.createGain();
    return gain;
}

// global variables
let gl;
let program;
let postProcessingProgram;
let resolutionLocation;
let timeLocation;
let mouseLocation;
let textureLocation;
let framebuffer;
let renderbuffer;
let copyBuffer;
let canvas;
let audioContext;
let fftTextureLocation;
let fftTexture;
let copyTexture;
let timeLocationPost;
let mouseLocationPost;
let textureLocationPost;
let fftTextureLocationPost;
let resolutionLocationPost;
let music;
let halVoice;
let mouse = [0, 0];
let analyser;
let gain;
const WIDTH = 1024;
const HEIGHT = 1024;

async function setupMP3Audio(url) {
    const buffer = await loadMP3(url);
    const loopPoint = [0, 42.666];
    const source = setupAudioContextSource(buffer, loopPoint);
    const analyser = setupAudioContextAnalyser();
    const gain = setupAudioContextGain();
    source.connect(analyser);
    analyser.connect(gain);
    gain.connect(audioContext.destination);
    return [analyser, gain, source];
}

async function setup() {
    canvas = setupCanvas(WIDTH, HEIGHT);
    gl = setupWebGL2(canvas);
    [program, postProcessingProgram] = await setupPrograms();
    [resolutionLocation, timeLocation, mouseLocation, textureLocation] = setupParameters(program);
    // setup post params
    [resolutionLocationPost, timeLocationPost, mouseLocationPost, textureLocationPost] = setupParameters(postProcessingProgram);
    let cubemapUrls = [
        './cubemaps/winter/posx.png',
        './cubemaps/winter/negx.png',
        './cubemaps/winter/posy.png',
        './cubemaps/winter/negy.png',
        './cubemaps/winter/posz.png',
        './cubemaps/winter/negz.png'
    ];
    await addCubeMapToProgram(postProcessingProgram, cubemapUrls, 2, 'u_env');
    [framebuffer, renderbuffer, copyBuffer] = setupFramebuffer(WIDTH, HEIGHT);
    createRenderQuad(gl);
    setupMouse(canvas);
    fftTextureLocation = gl.getUniformLocation(program, 'u_fftTexture');
    fftTextureLocationPost = gl.getUniformLocation(postProcessingProgram, 'u_fftTexture');
    audioContext = setupAudioContext();
    [analyser, gain, music] = await setupMP3Audio('./scember1.mp3');
    music.start();
    loop(0);
}

function setupMouse(canvas) {
    const mouse = [0, 0];
    canvas.addEventListener('mousemove', (event) => {
        mouse[0] = event.clientX;
        mouse[1] = event.clientY;
    });
    return mouse;
}
function updateParameters(time, mouse) {
    gl.useProgram(program);
    gl.uniform1f(timeLocation, time);
    gl.uniform2f(mouseLocation, mouse[0], mouse[1]);
    gl.uniform2f(resolutionLocation, WIDTH, HEIGHT);
    gl.useProgram(postProcessingProgram);
    gl.uniform1f(timeLocationPost, time);
    gl.uniform2f(mouseLocationPost, mouse[0], mouse[1]);
    gl.uniform2f(resolutionLocationPost, WIDTH, HEIGHT);

}

function updateTexture(texture) {
    gl.activeTexture(gl.TEXTURE0);
    gl.bindTexture(gl.TEXTURE_2D, texture);
    gl.uniform1i(textureLocation, 0);
}

function render(time) {
    update(time);

    // Update FFT Texture
    buildFFTTexture(); // This should bind and update the FFT texture on gl.TEXTURE1

    // Render to framebuffer
    gl.bindFramebuffer(gl.FRAMEBUFFER, framebuffer);
    gl.bindRenderbuffer(gl.RENDERBUFFER, renderbuffer);
    gl.clear(gl.COLOR_BUFFER_BIT | gl.DEPTH_BUFFER_BIT);
    if(!copyTexture)
        copyTexture = gl.createTexture();
    // Use program and draw scene
    gl.useProgram(program);
    gl.activeTexture(gl.TEXTURE0);
    gl.bindTexture(gl.TEXTURE_2D, copyTexture);
    gl.texImage2D(gl.TEXTURE_2D, 0, gl.RGBA, 2, 2, 0, gl.RGBA, gl.UNSIGNED_BYTE, null);
    gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_MIN_FILTER, gl.NEAREST);
    gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_MAG_FILTER, gl.NEAREST);
    gl.copyTexImage2D(gl.TEXTURE_2D, 0, gl.RGBA, 0, 0, WIDTH, HEIGHT, 0);
    gl.uniform1i(textureLocation, 0);
    gl.bindTexture(gl.TEXTURE_2D, null);
    gl.activeTexture(gl.TEXTURE1); // Activate texture unit for FFT texture
    gl.bindTexture(gl.TEXTURE_2D, fftTexture);
    gl.uniform1i(fftTextureLocation, 1); // Tell the shader to use texture unit 1 for FFT
    gl.drawArrays(gl.TRIANGLES, 0, 6);

    // Render post-processing effect
    gl.useProgram(postProcessingProgram);
    gl.activeTexture(gl.TEXTURE0); // Activate texture unit for framebuffer texture
    gl.bindTexture(gl.TEXTURE_2D, framebuffer.colorBufferTexture);
    gl.uniform1i(textureLocationPost, 0); // Tell the shader to use texture unit 0 for framebuffer texture
    gl.activeTexture(gl.TEXTURE1); // Also bind FFT texture for post-processing if needed
    gl.bindTexture(gl.TEXTURE_2D, fftTexture);
    gl.uniform1i(fftTextureLocationPost, 1);

    // Unbind framebuffer
    gl.bindFramebuffer(gl.FRAMEBUFFER, null);
    gl.bindRenderbuffer(gl.RENDERBUFFER, null);
    gl.drawArrays(gl.TRIANGLES, 0, 6);
}
function updateFFTTexture() {
    const dataArray = new Uint8Array(analyser.frequencyBinCount);
    gl.bindTexture(gl.TEXTURE_2D, fftTexture);
    gl.texSubImage2D(gl.TEXTURE_2D, 0, 0, 0, dataArray.length, 1, gl.LUMINANCE, gl.UNSIGNED_BYTE, dataArray);

}
function buildFFTTexture() {
    if(!fftTexture)
        fftTexture = gl.createTexture();
    gl.bindTexture(gl.TEXTURE_2D, fftTexture);
    gl.texImage2D(gl.TEXTURE_2D, 0, gl.LUMINANCE, analyser.frequencyBinCount, 1, 0, gl.LUMINANCE, gl.UNSIGNED_BYTE, null);
    gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_MIN_FILTER, gl.NEAREST);
    gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_MAG_FILTER, gl.NEAREST);
    gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_WRAP_S, gl.CLAMP_TO_EDGE);
    gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_WRAP_T, gl.CLAMP_TO_EDGE);
    gl.bindTexture(gl.TEXTURE_2D, null);
    gl.useProgram(program);
    gl.uniform1i(fftTextureLocation, 0);
    gl.activeTexture(gl.TEXTURE0);
    gl.bindTexture(gl.TEXTURE_2D, fftTexture);
    const dataArray = new Uint8Array(analyser.frequencyBinCount);
    analyser.getByteFrequencyData(dataArray);
    gl.texSubImage2D(gl.TEXTURE_2D, 0, 0, 0, dataArray.length, 1, gl.LUMINANCE, gl.UNSIGNED_BYTE, dataArray);
    gl.useProgram(postProcessingProgram);
    gl.uniform1i(fftTextureLocationPost, 1);
    gl.activeTexture(gl.TEXTURE1);
    gl.bindTexture(gl.TEXTURE_2D, fftTexture);
    gl.texSubImage2D(gl.TEXTURE_2D, 0, 0, 0, dataArray.length, 1, gl.LUMINANCE, gl.UNSIGNED_BYTE, dataArray);
}
function update(time) {
    updateParameters(time, mouse);
}
function loop(time) {
    render(time);
    requestAnimationFrame(loop);
}

let running = false;

// start if not running on document click or finger touch tap

document.addEventListener('click', () => {
    if (!running) {
        setup();
        running = true;
    }
});

document.addEventListener('touchstart', () => {
    if (!running) {
        setup();
        running = true;
    }
});

// run setup if running on localhost or 127.0.0.1, or any localhost or 127.0.0.1 with port in the range 5000-6000, use regex to match the port range

if (window.location.hostname === 'localhost' || window.location.hostname === '127.0.0.1' || window.location.hostname.match(/127\.0\.0\.1:[5-6][0-9]{3}/) || window.location.hostname.match(/localhost:[5-6][0-9]{3}/)) {
    setup();
    running = true;
}
