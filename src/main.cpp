#include "ofMain.h"
#include "ofApp.h"

//========================================================================
int main( ){
    // this example uses compute shaders which are only supported since
    // openGL 4.3
	ofGLFWWindowSettings settings;
	settings.setGLVersion(4,4);
	
	settings.stencilBits = 8; 
	settings.width = 1920;
	settings.height = 1080;
	//settings.windowMode = OF_FULLSCREEN;
	ofCreateWindow(settings);			// <-------- setup the GL context

	// this kicks off the running of my app
	// can be OF_WINDOW or OF_FULLSCREEN
	// pass in width and height too:
	ofRunApp(new ofApp());

}
