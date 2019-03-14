package;

import lime.app.Application;
import lime.graphics.WebGLRenderContext;
import lime.graphics.opengl.GLBuffer;
import lime.graphics.opengl.GLProgram;
import lime.graphics.opengl.GLTexture;
import lime.graphics.opengl.GLUniformLocation;
import lime.graphics.Image;
import lime.graphics.RenderContext;
import lime.math.Matrix4;
import lime.utils.Assets;
import lime.utils.Float32Array;
import lime.graphics.ImageType;

class Main extends Application {
	
	private var gl:WebGLRenderContext;
		
	private var glBuffer:GLBuffer;
	private var glProgram:GLProgram;
	private var glTextureAttribute:Int;
	private var glVertexAttribute:Int;
	private var glMatrixUniform:GLUniformLocation;
	private var imageUniform:GLUniformLocation;

	private var matrix = new Matrix4 ();	
	
	private var glTextures = new Array<GLTexture>();
	
	private var isReadyToRender = false;
	
	
	public function new () {
		
		super ();
		
	}
	
	
	public override function onWindowCreate ():Void {
		
		gl = window.context.webgl;
		onWindowResize (window.width, window.height);
		
		createBuffer(window.width, window.height);
		createProgram();
		
		
		var width = Std.int(gl.getParameter(gl.MAX_TEXTURE_SIZE)/4);
		var height = width;
		var maxTextures = 200;
		
		var availTextures = checkMaxTextures(width, height, maxTextures);
		var gpuRam = availTextures * Std.int( width * height * 4 / 1024 / 1024);
		
		trace ('A maximum of $availTextures textures with size of $width x $height is available');
		trace ('that is using $gpuRam MB of GPU-RAM.');
		
	}
	
	
	public override function onWindowResize (width:Int, height:Int):Void {
		
		matrix.createOrtho (0, width, height, 0, -1000, 1000);		
	}
	
	/*
	public override function onPreloadComplete ():Void {
		
		glTextures.push( createTextureFromImage(Assets.getImage ("assets/lime.png")) );	
		
	}
	*/
	
	public function checkMaxTextures(width:Int, height:Int, maxTextures:Int = 1 ):Int
	{
		var randomImage = createRandomImage(width, height);
		
		var availTextures = 0;
		
		trace('trying to create $maxTextures textures with size of $width x $height');
		
		while (availTextures < maxTextures)
		{
			try {
				glTextures.push( createTextureFromImage( randomImage ) );
				renderAllTextures();
				availTextures++;
			}
			catch (e:Dynamic) {
				trace(e);
				maxTextures = 0;
			}
			trace(availTextures);
		}
		
		return availTextures;
	}
	
	
	public override function onRenderContextLost ():Void
	{		
		trace(" ---------  LOST RENDERCONTEXT ----------- ");		
	}

	
	public override function render (context:RenderContext):Void {
		
		switch (context.type) {
			
			case OPENGL, OPENGLES, WEBGL:
				
				gl.viewport (0, 0, window.width, window.height);				
				gl.clearColor (0.0, 0.0, 0.0, 0.0);
				gl.clear (gl.COLOR_BUFFER_BIT);
				
				// alpha blending
				gl.blendFunc (gl.SRC_ALPHA, gl.ONE_MINUS_SRC_ALPHA);
				gl.enable (gl.BLEND);		
		
				//if (glTextures.length > 0) renderAllTextures();
			
			default:
			
		}		
	}
	
	
	public function renderAllTextures()
	{
		// program
		gl.useProgram (glProgram);		
		
		// texture
		#if desktop
		gl.enable (gl.TEXTURE_2D);
		#end
		gl.activeTexture (gl.TEXTURE0);
		
		
		// uniforms
		gl.uniformMatrix4fv (glMatrixUniform, false, matrix);
		gl.uniform1i (imageUniform, 0);
		
		
		// init vertex buffer
		gl.bindBuffer (gl.ARRAY_BUFFER, glBuffer);
		gl.vertexAttribPointer (glVertexAttribute, 3, gl.FLOAT, false, 5 * Float32Array.BYTES_PER_ELEMENT, 0);
		gl.vertexAttribPointer (glTextureAttribute, 2, gl.FLOAT, false, 5 * Float32Array.BYTES_PER_ELEMENT, 3 * Float32Array.BYTES_PER_ELEMENT);
		
		gl.enableVertexAttribArray (glVertexAttribute);
		gl.enableVertexAttribArray (glTextureAttribute);
		
		
		// draw for each texture
		for (glTexture in glTextures) {
			gl.bindTexture (gl.TEXTURE_2D, glTexture);
			gl.drawArrays (gl.TRIANGLE_STRIP, 0, 4);
		}
		
	}
	
	
	// clear the error-queue
	public function clearGlErrorQueue() {
		
		while ( gl.getError() != gl.NO_ERROR) {}
	}
	
