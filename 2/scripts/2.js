
const canvas = setupCanvas();
const gl = canvas.getContext("webgl2");
gl.viewport(0, 0, canvas.width, canvas.height);
let program, timeLocation, resolutionLocation, mouseLocation, fftTextureLocation;

let click = false;
let playing = false;
let lastMousePos = { x: 0, y: 0 };
let useResize = window.innerWidth === 1024 || window.innerHeight === 1024;
const buffer = gl.createBuffer();
let audioContext, analyser, source;
loadShaders(ready);

function setupCanvas() {
    const c = document.createElement("canvas");
    const parent = document.getElementById("canvas-container");
    c.id = "space";
    c.width = 1024;
    c.height = 1024;
    parent.appendChild(c);
    window.addEventListener("resize", resize);
    document.addEventListener("mousemove", mousemove);
    document.addEventListener("click", initAudioOnUserAction);
    document.addEventListener("touchstart", initAudioOnUserAction);
    c.addEventListener("mousedown", (e) => { click = true; });
    c.addEventListener("mouseup", (e) => { click = false; });
    return c;
}

function resize() {
    if (!useResize) {
        return;
    }
    var w = window.innerWidth;
    var h = window.innerHeight;
    canvas.width = w;
    canvas.height = h;
    console.log(w, h);
    gl.uniform2f(resolutionLocation, w, h);
    gl.viewport(0, 0, w, h);
}

function mousemove(e) {
    var cRect = canvas.getBoundingClientRect();              // Gets the CSS positions along with width/height
    var canvasX = Math.round(e.clientX - cRect.left);        // Subtract the 'left' of the canvas from the X/Y
    var canvasY = Math.round(e.clientY - cRect.top);
    var c = -1;
    var r = -1;
    if (click) {
        lastMousePos.x = canvasX / canvas.width;
        lastMousePos.y = canvasY / canvas.height;
        c = 1;
    } else {
        c = -1;
    }
    gl.uniform4f(mouseLocation, lastMousePos.x, lastMousePos.y, c, r);
}

let audioStarted = false;

function initAudioOnUserAction() {
  document.removeEventListener("click", initAudioOnUserAction);
  document.removeEventListener("touchstart", initAudioOnUserAction);

  if (!audioStarted) {
    initWebAudio();
    audioStarted = true;
  }

  requestAnimationFrame(render);
}
function initWebAudio() {
    audioContext = new (window.AudioContext || window.webkitAudioContext)();
    analyser = audioContext.createAnalyser();
    analyser.fftSize = 256; // Adjust the FFT size as needed
    source = audioContext.createBufferSource();

    // Load and decode the .wav file
    loadAudioFile("./scember1.mp3", function (buffer) {
        if(!playing)
        {
            source.buffer = buffer;
            source.loopEnd = 24.0;
            source.loop = true;
            source.connect(analyser);
            analyser.connect(audioContext.destination);

            source.start(0);
            playing = true;
    
            // Update FFT uniforms in the render loop
            updateFFTTexture();

            // Start rendering after both shader and audio are ready
            requestAnimationFrame(render);
        }
    });
}

function loadAudioFile(url, callback) {
    fetch(url)
        .then((response) => response.arrayBuffer())
        .then((data) => audioContext.decodeAudioData(data))
        .then((buffer) => callback(buffer))
        .catch((error) => console.error("Error loading audio file:", error));
}

