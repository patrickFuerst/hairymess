#include "ofApp.h"
#include "ofConstants.h"


#define NUM_HAIR_PARTICLES 16   // number must not be bigger then WORK_GROUP_SIZE , current 32 max, because glsl for loop limited
#define HAIR_LENGTH 2.0f


#define WORK_GROUP_SIZE 64

void ofApp::reloadShaders(){

		

	mComputeShader.setupShaderFromFile(GL_COMPUTE_SHADER,"hairSimulation.glsl");
	mComputeShader.linkProgram();
	mComputeShader.begin();
	int size[3]; 
	glGetProgramiv( mComputeShader.getProgram(), GL_COMPUTE_WORK_GROUP_SIZE, size);

	mComputeShader.printSubroutineNames(GL_COMPUTE_SHADER);
	mComputeShader.printSubroutineUniforms(GL_COMPUTE_SHADER);

	mComputeShader.setUniform3f("g_gravityForce", ofVec3f(0,-10,0));
	mComputeShader.setUniform1i("g_numVerticesPerStrand",NUM_HAIR_PARTICLES);
	mComputeShader.setUniform1i("g_numStrandsPerThreadGroup", mNumHairs * mNumHairs / WORK_GROUP_SIZE);
	mComputeShader.setUniform1f("g_strandLength",HAIR_LENGTH);

	mHairshader.setupShaderFromFile( GL_VERTEX_SHADER, "basic_VS.glsl");
	mHairshader.setupShaderFromFile( GL_FRAGMENT_SHADER, "basic_FS.glsl");
	mHairshader.linkProgram();
	
	particlesBuffer.setData(particles,GL_DYNAMIC_DRAW);

	mModelAnimation.makeIdentityMatrix();
}

//--------------------------------------------------------------
void ofApp::setup(){
	
	mReloadShaders = true; 
	ofSetLogLevel( OF_LOG_VERBOSE);
	//ofSetVerticalSync(false);
	camera.setAutoDistance(false);
	camera.setupPerspective(false,60,0.1,1000);
	camera.setPosition(10,15,10);
	camera.lookAt(ofVec3f(0,0,0));
	
	mFurryMesh = ofMesh::sphere(4,12 ); 
	mNumHairs = mFurryMesh.getNumVertices();
	particles.resize( mNumHairs * NUM_HAIR_PARTICLES);

	mNumWorkGroups = ((mNumHairs*NUM_HAIR_PARTICLES + (WORK_GROUP_SIZE-1))/ WORK_GROUP_SIZE);
	
		int index = 0;
	for (int i = 0; i <  mFurryMesh.getNumVertices(); i++)
	{

		ofVec3f v = mFurryMesh.getVertex(i);
		ofVec3f n = mFurryMesh.getNormal(i);
		for (int j = 0; j < NUM_HAIR_PARTICLES; j++)
		{
			auto& p = particles.at(index);
			p.pos = v + j* n * HAIR_LENGTH / NUM_HAIR_PARTICLES;
			p.pos.w = 1.0; 
			p.prevPos = p.pos;
			p.vel.set(0,0,0,0);
			p.fixed = j == 0 ? true : false;
			index++;
		}

	}
	
	mModelAnimation.makeIdentityMatrix();
	particlesBuffer.allocate(particles,GL_DYNAMIC_DRAW);

	vbo.setVertexBuffer(particlesBuffer,4,sizeof(Particle));

	ofBackground(0);
	ofEnableBlendMode(OF_BLENDMODE_ADD);

	gui.setup();
	mShaderUniforms.setName("shader params");
	mShaderUniforms.add( mVelocityDamping.set("g_velocityDamping", 0.5f, 0,1));
	mShaderUniforms.add( mNumConstraintIterations.set("g_numIterations", 25, 0,200));
	mShaderUniforms.add( mStiffness.set("g_stiffness",1.0f, 0,1));
	mShaderUniforms.add( mFTLDistanceDamping.set("g_ftlDamping", 1.0,0.0,1.0));
	mSimulationAlgorithms.setName( "shader algorithms");
	
	mPBDAlgorithm.setup( "PBD Algorithm");
	mDFTLAlgorithm.setup( "DFTL Algorithm" );
	mPBDAlgorithm.addListener( this, &ofApp::algorithmChanged );
	mDFTLAlgorithm.addListener( this, &ofApp::algorithmChanged );
	
	gui.add( &mPBDAlgorithm);
	gui.add( &mDFTLAlgorithm);
	gui.add( mShaderUniforms);
	gui.add(fps.set("fps",60,0,10000));



	particlesBuffer.bindBase(GL_SHADER_STORAGE_BUFFER, 0);
}