	// fetch last gl-error from queue (error-catching can be disabled while context-creation!)
	public function getLastGlError():Int {
		
		var err:Int = gl.getError();
		if (err != gl.NO_ERROR) {
			if (err == gl.INVALID_ENUM) trace("(GL-Error: INVALID_ENUM)");
			else if (err == gl.INVALID_VALUE) trace("(GL-Error: INVALID_VALUE)");
			else if (err == gl.INVALID_OPERATION) trace("(GL-Error: INVALID_OPERATION)");
			else if (err == gl.OUT_OF_MEMORY) trace("(GL-Error: OUT_OF_MEMORY)");
			else trace("GL-Error: " + err);
		}
		return err;	
	}

	
	public function createTextureFromImage(image:Image):GLTexture {
		
		clearGlErrorQueue();
		var _glTexture = gl.createTexture ();
		if (getLastGlError() != gl.NO_ERROR) throw("ERROR - gl.createTexture()");
		
		gl.bindTexture (gl.TEXTURE_2D, _glTexture);
		gl.texParameteri (gl.TEXTURE_2D, gl.TEXTURE_WRAP_S, gl.CLAMP_TO_EDGE);
		gl.texParameteri (gl.TEXTURE_2D, gl.TEXTURE_WRAP_T, gl.CLAMP_TO_EDGE);
		
		clearGlErrorQueue();
		#if js
		gl.texImage2D (gl.TEXTURE_2D, 0, gl.RGBA, gl.RGBA, gl.UNSIGNED_BYTE, image.src);
		#else
		gl.texImage2D (gl.TEXTURE_2D, 0, gl.RGBA, image.width, image.height, 0, gl.RGBA, gl.UNSIGNED_BYTE, image.data);
		#end
		if (getLastGlError() != gl.NO_ERROR) throw("ERROR - gl.texImage2D");

		
		gl.texParameteri (gl.TEXTURE_2D, gl.TEXTURE_MAG_FILTER, gl.LINEAR);
		gl.texParameteri (gl.TEXTURE_2D, gl.TEXTURE_MIN_FILTER, gl.LINEAR);
		gl.bindTexture (gl.TEXTURE_2D, null);
		
		return _glTexture;
		
	}
	
	
	public function createProgram():Void {
		
		var vertexSource = 
			
			"attribute vec4 aPosition;
			attribute vec2 aTexCoord;
			varying vec2 vTexCoord;
			
			uniform mat4 uMatrix;
			
			void main(void) {
				
				vTexCoord = aTexCoord;
				gl_Position = uMatrix * aPosition;
				
			}";
		
		var fragmentSource = 
			
			#if !desktop
			"precision mediump float;" +
			#end
			"varying vec2 vTexCoord;
			uniform sampler2D uImage0;
			
			void main(void)
			{
				gl_FragColor = texture2D (uImage0, vTexCoord);
			}";
		
		glProgram = GLProgram.fromSources (gl, vertexSource, fragmentSource);
		
		glVertexAttribute = gl.getAttribLocation (glProgram, "aPosition");
		glTextureAttribute = gl.getAttribLocation (glProgram, "aTexCoord");
		
		glMatrixUniform = gl.getUniformLocation (glProgram, "uMatrix");
		imageUniform = gl.getUniformLocation (glProgram, "uImage0");
			
	}
	
	
	public function createBuffer(width:Int, height:Int):Void {
		
		var data = [
			
			width, height, 0, 1, 1,
			0, height, 0, 0, 1,
			width, 0, 0, 1, 0,
			0, 0, 0, 0, 0
			
		];
		
		glBuffer = gl.createBuffer ();
		gl.bindBuffer (gl.ARRAY_BUFFER, glBuffer);
		gl.bufferData (gl.ARRAY_BUFFER, new Float32Array (data), gl.STATIC_DRAW);
		gl.bindBuffer (gl.ARRAY_BUFFER, null);
		
	}
	
	
	// create image with random pixels
	public function createRandomImage(width:Int, height:Int):Image {
		
		var image:Image = null;
		
		trace('Create an Image ($width x $height) with random pixels for texture-data.');
		
		try {
			image = new Image(null, 0, 0, width, height, 0xff0000FF, ImageType.DATA);
		}
		catch (e:Dynamic) trace("Error while creating lime.graphics.Image", e);
		
		for (x in 0...width) {
			for (y in 0...height) {
				image.setPixel32(x, y, (Std.int(Math.random() * 256) << 24) | Std.random(0x1000000) );
			}
		}
		
		return image;
		
	}
	
	
}