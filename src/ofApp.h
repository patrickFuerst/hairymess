#pragma once

#include "ofMain.h"
#include "ofBufferObject.h"

#include "ofxAssimpModelLoader.h"
#include "ofxGui.h"



class PingPongBuffer{

	public: 
	void allocate(GLsizeiptr bytes, GLenum usage){ mReadBuffer.allocate(bytes,usage); mWriteBuffer.allocate(bytes,usage);};
	ofBufferObject& getReadBuffer(){ return mReadBuffer;};
	ofBufferObject& getWriteBuffer(){ return mWriteBuffer;};
	void swap(){ std::swap( mReadBuffer, mWriteBuffer ); }; 

	private: 
	ofBufferObject mReadBuffer, mWriteBuffer; 
};

class ofApp : public ofBaseApp{

	public:

		struct AABB {
			ofVec3f min; 
			ofVec3f max; 
		};

		void setup();
		void update();
		void draw();
		void exit();

		void drawFloor();
		void drawAnimatedMesh();

		void keyPressed(int key);
		void keyReleased(int key);
		void mouseMoved(int x, int y );
		void mouseDragged(int x, int y, int button);
		void mousePressed(int x, int y, int button);
		void mouseReleased(int x, int y, int button);
		void windowResized(int w, int h);
		void dragEvent(ofDragInfo dragInfo);
		void gotMessage(ofMessage msg);
		
		// hair stuff
		void fillVoxelGrid( float timeStep);
		AABB calculateBoundingBox( ofMesh &mesh, float hairlength  );
		void reloadShaders();
		void updateUBO( float deltaTime);

		// gui 
		void createGui(); 
		void algorithmChanged(const void* sender);

		// debug helpers

		void pushGlDebugGroup( std::string message );
		void popGlDebugGroup();
		
		void drawDebug();
		void drawInfo();

		static void GLAPIENTRY glErrorCallback (GLenum source​, GLenum type​, GLuint id​, GLenum severity​, GLsizei length​, const GLchar* message​, const void* userParam​);



		/// Shader Storage Buffers
		struct ParticleData{
			ofVec4f pos;
			ofVec4f prevPos;
			ofVec4f vel; // not necessarily needed, could be derived from prevPos
			ofFloatColor color; 
			int fixed;  // actually bool in glsl,  could be encode to pos.w to save memory
			int pad[3];  // struct in glsl is aligned to multiple of the biggest base alingment, here 16 , so offset of next is 64 not 52
		};

		// data per strand, maybe more later
		struct StrandData{
			float strandLength; 
			int pad[3];  // we use std140 alignment so padding needs to be added

		};

		/// Uniform Buffer Objects structure

	
		struct SimulationData{ 
			ofVec4f gravityForce;
			float velocityDamping;
			int numIterationsPBD;
			float stiffness;
			float friction; 
			float repulsion;
			float ftlDamping; 
			float deltaTime; 
		
		}mSimulationData;


		struct ConstSimulationData{
			int numVerticesPerStrand; 
			int numStrandsPerThreadGroup;
			int numStrands; 

		}mConstSimulationData;

		struct ModelData{
			ofMatrix4x4 modelMatrix; 
			ofMatrix4x4 modelMatrixPrevInverted;
			ofVec4f modelTranslation; 

		}mModelData;
		

		struct ConstVoxelGridData{
			ofVec4f minBB;
			ofVec4f maxBB; 
			int gridSize; 

		}mConstVoxelGridData;

		struct VoxelGridData{
			float deltaTime; 
		
		}mVoxelGridData;

		
		struct UniformBuffers {  // struct helps us with scoping, because the names of data structs are the same
			// can't use enum struct because doesn't support int conversion 
			enum  
			{
				SimulationData = 0, 
				ConstSimulationData,
				ModelData,
				VoxelGridData,
				ConstVoxelGridData,
				Size
			};
		};
		struct ShaderStorageBuffers {  // struct helps us with scoping, because the names of data structs are the same

			enum   
			{
				ParticleData = 0, 
				GradientReadData,
				GradientWriteData,
				VelocityReadData,
				VelocityWriteData,
				DensityData, 
				StandData, 
				RootData,
				Size
			} ;
		};
	

		// hair simulation
		GLuint mUbos[UniformBuffers::Size]; 
		GLuint mSubroutineUniforms[1];
		GLuint mRootBufferId; 
		ofShader mHairshader,mFloorShader,  mVoxelComputeShaderFill, mVoxelComputeShaderPostProcess, mVoxelComputeShaderFilter; 
		int mVoxelGridSize; 

		ofShader mComputeShaderSimulation;
		int mNumWorkGroups;

		vector<ParticleData> mParticles; // let's keep them on cpu side if we refresh it 
		vector<StrandData> mStrandData; // let's keep them on cpu side if we refresh it 
		ofBufferObject mParticlesBuffer,  mDensityBuffer, mStrandDataBuffer;
		PingPongBuffer mVoxelVelocityBuffer, mVoxelGradientBuffer; 

		int mNumHairStands,  mNumParticles; ; 
		AABB mSimulationBoundingBox; 

		ofMatrix4x4 mModelAnimation, mModelAnimationPrevInversed;
		ofQuaternion mModelOrientation; 


		ofMesh mFurryMesh;
		
		ofEasyCam camera;
		//ofCamera camera;
		ofVbo mHairVbo;

		ofVboMesh mFloor; 

		// debug Voxel grid 
		ofShader mVoxelGridShader;
		ofVbo mVoxelVBO; 

		// gui
		ofxPanel gui;
		ofParameter<float> mVelocityDamping,  mStiffness, mFriction, mRepulsion ; 
		ofParameterGroup mShaderUniforms;
		ofxGuiGroup mSimulationAlgorithms; 
		ofxButton mPBDAlgorithm, mDFTLAlgorithm; 
		
		// integrated length contraint 
		ofParameter<int> mNumConstraintIterations ; 

		// dynamic follow the leader constraint 
		ofParameter<float> mFTLDistanceDamping;

		// animated model 
		ofxAssimpModelLoader mAnimatedModel;


		// debug 
		bool mReloadShaders; 
		ofParameter<bool> mDrawBoundingBox; 
		ofParameter<bool> mUseFilter; 
		ofParameter<bool> mDrawVoxelGrid; 
		ofParameter<bool> mDrawFur; 
		ofParameter<bool> mPlayAnimation; 
		ofParameter<ofVec3f> mGravity; 


};
