#include "ofApp.h"
#include "ofConstants.h"


#define NUM_HAIR_PARTICLES 16   // number must not be bigger then WORK_GROUP_SIZE , current 32 max, because glsl for loop limited
#define HAIR_LENGTH 2.0f


#define WORK_GROUP_SIZE 64

#define VOXEL_GRID_SIZE 64

// glsl locations
#define POSITION	0
#define COLOR		1
#define NORMAL		2
#define TEXCOORD    3

#define VELOCITY 4
#define GRADIENT 5
#define DENSITY 6 


void ofApp::reloadShaders(){


	

	mComputeShader.setupShaderFromFile(GL_COMPUTE_SHADER,"hairSimulation.glsl");
	mComputeShader.linkProgram();
	mComputeShader.begin();
	int size[3]; 
	glGetProgramiv( mComputeShader.getProgram(), GL_COMPUTE_WORK_GROUP_SIZE, size);
	

	//mComputeShader.printSubroutineNames(GL_COMPUTE_SHADER);
	//mComputeShader.printSubroutineUniforms(GL_COMPUTE_SHADER);

	
	mHairshader.setupShaderFromFile( GL_VERTEX_SHADER, "basic_VS.glsl");
	mHairshader.setupShaderFromFile( GL_FRAGMENT_SHADER, "basic_FS.glsl");
	mHairshader.linkProgram();
	


	mVoxelComputeShaderFill.setupShaderFromFile(GL_COMPUTE_SHADER, "voxelGridFill.glsl" ); 
	mVoxelComputeShaderFill.linkProgram();

	mVoxelComputeShaderPostProcess.setupShaderFromFile(GL_COMPUTE_SHADER, "voxelGridPost.glsl" ); 
	mVoxelComputeShaderPostProcess.linkProgram();

	//mVoxelComputeShaderFill.begin();
	//	int size2[3]; 
	//	glGetIntegeri_v(GL_MAX_COMPUTE_WORK_GROUP_SIZE,0, &size2[0]);
	//	glGetIntegeri_v(GL_MAX_COMPUTE_WORK_GROUP_SIZE,1, &size2[1]);
	//	glGetIntegeri_v(GL_MAX_COMPUTE_WORK_GROUP_SIZE,2, &size2[2]);
	//	int maxInv; 
	//	glGetIntegerv(GL_MAX_COMPUTE_WORK_GROUP_INVOCATIONS, &maxInv ); 
	//	glGetIntegerv(GL_MAX_COMPUTE_WORK_GROUP_COUNT, &maxInv ); 
	//


	/*mVoxelComputeShader.setUniform1i("g_numVerticesPerStrand",NUM_HAIR_PARTICLES);
	mVoxelComputeShader.setUniform1i("g_numStrandsPerThreadGroup", mNumHairs * mNumHairs / WORK_GROUP_SIZE);	*/
		



	mVoxelGridShader.load( "voxelGrid_vs.glsl", "voxelGrid_fs.glsl" ); 




	particlesBuffer.setData(particles,GL_DYNAMIC_DRAW);



	mModelAnimation.makeIdentityMatrix();
}