function updateFFTTexture() {
    // Create an array to store FFT data
    const dataArray = new Uint8Array(analyser.frequencyBinCount);
  
    // Create a texture to store the FFT data
    const fftTexture = gl.createTexture();
    gl.bindTexture(gl.TEXTURE_2D, fftTexture);
    
    // Assuming analyser.frequencyBinCount is the width of the texture
    gl.texImage2D(gl.TEXTURE_2D, 0, gl.LUMINANCE, analyser.frequencyBinCount, 1, 0, gl.LUMINANCE, gl.UNSIGNED_BYTE, null);
    gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_MIN_FILTER, gl.NEAREST);
    gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_MAG_FILTER, gl.NEAREST);
    gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_WRAP_S, gl.CLAMP_TO_EDGE);
    gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_WRAP_T, gl.CLAMP_TO_EDGE);
    gl.bindTexture(gl.TEXTURE_2D, null);
  
    // Bind the texture to the uniform location
    gl.useProgram(program);
    gl.uniform1i(fftTextureLocation, 0); // Use texture unit 0
    gl.activeTexture(gl.TEXTURE0);
    gl.bindTexture(gl.TEXTURE_2D, fftTexture);
  
    function update() {
      analyser.getByteFrequencyData(dataArray);
      // Update the texture with the new FFT data
      gl.texSubImage2D(gl.TEXTURE_2D, 0, 0, 0, dataArray.length, 1, gl.LUMINANCE, gl.UNSIGNED_BYTE, dataArray);
  
      requestAnimationFrame(update);
    }
  
    // Start updating the FFT texture
    update();
  }
function render(time) {
    if (time === 0) {
        console.log("running");
    }
    gl.uniform1f(timeLocation, time * 0.001);
    gl.drawArrays(gl.TRIANGLES, 0, 6);
    requestAnimationFrame(render);
}

function ready() {
    gl.useProgram(program);
    let positionLocation = gl.getAttribLocation(program, "a_position");
    gl.bindBuffer(gl.ARRAY_BUFFER, buffer);
    gl.bufferData(gl.ARRAY_BUFFER, new Float32Array([
        -1.0, -1.0, 1.0, -1.0, -1.0, 1.0,
        -1.0, 1.0, 1.0, -1.0, 1.0, 1.0]), gl.STATIC_DRAW);
    gl.bindBuffer(gl.ARRAY_BUFFER, buffer);
    gl.enableVertexAttribArray(positionLocation);
    gl.vertexAttribPointer(positionLocation, 2, gl.FLOAT, false, 0, 0);
    gl.uniform2fv(resolutionLocation, [canvas.width, canvas.height]);

    // Get the uniform locations for FFT focuses
    fftBassLocation = gl.getUniformLocation(program, "u_fftBass");
    fftTransientLocation = gl.getUniformLocation(program, "u_fftTransient");
    fftHighMidLocation = gl.getUniformLocation(program, "u_fftHighMid");

    function initAudioOnUserAction() {
      // Remove the event listener after the first user action to avoid multiple initializations
      document.removeEventListener("click", initAudioOnUserAction);
    
      // Initialize the Web Audio API
      initWebAudio();
    
      // Start rendering after both shader and audio are ready
      requestAnimationFrame(render);
    }
}

function loadShaders(cb) {
    fetch("shaders/vertex.shader")
        .then((res) => res.text())
        .then((text) => {
            program = gl.createProgram();
            buildShader(text, gl.VERTEX_SHADER, program);
            return fetch("shaders/fragment.shader");
        })
        .then((res) => res.text())
        .then((text) => {
            buildShader(text, gl.FRAGMENT_SHADER, program);
            gl.linkProgram(program);
            if (!gl.getProgramParameter(program, gl.LINK_STATUS)) {
                console.error("Cannot link program", gl.getProgramInfoLog(program));
            }
            timeLocation = gl.getUniformLocation(program, "u_time");
            resolutionLocation = gl.getUniformLocation(program, "u_resolution");
            mouseLocation = gl.getUniformLocation(program, "u_mouse");
            cb(0);
        })
        .catch((err) => {
            console.log(err);
        });
}

function buildShader(source, type, program) {
    let shader = gl.createShader(type);
    gl.shaderSource(shader, source);
    gl.compileShader(shader);
    if (!gl.getShaderParameter(shader, gl.COMPILE_STATUS)) {
        console.error("Cannot compile shader\nSyntax error!", gl.getShaderInfoLog(shader));
        return;
    }
    gl.attachShader(program, shader);
}