//--------------------------------------------------------------
void ofApp::update(){
	
	if(mReloadShaders){

		reloadShaders();
		mReloadShaders = false; 
	}
	
	
	fps = ofGetFrameRate();
	float timeStep = ofGetLastFrameTime();
	if( timeStep > 0.02)  // prevent to high timesteps at the beginning of the app start
		timeStep = 0.02;

	//ofMatrix4x4 modelAnimationMatrixDelta = mModelAnimation * mModelAnimationPrevInversed;
	mModelAnimationPrevInversed = mModelAnimation.getInverse();

	static ofQuaternion first, second; 
	first.makeRotate(0,0,0,0);
	second.makeRotate(180,1,1,0);
	mModelOrientation.slerp( sin(0.2f* ofGetElapsedTimef()), first, second);
	mModelAnimation.makeIdentityMatrix();
	mModelAnimation.postMultRotate(mModelOrientation);
	mModelAnimation.setTranslation( ofVec3f( 0,5.0f*abs( sin( ofGetElapsedTimef() ) ), 0));

	mComputeShader.begin();

	glUniformSubroutinesuiv( GL_COMPUTE_SHADER, 1, subroutineUniforms);
	
	mComputeShader.setUniforms(mShaderUniforms);
	mComputeShader.setUniform1f("g_timeStep",timeStep);
	mComputeShader.setUniformMatrix4f("g_modelMatrix",mModelAnimation );	
	mComputeShader.setUniformMatrix4f("g_modelMatrixPrevInverted",mModelAnimationPrevInversed );	
	mComputeShader.setUniform1f("elapsedTime",ofGetElapsedTimef());
	
	mComputeShader.dispatchCompute( mNumWorkGroups, 1, 1);
	mComputeShader.end();


	
}

//--------------------------------------------------------------
void ofApp::draw(){
	ofEnableBlendMode(OF_BLENDMODE_ADD);
	camera.begin();
	
	ofDrawGrid(1.25, 10 , false,false,true,false);

	ofSetColor(ofColor::red);
	ofPushMatrix();
	ofMultViewMatrix(mModelAnimation);
	mFurryMesh.draw();
	ofPopMatrix();
	
	glPointSize(2);
	
	mHairshader.begin();

	glMemoryBarrier(GL_VERTEX_ATTRIB_ARRAY_BARRIER_BIT); //? 
	vbo.draw(GL_POINTS,0,particles.size());

	mHairshader.end();
	camera.end();

	ofEnableBlendMode(OF_BLENDMODE_ALPHA);
	ofSetColor(255);
	gui.draw();
}

void ofApp::algorithmChanged(const void* sender ) {
	
	ofxButton* button = (ofxButton*) sender; 
	string name = button->getName();
	GLint subroutine = 0;

	if( name == "PBD Algorithm" )
		subroutine = mComputeShader.getSubroutineLocation( GL_COMPUTE_SHADER , "PBDApproach");
	else if( name == "DFTL Algorithm" )
		subroutine = mComputeShader.getSubroutineLocation( GL_COMPUTE_SHADER , "DFTLApproach");

	subroutineUniforms[0] = subroutine;
}

//--------------------------------------------------------------
void ofApp::keyPressed(int key){
}

//--------------------------------------------------------------
void ofApp::keyReleased(int key){
	if (key == 'f'){
		ofToggleFullscreen();
	}else if( key == 'r'){
		mReloadShaders = true;
	}

}

//--------------------------------------------------------------
void ofApp::mouseMoved(int x, int y ){

	//ofVec3f t =  camera.screenToWorld( ofVec3f(x,y,0.8));
	//t.z = 0.0;
	//mStrandModelMatrix.setTranslation( t ) ; 

}

//--------------------------------------------------------------
void ofApp::mouseDragged(int x, int y, int button){

}

//--------------------------------------------------------------
void ofApp::mousePressed(int x, int y, int button){

}

//--------------------------------------------------------------
void ofApp::mouseReleased(int x, int y, int button){

}

//--------------------------------------------------------------
void ofApp::windowResized(int w, int h){

}

//--------------------------------------------------------------
void ofApp::gotMessage(ofMessage msg){

}

//--------------------------------------------------------------
void ofApp::dragEvent(ofDragInfo dragInfo){ 

}