void ofApp::updateUBO( float deltaTime ){


	static bool uboInit = false; 

	mSimulationData.velocityDamping = mVelocityDamping;
	mSimulationData.numIterationsPBD = mNumConstraintIterations; 
	mSimulationData.stiffness = mStiffness;
	mSimulationData.friction = mFriction;
	mSimulationData.repulsion = mRepulsion;
	mSimulationData.ftlDamping = mFTLDistanceDamping;
	mSimulationData.deltaTime = deltaTime;


	mModelData.modelMatrix = mModelAnimation;
	mModelData.modelMatrixPrevInverted = mModelAnimationPrevInversed; 
	mModelData.modelTranslation =  mModelAnimation.getTranslation();

	mVoxelGridData.deltaTime = deltaTime;
	
	if(	!uboInit ){
		mConstSimulationData.gravityForce = ofVec4f(20,-2,0,0);
		mConstSimulationData.numVerticesPerStrand = NUM_HAIR_PARTICLES;
		mConstSimulationData.numStrandsPerThreadGroup =   WORK_GROUP_SIZE / NUM_HAIR_PARTICLES;
		mConstSimulationData.strandLength = HAIR_LENGTH;

		mConstVoxelGridData.minBB = mSimulationBoundingBox.min;
		mConstVoxelGridData.maxBB = mSimulationBoundingBox.max;
		mConstVoxelGridData.gridSize = mVoxelGridSize;
	
		glBindBuffer(GL_UNIFORM_BUFFER, mUbos[UniformBuffers::ConstSimulationData]);
		glBufferData( GL_UNIFORM_BUFFER, sizeof(ConstSimulationData), &mConstSimulationData, GL_STATIC_DRAW );
		
		glBindBuffer(GL_UNIFORM_BUFFER, mUbos[UniformBuffers::ConstVoxelGridData]);
		glBufferData( GL_UNIFORM_BUFFER, sizeof(ofApp::ConstVoxelGridData), &mConstVoxelGridData, GL_STATIC_DRAW ); 		
	
	}

	glBindBuffer(GL_UNIFORM_BUFFER, mUbos[UniformBuffers::SimulationData]);
	glBufferData( GL_UNIFORM_BUFFER, sizeof(SimulationData), &mSimulationData, GL_DYNAMIC_DRAW ); 

	glBindBuffer(GL_UNIFORM_BUFFER, mUbos[UniformBuffers::VoxelGridData]);
	glBufferData( GL_UNIFORM_BUFFER, sizeof(VoxelGridData), &mVoxelGridData, GL_DYNAMIC_DRAW );

	glBindBuffer(GL_UNIFORM_BUFFER, mUbos[UniformBuffers::ModelData]);
	glBufferData( GL_UNIFORM_BUFFER, sizeof(ModelData), &mModelData, GL_DYNAMIC_DRAW );

	glBindBuffer( GL_UNIFORM_BUFFER, 0);
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
	
	mFurryMesh = ofMesh::sphere(4,120); 
	mNumHairStands = mFurryMesh.getNumVertices();
	mNumParticles = mNumHairStands * NUM_HAIR_PARTICLES;
	particles.resize(mNumParticles);

	mNumWorkGroups = (( mNumParticles + (WORK_GROUP_SIZE-1))/ WORK_GROUP_SIZE);
	
	std::vector<ofIndexType> indices; // create indices for line strips, including restart index 
	indices.resize( mNumParticles + mNumHairStands ); // we need storage for an indices for every particle, plus the restart index after each hair strand
	int restartIndex = std::numeric_limits<ofIndexType>::max();

	int index = 0; 
	int index2 = 0;

	for (int i = 0; i <  mFurryMesh.getNumVertices(); i++)
	{

		ofVec3f v = mFurryMesh.getVertex(i);
		ofVec3f n = mFurryMesh.getNormal(i);
		for (int j = 0; j < NUM_HAIR_PARTICLES; j++)
		{
			ofFloatColor startColor = ofFloatColor::greenYellow;
		ofFloatColor endColor = ofFloatColor::deepSkyBlue; 

			indices.at(index2) = index;  

			auto& p = particles.at(index);
			p.pos = v + j* n * HAIR_LENGTH / NUM_HAIR_PARTICLES;
			p.pos.w = 1.0; 
			p.prevPos = p.pos;
			p.vel.set(0,0,0,0);
			p.color.set( startColor.lerp( endColor, float(j)/ NUM_HAIR_PARTICLES ) );
			p.fixed = j == 0 ? true : false;
			index++;
			index2++;
		}

		indices.at(index2) = restartIndex;  
		index2++;


	}

	glGenBuffers((int)UniformBuffers::Size, mUbos);


	mModelAnimation.makeIdentityMatrix();

	// PARTICLE BUFFER
	particlesBuffer.allocate(particles,GL_DYNAMIC_DRAW);
	particlesBuffer.bindBase(GL_SHADER_STORAGE_BUFFER, 0);
	mHairVbo.setVertexBuffer(particlesBuffer,4,sizeof(Particle));
	mHairVbo.setColorBuffer(particlesBuffer,  sizeof(Particle), offsetof(Particle, Particle::color) ); 
	mHairVbo.setIndexData( indices.data() , indices.size() , GL_STATIC_DRAW );  

	//let enable and set the right restart index 
	glEnable(GL_PRIMITIVE_RESTART ); 
	glPrimitiveRestartIndex( restartIndex ); 
	glDisable(GL_PRIMITIVE_RESTART);

	// VOXEL BUFFER

	//mDensityBuffer1.allocate( sizeof(float)* mVoxelGridSize * mVoxelGridSize * mVoxelGridSize, GL_STREAM_COPY);
	//mDensityBuffer2.allocate( sizeof(float)* mVoxelGridSize * mVoxelGridSize * mVoxelGridSize, GL_STREAM_COPY);



	mVoxelGridSize = VOXEL_GRID_SIZE;
	mVoxelBuffer.allocate( sizeof(Voxel) * mVoxelGridSize * mVoxelGridSize * mVoxelGridSize, GL_STREAM_COPY);
	mVoxelBuffer.bindBase(GL_SHADER_STORAGE_BUFFER,1);
	mVoxelVBO.setAttributeBuffer( VELOCITY , mVoxelBuffer, 4 , sizeof(Voxel), offsetof(Voxel, Voxel::velocity)  ); // first attribute is velocity 
	mVoxelVBO.setAttributeBuffer( GRADIENT , mVoxelBuffer, 4 , sizeof(Voxel), offsetof(Voxel, Voxel::gradient)  ); // second attribute is gradient 
	mVoxelVBO.setAttributeBuffer( DENSITY , mVoxelBuffer, 1 , sizeof(Voxel), offsetof(Voxel, Voxel::density) ); // third attribute is density  
	//mVoxelVBO.setAttributeBuffer( DENSITY , mDensityBuffer1, 1 , sizeof(float), 0 ); // third attribute is density  


	ofBackground(0);
	ofEnableBlendMode(OF_BLENDMODE_ADD);

	createGui();

	mSimulationBoundingBox = calculateBoundingBox( mFurryMesh, HAIR_LENGTH ); 
	mDrawBoundingBox = false; 



}

