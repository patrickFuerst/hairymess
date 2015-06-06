#include "ofApp.h"
#include "ofConstants.h"


#define NUM_HAIR_PARTICLES 16   // number must not be bigger then WORK_GROUP_SIZE , current 32 max, because glsl for loop limited
#define HAIR_LENGTH 2.0f


#define WORK_GROUP_SIZE 64

// glsl locations
#define POSITION	0
#define COLOR		1
#define NORMAL		2
#define TEXCOORD    3

#define VELOCITY 4
#define DENSITY 5 


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
	


	mVoxelComputeShader.setupShaderFromFile(GL_COMPUTE_SHADER, "voxelGridFill.glsl" ); 
	mVoxelComputeShader.linkProgram();
	mVoxelComputeShader.begin();
		int size2[3]; 
		glGetIntegeri_v(GL_MAX_COMPUTE_WORK_GROUP_SIZE,0, &size2[0]);
		glGetIntegeri_v(GL_MAX_COMPUTE_WORK_GROUP_SIZE,1, &size2[1]);
		glGetIntegeri_v(GL_MAX_COMPUTE_WORK_GROUP_SIZE,2, &size2[2]);
		int maxInv; 
		glGetIntegerv(GL_MAX_COMPUTE_WORK_GROUP_INVOCATIONS, &maxInv ); 
		glGetIntegerv(GL_MAX_COMPUTE_WORK_GROUP_COUNT, &maxInv ); 
	
	/*mVoxelComputeShader.setUniform1i("g_numVerticesPerStrand",NUM_HAIR_PARTICLES);
	mVoxelComputeShader.setUniform1i("g_numStrandsPerThreadGroup", mNumHairs * mNumHairs / WORK_GROUP_SIZE);	*/
		



	mVoxelGridShader.load( "voxelGrid_vs.glsl", "voxelGrid_fs.glsl" ); 




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
	
	mFurryMesh = ofMesh::sphere(4,120 ); 
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
			p.color.set( ofColor::goldenRod);
			p.fixed = j == 0 ? true : false;
			index++;
		}

	}
	
	mModelAnimation.makeIdentityMatrix();

	// PARTICLE BUFFER
	particlesBuffer.allocate(particles,GL_DYNAMIC_DRAW);
	particlesBuffer.bindBase(GL_SHADER_STORAGE_BUFFER, 0);
	vbo.setVertexBuffer(particlesBuffer,4,sizeof(Particle));
	vbo.setColorBuffer(particlesBuffer,  sizeof(Particle), offsetof(Particle, Particle::color) ); 


	// VOXEL BUFFER
	mVoxelGridSize = 64;
	mVoxelBuffer.allocate( sizeof(Voxel) * mVoxelGridSize * mVoxelGridSize * mVoxelGridSize, GL_STREAM_COPY);
	mVoxelBuffer.bindBase(GL_SHADER_STORAGE_BUFFER,1);
	mVoxelVBO.setAttributeBuffer( VELOCITY , mVoxelBuffer, 4 , sizeof(Voxel), offsetof(Voxel, Voxel::velocity)  ); // first attribute is velocity 
	mVoxelVBO.setAttributeBuffer( DENSITY , mVoxelBuffer, 1 , sizeof(Voxel), offsetof(Voxel, Voxel::density) ); // second attribute is density  


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
	mDrawBoundingBox.setName("Draw BoundingBox");
	mDrawVoxelGrid.setName("Draw VoxelGrid");
	mDrawFur.setName( "Draw Fur" ); 

	gui.add( &mPBDAlgorithm);
	gui.add( &mDFTLAlgorithm);
	gui.add( mDrawBoundingBox );
	gui.add( mDrawVoxelGrid );
	gui.add( mDrawFur );
	gui.add( mShaderUniforms);
	gui.add(fps.set("fps",60,0,10000));


	mSimulationBoundingBox = calculateBoundingBox( mFurryMesh, HAIR_LENGTH ); 
	mDrawBoundingBox = false; 
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


	
	fillVoxelGrid(); // create the voxel grid 


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
	camera.begin();
	ofEnableDepthTest();
	ofClear( ofColor::gray);
	ofDrawAxis(10);
	ofDrawGrid(1.25, 10 , false,false,true,false);

	if( mDrawFur ){

		glPointSize(1);
	
		mHairshader.begin();

		glMemoryBarrier(GL_VERTEX_ATTRIB_ARRAY_BARRIER_BIT); //? 
		vbo.draw(GL_POINTS,0,particles.size());

		mHairshader.end();
		ofSetColor(ofColor::red);
		ofPushMatrix();
		ofMultViewMatrix(mModelAnimation);
		mFurryMesh.draw();
		ofPopMatrix();

	}
	
	

	

	if( mDrawBoundingBox ){
		ofNoFill();
		ofVec3f position = ( mSimulationBoundingBox.max +  mSimulationBoundingBox.min) / 2.0f + mModelAnimation.getTranslation();
		float width =  mSimulationBoundingBox.max.x -  mSimulationBoundingBox.min.x;
		float height =  mSimulationBoundingBox.max.y -mSimulationBoundingBox.min.y;
		float depth =  mSimulationBoundingBox.max.z - mSimulationBoundingBox.min.z;
		ofDrawBox(position, width, height, depth ) ;
		ofFill();
	
	}
	if( mDrawVoxelGrid ){
		

		mVoxelGridShader.begin();

		mVoxelGridShader.setUniform3f( "g_minBB" , mSimulationBoundingBox.min);
		mVoxelGridShader.setUniform3f( "g_maxBB" , mSimulationBoundingBox.max);
		mVoxelGridShader.setUniformMatrix4f("g_modelMatrix", ofMatrix4x4::newTranslationMatrix( mModelAnimation.getTranslation() ) );	
		mVoxelGridShader.setUniform1i( "g_gridSize", mVoxelGridSize); 
		glPointSize(2);

		//	mVoxelVBO.draw(GL_POINTS,0, mVoxelGridSize * mVoxelGridSize * mVoxelGridSize); 
		// cant use draw because oF just draws if we have position attribute
		mVoxelVBO.bind();
		glDrawArrays(GL_POINTS,0, mVoxelGridSize * mVoxelGridSize * mVoxelGridSize);
		mVoxelVBO.unbind();

		mVoxelGridShader.end();

	
	}
	
	camera.end();
	ofDisableDepthTest();
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


