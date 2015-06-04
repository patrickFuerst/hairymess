#pragma once

#include "ofMain.h"
#include "ofBufferObject.h"
#include "ofxGui.h"

class ofApp : public ofBaseApp{

	public:
		void setup();
		void update();
		void draw();
		void dirAsColorChanged(bool & dirAsColor);

		void reloadShaders();

		void keyPressed(int key);
		void keyReleased(int key);
		void mouseMoved(int x, int y );
		void mouseDragged(int x, int y, int button);
		void mousePressed(int x, int y, int button);
		void mouseReleased(int x, int y, int button);
		void windowResized(int w, int h);
		void dragEvent(ofDragInfo dragInfo);
		void gotMessage(ofMessage msg);
		
		void algorithmChanged(const void* sender);


		struct Particle{
			ofVec4f pos;
			ofVec4f prevPos;
			ofVec4f vel;
			ofFloatColor color;
			int fixed;  // actually bool in glsl
			int pad[3];  // struct in glsl is aligned to multiple of the biggest base alingment, here 16 , so offset of next is 64 not 52
		};

		ofShader mComputeShader;
		int mNumWorkGroups;
		//ofShader mConstrainPerStrainComputeShader;

		ofShader mHairshader; 
		vector<Particle> particles;
		ofBufferObject particlesBuffer;//, particlesBuffer2;
		
		ofMatrix4x4 mModelAnimation, mModelAnimationPrevInversed;
		ofQuaternion mModelOrientation; 

		GLuint vaoID;
		ofEasyCam camera;
		//ofCamera camera;
		ofVbo vbo;
		
		ofxPanel gui;
		ofParameter<float> mVelocityDamping,  mStiffness ; 
		ofParameterGroup mShaderUniforms;
		ofxGuiGroup mSimulationAlgorithms; 
		ofxButton mPBDAlgorithm, mDFTLAlgorithm; 
		
		// integrated length contraint 
		ofParameter<int> mNumConstraintIterations ; 

		// dynamic follow the leader constraint 
		ofParameter<float> mFTLDistanceDamping;
		ofParameter<float> fps;

		ofMesh mFurryMesh;
		int mNumHairs; 
		GLuint subroutineUniforms[1];



		bool mReloadShaders; 
};