//--------------------------------------------------------------
void ofApp::update(){
	
	if(mReloadShaders){

		reloadShaders();
		mReloadShaders = false; 
	}
	
	
	float timeStep = ofGetLastFrameTime();
	if( timeStep > 0.02)  // prevent to high timesteps at the beginning of the app start
		timeStep = 0.02;


	ofMatrix4x4 modelAnimationMatrixDelta = mModelAnimation * mModelAnimationPrevInversed;
	mModelAnimationPrevInversed = mModelAnimation.getInverse();

	static ofQuaternion first, second; 
	first.makeRotate(0,0,0,0);
	second.makeRotate(180,1,1,0);
	mModelOrientation.slerp( sin(0.2f* ofGetElapsedTimef()), first, second);
	mModelAnimation.makeIdentityMatrix();
	//mModelAnimation.postMultRotate(mModelOrientation);
	mModelAnimation.setTranslation( ofVec3f( 0,5.0f*abs( sin( ofGetElapsedTimef() ) ), 0));


	updateUBO( timeStep ); 

	
	createVoxelGrid( timeStep ); // create the voxel grid 


	pushGlDebugGroup( "Hair Simulation" );
	mComputeShader.begin();
	
	particlesBuffer.bindBase(GL_SHADER_STORAGE_BUFFER, 0);
	mVoxelBuffer.bindBase(GL_SHADER_STORAGE_BUFFER,1);
	
	glBindBufferBase( GL_UNIFORM_BUFFER , UniformBuffers::SimulationData, mUbos[UniformBuffers::SimulationData] ); 
	glBindBufferBase( GL_UNIFORM_BUFFER , UniformBuffers::ConstSimulationData, mUbos[UniformBuffers::ConstSimulationData] ); 
	glBindBufferBase( GL_UNIFORM_BUFFER , UniformBuffers::ModelData, mUbos[UniformBuffers::ModelData] ); 
	glBindBufferBase( GL_UNIFORM_BUFFER , UniformBuffers::ConstVoxelGridData, mUbos[UniformBuffers::ConstVoxelGridData] ); 

	glUniformSubroutinesuiv( GL_COMPUTE_SHADER, 1, subroutineUniforms);
	
	mComputeShader.dispatchCompute( mNumWorkGroups, 1, 1);
	
	glBindBufferBase( GL_UNIFORM_BUFFER , UniformBuffers::ModelData, 0 ); 
	glBindBufferBase( GL_UNIFORM_BUFFER , UniformBuffers::ConstVoxelGridData, 0 ); 
	glBindBufferBase( GL_UNIFORM_BUFFER , UniformBuffers::ConstSimulationData, 0 ); 
	glBindBufferBase( GL_UNIFORM_BUFFER , UniformBuffers::SimulationData, 0 ); 
	
	particlesBuffer.unbindBase(GL_SHADER_STORAGE_BUFFER, 0);
	mVoxelBuffer.unbindBase(GL_SHADER_STORAGE_BUFFER,1);

	mComputeShader.end();

	popGlDebugGroup();

}