void ofApp::fillVoxelGrid(){


	// clear buffer to write the new values 
	const GLfloat zero = 0;
	mVoxelBuffer.bind(GL_SHADER_STORAGE_BUFFER);
	glClearBufferData(GL_SHADER_STORAGE_BUFFER, GL_R32F, GL_RED, GL_FLOAT, &zero );		
	mVoxelBuffer.unbind(GL_SHADER_STORAGE_BUFFER);


	particlesBuffer.bindBase(GL_SHADER_STORAGE_BUFFER, 0);
	mVoxelBuffer.bindBase(GL_SHADER_STORAGE_BUFFER,1);

	mVoxelComputeShader.begin();
	
	mVoxelComputeShader.setUniform3f("g_modelTranslation", mModelAnimation.getTranslation() );
	mVoxelComputeShader.setUniform3f( "g_minBB" , mSimulationBoundingBox.min);
	mVoxelComputeShader.setUniform3f( "g_maxBB" , mSimulationBoundingBox.max);
	mVoxelComputeShader.setUniform1i( "g_gridSize", mVoxelGridSize); 
	mVoxelComputeShader.dispatchCompute(mNumWorkGroups , 1 , 1);

	mVoxelComputeShader.end();
	glMemoryBarrier(GL_SHADER_STORAGE_BARRIER_BIT); // wait till we finished writing the voxelgrid


}


ofApp::AABB ofApp::calculateBoundingBox( ofMesh &mesh , float hairlength ){

	float maxFloat = std::numeric_limits<float>::max();
	float minFloat = std::numeric_limits<float>::min();
	ofVec3f min(maxFloat), max(minFloat); 
	AABB boundingBox; 

	for( auto& vertexIter = mesh.getVertices().begin(); vertexIter != mesh.getVertices().end(); vertexIter++ ){
	
		float x = vertexIter->x;
		float y = vertexIter->y;
		float z = vertexIter->z;

		if( x < min.x ) min.x = x; 
		if( y < min.y ) min.y = y; 
		if( z < min.z ) min.z = z; 
		if( x > max.x ) max.x = x; 
		if( y > max.y ) max.y = y; 
		if( z > max.z ) max.z = z; 
						
	}

	min -= hairlength;
	max += hairlength; 

	boundingBox.min = min;
	boundingBox.max = max; 
	
	return boundingBox;

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
