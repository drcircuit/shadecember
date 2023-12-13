# [DrCircuitsCanvasLibrary](https://drcircuit.github.io/DrCircuitsCanvasLibrary/) click to view examples live
A tiny library for doing boilerplate stuff for canvas based vanilla js gfx and game projects.

Installation:
Install via npm: ```npm install --save drcircuitscanvaslibrary ```

Usage:
```javascript
(function(){
    let scr;
  
    function setup() {
        scr = dcl.setupScreen(window.innerWidth ,window.innerHeight );
        scr.setBgColor('darkblue');
        document.body.style.backgroundColor = 'darkblue';      
    }
    function draw(t, dt){
       // your drawing and update logic here..
    }
    dcl.init(setup, draw);
    dcl.animate();
})();
```

# Examples:
* [Cube](/examples/cube.html)
* [Curve](/examples/curve.html)
* [Dodecahedron](/examples/dodecahedron.html)
* [Dual tetrahedron](/examples/dualtetrahedron.html)
* [Keyboard](/examples/keyboard.html)
* [Mouse](/examples/mouse.html)
* [Shapes](/examples/shapes.html)
* [Tetrahedron](/examples/tetrahedron.html)
* [Triangle](/examples/triangle.html)

# setupScreen function
setupScreen: function (width, height, keepSquare, gridScale)

## Parameters:
* width: The width of your canvas
* height: The height of your canvas
* keepSquare: This will create a square canvas
* gridScale: Create a grid based coordinate system, where the scale is number of square pixels in one grid unit.

## return object:
This method returns an object with the following:
* ctx: 2d rendering context
* width: the width of the canvas
* height: the height of the canvas
* cols: the number of columns in your grid
* rows: the number of rows in your grid
* setBgColor: function(color): sets the background color of the canvas
* randomSpot: function(): retrieves a random spot from the grid, returns a vector x, y

# dcl.random function
dcl.random: function(min, max)
## Parameters:
* min: the minimum desired number of the random range.
& max: the maximum desired number of the random range.

## return object:
This method returns a random integer between the given min / max values passed to the function.

# dcl.rect function
dcl.rect: function(x, y, width, height, color, lineWidth, lineColor, ctx)

## Parameters:
* x: the x position of the upper left corner of the rectangle
* y: the y position of the upper left corner of the rectangle
* width: the width of the rectangle
* height: the height of the rectangle, if 0 or no value is provided, a square with a side length equal to the "width" parameter will be drawn
* color: the fill color of the rectangle, defaults to "blue" if no input is given.
* lineWidth: The width of the stroke around the perimeter : optional
* lineColor: The color of the stroke around the perimeter, defaults to "#000088" if no input is given : optional
* ctx: The canvas context to draw the circle on : optional.

## void
This method draws a rectangle based on the given parameters.

# dcl.circle function
dcl.circle: function(x, y, radius, color, lineWidth, lineColor, ctx)

## Parameters:

* x: the x position of the center of the circle
* y: the y position of the center of the circle
* radius: the radius of the circle
* color: the fill color of the circle, defaults to "blue" if no input is given.
* lineWidth: The width of the stroke around the perimeter : optional
* lineColor: The color of the stroke around the perimeter, defaults to "#000088" if no input is given : optional
* ctx: The canvas context to draw the circle on : optional.

## void
This method draws a circle based on the given parameters.

# dcl.line function
dcl.circle: function(x, y, dx, dy, lineWidth, lineColor, ctx)

## Parameters:
* x: the x position of the start of the line
* y: the y position of the start of the line
* dx: the x position of the end of the line
* dy: the y position of the end of the line
* lineWidth: The width of the stroke around the perimeter : optional
* lineColor: The color of the stroke around the perimeter, defaults to "#000088" if no input is given : optional
* ctx: The canvas context to draw the circle on : optional.

## void
This method draws a line based on the given parameters.

# dcl.init function
## Parameters:
* setup a function to setup your scene
* draw a function that will run in a loop rendering your scene

# dcl.animate function
This function starts the render loop.