//--------------------------------------------------------------
void ofApp::draw(){
	camera.begin();
	ofEnableDepthTest();
	ofClear( ofColor::gray);
	ofDrawAxis(10);
	ofDrawGrid(1.25, 10 , false,false,true,false);

	if( mDrawFur ){

		pushGlDebugGroup( "Draw Hair" );
		glPointSize(1);
	
		mHairshader.begin();

		glMemoryBarrier(GL_VERTEX_ATTRIB_ARRAY_BARRIER_BIT); //? 
		//mHairVbo.draw(GL_POINTS,0,particles.size());
		glEnable(GL_PRIMITIVE_RESTART);
		mHairVbo.drawElements( GL_LINE_STRIP , mHairVbo.getNumIndices() ); 
		glDisable(GL_PRIMITIVE_RESTART);


		mHairshader.end();
		ofSetColor(ofColor::red);
		ofPushMatrix();
		ofMultViewMatrix(mModelAnimation);
		mFurryMesh.draw();
		ofPopMatrix();

		popGlDebugGroup();

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

		glBindBufferBase( GL_UNIFORM_BUFFER , UniformBuffers::ModelData, mUbos[UniformBuffers::ModelData] ); 
		glBindBufferBase( GL_UNIFORM_BUFFER , UniformBuffers::ConstVoxelGridData, mUbos[UniformBuffers::ConstVoxelGridData] ); 
		glPointSize(2);

		//	mVoxelVBO.draw(GL_POINTS,0, mVoxelGridSize * mVoxelGridSize * mVoxelGridSize); 
		// cant use draw because oF just draws if we have position attribute
		mVoxelVBO.bind();
		glDrawArrays(GL_POINTS,0, mVoxelGridSize * mVoxelGridSize * mVoxelGridSize);
		mVoxelVBO.unbind();


		glBindBufferBase( GL_UNIFORM_BUFFER , UniformBuffers::ModelData, 0 ); 
		glBindBufferBase( GL_UNIFORM_BUFFER , UniformBuffers::ConstVoxelGridData, 0 ); 
	
		mVoxelGridShader.end();

	
	}
	
	camera.end();
	ofDisableDepthTest();
	ofEnableBlendMode(OF_BLENDMODE_ALPHA);
	ofSetColor(255);
	gui.draw();

	drawInfo();
	drawDebug();


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


void ofApp::createGui(){

	gui.setup();
	mShaderUniforms.setName("shader params");
	mShaderUniforms.add( mVelocityDamping.set("velocityDamping", 0.5f, 0,1));
	mShaderUniforms.add( mNumConstraintIterations.set("numIterations", 25, 0,200));
	mShaderUniforms.add( mStiffness.set("stiffness",1.0f, 0,1));
	mShaderUniforms.add( mFriction.set("friction",0.1f, 0,1.0));
	mShaderUniforms.add( mRepulsion.set("repulsion",0.1f, 0,5.0));
	mShaderUniforms.add( mFTLDistanceDamping.set("ftlDamping", 1.0,0.0,1.0));
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



}
void ofApp::createVoxelGrid(float timeStep){


	// clear buffer to write the new values 
	const GLfloat zero = 0;
	
	
	
	mVoxelBuffer.bind(GL_SHADER_STORAGE_BUFFER);
	glClearBufferData(GL_SHADER_STORAGE_BUFFER, GL_R32F, GL_RED, GL_FLOAT, &zero );		
	mVoxelBuffer.unbind(GL_SHADER_STORAGE_BUFFER);

	/*mDensityBuffer1.bind(GL_SHADER_STORAGE_BUFFER);
	glClearBufferData(GL_SHADER_STORAGE_BUFFER, GL_R32F, GL_RED, GL_FLOAT, &zero );		
	mDensityBuffer1.unbind(GL_SHADER_STORAGE_BUFFER);

	mDensityBuffer2.bind(GL_SHADER_STORAGE_BUFFER);
	glClearBufferData(GL_SHADER_STORAGE_BUFFER, GL_R32F, GL_RED, GL_FLOAT, &zero );		
	mDensityBuffer2.unbind(GL_SHADER_STORAGE_BUFFER);*/

	pushGlDebugGroup( "Fill Voxel Grid" ); 
	
	particlesBuffer.bindBase(GL_SHADER_STORAGE_BUFFER, 0);
	mVoxelBuffer.bindBase(GL_SHADER_STORAGE_BUFFER,1);
	//mDensityBuffer1.bindBase( GL_SHADER_STORAGE_BUFFER,2);

	mVoxelComputeShaderFill.begin();
	
	glBindBufferBase( GL_UNIFORM_BUFFER , UniformBuffers::ModelData, mUbos[UniformBuffers::ModelData] ); 
	glBindBufferBase( GL_UNIFORM_BUFFER , UniformBuffers::ConstVoxelGridData, mUbos[UniformBuffers::ConstVoxelGridData] ); 


	mVoxelComputeShaderFill.dispatchCompute(mNumWorkGroups , 1 , 1);

	glBindBufferBase( GL_UNIFORM_BUFFER , UniformBuffers::ModelData, 0 ); 
	glBindBufferBase( GL_UNIFORM_BUFFER , UniformBuffers::ConstVoxelGridData, 0 ); 


	mVoxelComputeShaderFill.end();
	glMemoryBarrier(GL_SHADER_STORAGE_BARRIER_BIT); // wait till we finished writing the voxelgrid

	particlesBuffer.unbindBase(GL_SHADER_STORAGE_BUFFER,0); 
	mVoxelBuffer.unbindBase(GL_SHADER_STORAGE_BUFFER,1);
	//mDensityBuffer1.unbindBase( GL_SHADER_STORAGE_BUFFER,2);

	popGlDebugGroup();
		
	pushGlDebugGroup( "Post-Proess Voxel Grid" ); 

	//TODO filter density grid!!
	
	int voxelComputeLocalSize = 8;
	int voxelGridWorkGroups  = ((mVoxelGridSize + (voxelComputeLocalSize-1))/ voxelComputeLocalSize);

	// post process voxel grid - normalize velocity and create gradient of density field


	mVoxelComputeShaderPostProcess.begin();
	
	mVoxelBuffer.bindBase(GL_SHADER_STORAGE_BUFFER,1);
	glBindBufferBase( GL_UNIFORM_BUFFER , UniformBuffers::ConstVoxelGridData, mUbos[UniformBuffers::ConstVoxelGridData] ); 

	mVoxelComputeShaderPostProcess.dispatchCompute(voxelGridWorkGroups , voxelGridWorkGroups , voxelGridWorkGroups);
	glMemoryBarrier(GL_SHADER_STORAGE_BARRIER_BIT); // wait till we finished writing the voxelgrid
	
	glBindBufferBase( GL_UNIFORM_BUFFER , UniformBuffers::ConstVoxelGridData, 0 ); 

	mVoxelComputeShaderPostProcess.end();
	
	particlesBuffer.unbindBase(GL_SHADER_STORAGE_BUFFER,0); 
	mVoxelBuffer.unbindBase(GL_SHADER_STORAGE_BUFFER,1);


	popGlDebugGroup();
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

	min -=  2.0f * hairlength;
	max += 2.0f * hairlength; 

	boundingBox.min = min;
	boundingBox.max = max; 
	
	return boundingBox;

}

void ofApp::exit(){

	glDeleteBuffers( UniformBuffers::Size, mUbos );
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


void ofApp::pushGlDebugGroup( std::string message ){

	int maxLenght; 
	glGetIntegerv(GL_MAX_DEBUG_MESSAGE_LENGTH, &maxLenght );

	if( message.size() > maxLenght ){
		ofLogVerbose("OpenGl debug message toolong"); 
	}else{
	
		glPushDebugGroup(GL_DEBUG_SOURCE_APPLICATION, NULL , message.size() , message.data() );
	}

}

void ofApp::popGlDebugGroup(){

	glPopDebugGroup();
}


void ofApp::drawDebug(){

    ofSetColor(0, 255, 0);
    string framerate = ofToString( ofGetFrameRate() );
    ofDrawBitmapString( framerate, 30, 30);
    ofSetColor(255, 255, 255);
}

void ofApp::drawInfo(){


    string info =
    
    "Press Key:\n"
    "r: reload shaders \n"
	"Num Particles: " + std::to_string(mNumParticles) + "\n"
	"Num Hairstrands: " + std::to_string(mNumHairStands) + "\n"
    "\n"
     "///////  ///////     Furry Ball \n"
     "//   //  //          patrickfuerst.at \n"
     "//////   //// \n"
     "//       // \n"
     "//       // ";
    
    ofSetColor(0, 255, 0);
    ofDrawBitmapString( info, 30, ofGetWindowHeight() - 150);
    ofSetColor(255, 255, 255);



}
