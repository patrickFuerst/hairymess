#include "ofApp.h"
#include "ofConstants.h"

#define NUM_HAIR_PARTICLES 8   // number must not be bigger then WORK_GROUP_SIZE , current 32 max, because glsl for loop limited
#define MIN_HAIR_LENGTH 1.0f
#define MAX_HAIR_LENGTH 1.5f

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
	mComputeShaderSimulation.setupShaderFromFile(GL_COMPUTE_SHADER,"hairSimulation.glsl");
	mComputeShaderSimulation.linkProgram();
	//mComputeShaderSimulation.begin();
	//int size[3];
	//glGetProgramiv( mComputeShaderSimulation.getProgram(), GL_COMPUTE_WORK_GROUP_SIZE, size);

	//mComputeShaderSimulation.printSubroutineNames(GL_COMPUTE_SHADER);
	//mComputeShaderSimulation.printSubroutineUniforms(GL_COMPUTE_SHADER);

	mHairshader.setupShaderFromFile( GL_VERTEX_SHADER, "basic_VS.glsl");
	mHairshader.setupShaderFromFile( GL_FRAGMENT_SHADER, "basic_FS.glsl");
	mHairshader.linkProgram();

	mVoxelComputeShaderFill.setupShaderFromFile(GL_COMPUTE_SHADER, "voxelGridFill.glsl" );
	mVoxelComputeShaderFill.linkProgram();

	mVoxelComputeShaderPostProcess.setupShaderFromFile(GL_COMPUTE_SHADER, "voxelGridPost.glsl" );
	mVoxelComputeShaderPostProcess.linkProgram();

	mVoxelComputeShaderFilter.setupShaderFromFile(GL_COMPUTE_SHADER, "voxelGridFilter.glsl" );
	mVoxelComputeShaderFilter.linkProgram();

	//mVoxelComputeShaderFill.begin();
	//	int size2[3];
	//	glGetIntegeri_v(GL_MAX_COMPUTE_WORK_GROUP_SIZE,0, &size2[0]);
	//	glGetIntegeri_v(GL_MAX_COMPUTE_WORK_GROUP_SIZE,1, &size2[1]);
	//	glGetIntegeri_v(GL_MAX_COMPUTE_WORK_GROUP_SIZE,2, &size2[2]);
	//	int maxInv;
	//	glGetIntegerv(GL_MAX_COMPUTE_WORK_GROUP_INVOCATIONS, &maxInv );
	//	glGetIntegerv(GL_MAX_COMPUTE_WORK_GROUP_COUNT, &maxInv );
	//

	/*mComputeShaderSimulation.setUniform1i("g_numVerticesPerStrand",NUM_HAIR_PARTICLES);
	mComputeShaderSimulation.setUniform1i("g_numStrandsPerThreadGroup", mNumHairs * mNumHairs / WORK_GROUP_SIZE);	*/

	mVoxelGridShader.load( "voxelGrid_vs.glsl", "voxelGrid_fs.glsl" );

	mParticlesBuffer.setData(mParticles,GL_DYNAMIC_DRAW);
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
		mConstSimulationData.gravityForce = ofVec4f(0,-10,0,0);
		mConstSimulationData.numVerticesPerStrand = NUM_HAIR_PARTICLES;
		mConstSimulationData.numStrandsPerThreadGroup =   WORK_GROUP_SIZE / NUM_HAIR_PARTICLES;
		mConstSimulationData.numStrands = mNumHairStands;

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

void ofApp::fillVoxelGrid(float timeStep){
	// clear buffer to write the new values
	static const GLfloat zero = 0;

	mVoxelGradientBuffer.getReadBuffer().bind(GL_SHADER_STORAGE_BUFFER);
	glClearBufferData(GL_SHADER_STORAGE_BUFFER, GL_R32F, GL_RED, GL_FLOAT, &zero );
	mVoxelGradientBuffer.getReadBuffer().unbind(GL_SHADER_STORAGE_BUFFER);

	mVoxelGradientBuffer.getWriteBuffer().bind(GL_SHADER_STORAGE_BUFFER);
	glClearBufferData(GL_SHADER_STORAGE_BUFFER, GL_R32F, GL_RED, GL_FLOAT, &zero );
	mVoxelGradientBuffer.getWriteBuffer().unbind(GL_SHADER_STORAGE_BUFFER);

	mDensityBuffer.bind(GL_SHADER_STORAGE_BUFFER);
	glClearBufferData(GL_SHADER_STORAGE_BUFFER, GL_R32F, GL_RED, GL_FLOAT, &zero );
	mDensityBuffer.unbind(GL_SHADER_STORAGE_BUFFER);

	mVoxelVelocityBuffer.getReadBuffer().bind(GL_SHADER_STORAGE_BUFFER);
	glClearBufferData(GL_SHADER_STORAGE_BUFFER, GL_R32F, GL_RED, GL_FLOAT, &zero );
	mVoxelVelocityBuffer.getReadBuffer().unbind(GL_SHADER_STORAGE_BUFFER);

	mVoxelVelocityBuffer.getWriteBuffer().bind(GL_SHADER_STORAGE_BUFFER);
	glClearBufferData(GL_SHADER_STORAGE_BUFFER, GL_R32F, GL_RED, GL_FLOAT, &zero );
	mVoxelVelocityBuffer.getWriteBuffer().unbind(GL_SHADER_STORAGE_BUFFER);

	pushGlDebugGroup( "Fill Voxel Grid" );

	// fill voxel grid with velocity and density

	mParticlesBuffer.bindBase( GL_SHADER_STORAGE_BUFFER, ShaderStorageBuffers::ParticleData );
	mDensityBuffer.bindBase( GL_SHADER_STORAGE_BUFFER, ShaderStorageBuffers::DensityData );
	mVoxelVelocityBuffer.getWriteBuffer().bindBase( GL_SHADER_STORAGE_BUFFER, ShaderStorageBuffers::VelocityWriteData );

	mVoxelComputeShaderFill.begin();

	glBindBufferBase( GL_UNIFORM_BUFFER , UniformBuffers::ModelData, mUbos[UniformBuffers::ModelData] );
	glBindBufferBase( GL_UNIFORM_BUFFER , UniformBuffers::ConstVoxelGridData, mUbos[UniformBuffers::ConstVoxelGridData] );

	mVoxelComputeShaderFill.dispatchCompute(mNumWorkGroups , 1 , 1);

	glBindBufferBase( GL_UNIFORM_BUFFER , UniformBuffers::ModelData, 0 );
	glBindBufferBase( GL_UNIFORM_BUFFER , UniformBuffers::ConstVoxelGridData, 0 );

	mVoxelComputeShaderFill.end();
	glMemoryBarrier( GL_SHADER_STORAGE_BARRIER_BIT ); // wait till we finished writing the voxelgrid

	mParticlesBuffer.unbindBase( GL_SHADER_STORAGE_BUFFER, ShaderStorageBuffers::ParticleData );
	mDensityBuffer.unbindBase( GL_SHADER_STORAGE_BUFFER, ShaderStorageBuffers::DensityData );
	mVoxelVelocityBuffer.getWriteBuffer().unbindBase( GL_SHADER_STORAGE_BUFFER, ShaderStorageBuffers::VelocityWriteData );
	popGlDebugGroup();

	pushGlDebugGroup( "Post-Process Voxel Grid" );

	int voxelComputeLocalSize = 8;
	int voxelGridWorkGroups  = ((mVoxelGridSize + (voxelComputeLocalSize-1))/ voxelComputeLocalSize);

	// post process voxel grid - normalize velocity and create gradient of density field
	mVoxelComputeShaderPostProcess.begin();

	mVoxelGradientBuffer.getWriteBuffer().bindBase(GL_SHADER_STORAGE_BUFFER,ShaderStorageBuffers::GradientWriteData);
	mDensityBuffer.bindBase( GL_SHADER_STORAGE_BUFFER,ShaderStorageBuffers::DensityData);
	mVoxelVelocityBuffer.getWriteBuffer().bindBase( GL_SHADER_STORAGE_BUFFER,ShaderStorageBuffers::VelocityWriteData);

	glBindBufferBase( GL_UNIFORM_BUFFER , UniformBuffers::ConstVoxelGridData, mUbos[UniformBuffers::ConstVoxelGridData] );

	mVoxelComputeShaderPostProcess.dispatchCompute(voxelGridWorkGroups , voxelGridWorkGroups , voxelGridWorkGroups);
	glMemoryBarrier(GL_SHADER_STORAGE_BARRIER_BIT); // wait till we finished writing the voxelgrid

	glBindBufferBase( GL_UNIFORM_BUFFER , UniformBuffers::ConstVoxelGridData, 0 );

	mVoxelComputeShaderPostProcess.end();

	mVoxelGradientBuffer.getWriteBuffer().unbindBase(GL_SHADER_STORAGE_BUFFER, ShaderStorageBuffers::GradientWriteData );
	mDensityBuffer.unbindBase( GL_SHADER_STORAGE_BUFFER, ShaderStorageBuffers::DensityData );
	mVoxelVelocityBuffer.getWriteBuffer().unbindBase( GL_SHADER_STORAGE_BUFFER, ShaderStorageBuffers::VelocityWriteData );
	mVoxelVelocityBuffer.swap();
	mVoxelGradientBuffer.swap();
	popGlDebugGroup();

	// filter velocity and gradient grid

	if(mUseFilter){
		pushGlDebugGroup( "Filter Voxel Grid" );
		mVoxelComputeShaderFilter.begin();

		glBindBufferBase( GL_UNIFORM_BUFFER , UniformBuffers::ConstVoxelGridData, mUbos[UniformBuffers::ConstVoxelGridData] );

		// filter in every direction x,y,z
		for(int i=0; i < 3; i++){
			mVoxelGradientBuffer.getReadBuffer().bindBase( GL_SHADER_STORAGE_BUFFER, ShaderStorageBuffers::GradientReadData );
			mVoxelGradientBuffer.getWriteBuffer().bindBase( GL_SHADER_STORAGE_BUFFER, ShaderStorageBuffers::GradientWriteData );
			mVoxelVelocityBuffer.getReadBuffer().bindBase( GL_SHADER_STORAGE_BUFFER, ShaderStorageBuffers::VelocityReadData );
			mVoxelVelocityBuffer.getWriteBuffer().bindBase( GL_SHADER_STORAGE_BUFFER,  ShaderStorageBuffers::VelocityWriteData );

			mVoxelComputeShaderFilter.setUniform1i("g_filterPass", i);

			mVoxelComputeShaderFilter.dispatchCompute(voxelGridWorkGroups , voxelGridWorkGroups , voxelGridWorkGroups);
			glMemoryBarrier(GL_SHADER_STORAGE_BARRIER_BIT); // wait till we finished writing the voxelgrid

			mVoxelGradientBuffer.getReadBuffer().unbindBase( GL_SHADER_STORAGE_BUFFER, ShaderStorageBuffers::GradientReadData );
			mVoxelGradientBuffer.getWriteBuffer().unbindBase( GL_SHADER_STORAGE_BUFFER, ShaderStorageBuffers::GradientWriteData );
			mVoxelVelocityBuffer.getReadBuffer().unbindBase( GL_SHADER_STORAGE_BUFFER, ShaderStorageBuffers::VelocityReadData );
			mVoxelVelocityBuffer.getWriteBuffer().unbindBase( GL_SHADER_STORAGE_BUFFER,  ShaderStorageBuffers::VelocityWriteData );
			mVoxelVelocityBuffer.swap();
			mVoxelGradientBuffer.swap();
		}

		glBindBufferBase( GL_UNIFORM_BUFFER , UniformBuffers::ConstVoxelGridData, 0 );

		mVoxelComputeShaderFilter.end();

		popGlDebugGroup();
	}
}

//--------------------------------------------------------------
void ofApp::setup(){
	// setup opengl debuging
	glEnable(GL_DEBUG_OUTPUT_SYNCHRONOUS );
	glDebugMessageCallback( ofApp::glErrorCallback , nullptr );

	mReloadShaders = true;
	ofSetLogLevel( OF_LOG_VERBOSE);
	ofSetVerticalSync(false);
	camera.setAutoDistance(false);
	camera.setupPerspective(false,60,0.1,1000);
	camera.setPosition(10,15,10);
	camera.lookAt(ofVec3f(0,0,0));

	mFloor = ofMesh::plane(30,30 );
	
	mAnimatedModel.loadModel("models/boyMerged.dae", true);
	mAnimatedModel.disableColors();
	mAnimatedModel.disableTextures();
	mAnimatedModel.disableNormals();
	mAnimatedModel.disableMaterials();
	//mAnimatedModel.setPosition(0,0,0);
	//mAnimatedModel.setScaleNormalization(100);
	mAnimatedModel.setLoopStateForAllAnimations(OF_LOOP_NORMAL);
	mAnimatedModel.playAllAnimations();
	mAnimatedModel.update();

	mRootBufferId = mAnimatedModel.getMeshHelper(0).vbo.getVertexBuffer().getId();
	mFurryMesh = mAnimatedModel.getCurrentAnimatedMesh(0);
	mNumHairStands = mFurryMesh.getNumVertices();
	mNumParticles = mNumHairStands * NUM_HAIR_PARTICLES;
	
	mParticles.resize(mNumParticles);
	mStrandData.resize(mNumHairStands);

	mNumWorkGroups = (( mNumParticles + (WORK_GROUP_SIZE-1))/ WORK_GROUP_SIZE);

	std::vector<ofIndexType> indices; // create indices for line strips, including restart index
	indices.resize( mNumParticles + mNumHairStands ); // we need storage for indices for every particle, plus the restart index after each hair strand
	int restartIndex = std::numeric_limits<ofIndexType>::max();

	int index = 0;
	int index2 = 0;

	// create ParticleData 
	// position along the normals of each vertex 
	// root vertex is fixed
	for (int i = 0; i <  mFurryMesh.getNumVertices(); i++)
	{
		float hairLength = MIN_HAIR_LENGTH  + ofRandom(1.0) * (MAX_HAIR_LENGTH - MIN_HAIR_LENGTH); 

		ofFloatColor startColor, endColor;
		if( i % 2 == 0){
			startColor = ofFloatColor::greenYellow;
			endColor = ofFloatColor::deepSkyBlue;
		}else{
			startColor = ofFloatColor::red;
			endColor = ofFloatColor::black;
		}

		ofVec3f v =  mAnimatedModel.getModelMatrix() * mFurryMesh.getVertex(i);
		ofVec3f n =  mFurryMesh.getNormal(i);
		for (int j = 0; j < NUM_HAIR_PARTICLES; j++)
		{
			
			indices.at(index2) = index;

			auto& p = mParticles.at(index);
			p.pos = v + j* n * hairLength / NUM_HAIR_PARTICLES;
			p.pos.w = 1.0;
			p.prevPos = p.pos;
			p.vel.set(0,0,0,0);
			p.color.set( startColor.lerp( endColor, float(j)/ NUM_HAIR_PARTICLES ) );
			p.fixed = j == 0 ? true : false;
			index++;
			index2++;
		}

		mStrandData.at(i).strandLength  = hairLength; 
		indices.at(index2) = restartIndex;
		index2++;
	}

	glGenBuffers((int)UniformBuffers::Size, mUbos);

	mModelAnimation.makeIdentityMatrix();

	// PARTICLE BUFFER
	mParticlesBuffer.allocate(mParticles,GL_DYNAMIC_DRAW);
	mParticlesBuffer.bindBase(GL_SHADER_STORAGE_BUFFER, 0);
	mHairVbo.setVertexBuffer(mParticlesBuffer,4,sizeof(ParticleData));
	mHairVbo.setColorBuffer(mParticlesBuffer,  sizeof(ParticleData), offsetof(ParticleData, ParticleData::color) );
	mHairVbo.setIndexData( indices.data() , indices.size() , GL_STATIC_DRAW );

	// STRAND DATA BUFFER
	mStrandDataBuffer.allocate(mStrandData, GL_STATIC_DRAW ); 


	// enable and set the right restart index
	glEnable(GL_PRIMITIVE_RESTART );
	glPrimitiveRestartIndex( restartIndex );
	glDisable(GL_PRIMITIVE_RESTART);

	// VOXEL BUFFERS

	mVoxelGridSize = VOXEL_GRID_SIZE;

	mVoxelGradientBuffer.allocate( sizeof(ofVec4f) * mVoxelGridSize * mVoxelGridSize * mVoxelGridSize, GL_STREAM_COPY);
	mDensityBuffer.allocate( sizeof(float)* mVoxelGridSize * mVoxelGridSize * mVoxelGridSize, GL_STREAM_COPY);
	mVoxelVelocityBuffer.allocate( sizeof(ofVec4f)* mVoxelGridSize * mVoxelGridSize * mVoxelGridSize, GL_STREAM_COPY);

	// just for debuging voxel grid
	mVoxelVBO.setAttributeBuffer( VELOCITY , mVoxelVelocityBuffer.getReadBuffer() , 4 , sizeof(ofVec4f), 0  ); // first attribute is velocity
	mVoxelVBO.setAttributeBuffer( GRADIENT , mVoxelGradientBuffer.getReadBuffer(), 4 , sizeof(ofVec4f), 0  ); // second attribute is gradient
	mVoxelVBO.setAttributeBuffer( DENSITY , mDensityBuffer, 1 , sizeof(float), 0 ); // third attribute is density

	ofBackground(0);
	ofEnableBlendMode(OF_BLENDMODE_ADD);

	createGui();

	//mSimulationBoundingBox = calculateBoundingBox( mFurryMesh, MAX_HAIR_LENGTH );
	mSimulationBoundingBox.max = ofVec3f(5,10,5);
	mSimulationBoundingBox.min = ofVec3f(-5,0,-5);
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

	mAnimatedModel.update();


	//ofMatrix4x4 modelAnimationMatrixDelta = mModelAnimation * mModelAnimationPrevInversed;
	mModelAnimationPrevInversed = mModelAnimation.getInverse();

	//static ofQuaternion first, second;
	//first.makeRotate(0,0,0,0);
	//second.makeRotate(180,1,1,0);
	//mModelOrientation.slerp( sin(0.2f* ofGetElapsedTimef()), first, second);
	mModelAnimation.makeIdentityMatrix();
	mModelAnimation = mAnimatedModel.getModelMatrix();
	//mModelAnimation.postMultRotate(mModelOrientation);
	//mModelAnimation.setTranslation( ofVec3f( 0,4 + 5.0f*abs( sin( ofGetElapsedTimef() ) ), 0));

	updateUBO( timeStep );

	fillVoxelGrid( timeStep ); // fill the voxel grid

	pushGlDebugGroup( "Hair Simulation" );
	mComputeShaderSimulation.begin();
	glBindBufferBase( GL_SHADER_STORAGE_BUFFER, ShaderStorageBuffers::RootData, mRootBufferId ); 

	mParticlesBuffer.bindBase(GL_SHADER_STORAGE_BUFFER, ShaderStorageBuffers::ParticleData);
	mVoxelGradientBuffer.getReadBuffer().bindBase(GL_SHADER_STORAGE_BUFFER, ShaderStorageBuffers::GradientReadData );
	mVoxelVelocityBuffer.getReadBuffer().bindBase( GL_SHADER_STORAGE_BUFFER, ShaderStorageBuffers::VelocityReadData );
	mStrandDataBuffer.bindBase(GL_SHADER_STORAGE_BUFFER, ShaderStorageBuffers::StandData );

	glBindBufferBase( GL_UNIFORM_BUFFER , UniformBuffers::SimulationData, mUbos[UniformBuffers::SimulationData] );
	glBindBufferBase( GL_UNIFORM_BUFFER , UniformBuffers::ConstSimulationData, mUbos[UniformBuffers::ConstSimulationData] );
	glBindBufferBase( GL_UNIFORM_BUFFER , UniformBuffers::ModelData, mUbos[UniformBuffers::ModelData] );
	glBindBufferBase( GL_UNIFORM_BUFFER , UniformBuffers::ConstVoxelGridData, mUbos[UniformBuffers::ConstVoxelGridData] );

	glUniformSubroutinesuiv( GL_COMPUTE_SHADER, 1, mSubroutineUniforms);

	mComputeShaderSimulation.dispatchCompute( mNumWorkGroups, 1, 1);

	glBindBufferBase( GL_UNIFORM_BUFFER , UniformBuffers::ModelData, 0 );
	glBindBufferBase( GL_UNIFORM_BUFFER , UniformBuffers::ConstVoxelGridData, 0 );
	glBindBufferBase( GL_UNIFORM_BUFFER , UniformBuffers::ConstSimulationData, 0 );
	glBindBufferBase( GL_UNIFORM_BUFFER , UniformBuffers::SimulationData, 0 );

	mParticlesBuffer.unbindBase(GL_SHADER_STORAGE_BUFFER, ShaderStorageBuffers::ParticleData);
	mVoxelGradientBuffer.getReadBuffer().unbindBase(GL_SHADER_STORAGE_BUFFER, ShaderStorageBuffers::GradientReadData );
	mVoxelVelocityBuffer.getReadBuffer().unbindBase( GL_SHADER_STORAGE_BUFFER, ShaderStorageBuffers::VelocityReadData );
	mStrandDataBuffer.unbindBase(GL_SHADER_STORAGE_BUFFER, ShaderStorageBuffers::StandData );
	glBindBufferBase( GL_SHADER_STORAGE_BUFFER, ShaderStorageBuffers::RootData, 0 ); 

	mComputeShaderSimulation.end();

	popGlDebugGroup();
}


void ofApp::drawAnimatedMesh(){

	mAnimatedModel.drawFaces();
	//mAnimatedModel.getMesh(2).draw();
}

//--------------------------------------------------------------
void ofApp::draw(){
	camera.begin();

	ofEnableDepthTest();
	ofClear( ofColor::white);
	ofDrawAxis(10);
	//ofDrawGrid(1.25, 10 , false,false,true,false);
	ofSetColor(ofColor::white);

	if( mDrawFur ){
		pushGlDebugGroup( "Draw Hair" );
		glPointSize(1);
		
		ofPushMatrix();
		
		mHairshader.begin();
		mHairshader.setUniform4f( "overrideColor", ofVec4f(1,1,1,1.0) );

		glMemoryBarrier(GL_VERTEX_ATTRIB_ARRAY_BARRIER_BIT); //?
		//mHairVbo.draw(GL_POINTS,0,mParticles.size());
		glEnable(GL_PRIMITIVE_RESTART);
		mHairVbo.drawElements( GL_LINE_STRIP , mHairVbo.getNumIndices() );
		glDisable(GL_PRIMITIVE_RESTART);

		mHairshader.end();
		ofPopMatrix();
		//ofSetColor(ofColor::red);
		//ofPushMatrix();
		//ofMultViewMatrix(mModelAnimation);
		//mFurryMesh.draw();
		//ofPopMatrix();

		drawAnimatedMesh();


		//drawFloor();

		popGlDebugGroup();
	}/*else{
		ofSetColor(ofColor::ghostWhite);
		ofPushMatrix();
		ofRotateX(90);
		mFloor.draw();
		ofPopMatrix();
	}*/

	if( mDrawBoundingBox ){
		pushGlDebugGroup( "Draw BoundingBox" );

		ofNoFill();
		ofSetColor(ofColor::red);
		ofVec3f position = ( mSimulationBoundingBox.max +  mSimulationBoundingBox.min) / 2.0f;// + mModelAnimation.getTranslation();
		float width =  mSimulationBoundingBox.max.x -  mSimulationBoundingBox.min.x;
		float height =  mSimulationBoundingBox.max.y -mSimulationBoundingBox.min.y;
		float depth =  mSimulationBoundingBox.max.z - mSimulationBoundingBox.min.z;
		ofDrawBox(position, width, height, depth ) ;
		ofFill();

		popGlDebugGroup();
	}
	if( mDrawVoxelGrid ){
		pushGlDebugGroup( "Draw Voxel Grid" );

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

		popGlDebugGroup();
	}

	camera.end();
	ofDisableDepthTest();
	ofEnableBlendMode(OF_BLENDMODE_ALPHA);
	ofSetColor(255);
	gui.draw();

	drawInfo();
	drawDebug();
}

void ofApp::drawFloor(){
	glEnable(GL_STENCIL_TEST );

	// draw floor
	glStencilFunc(GL_ALWAYS , 1 , 0xFF );
	glStencilOp(GL_KEEP, GL_KEEP, GL_REPLACE );
	glStencilMask(0xFF );
	glDepthMask(GL_FALSE);
	glClear(GL_STENCIL_BUFFER_BIT );

	ofSetColor(ofColor::ghostWhite);
	ofPushMatrix();
	ofRotateX(90);
	mFloor.draw();
	ofPopMatrix();

	// draw ball reflection

	glStencilFunc(GL_EQUAL, 1, 0xFF );
	glStencilMask( 0x00 );
	glDepthMask(GL_TRUE);

	ofPushMatrix();

	ofMultMatrix( ofMatrix4x4::newScaleMatrix(1,-1,1) ) ;
	mHairshader.begin();
	mHairshader.setUniform4f( "overrideColor", ofVec4f(0.6,0.6,0.6,0.8) );
	glMemoryBarrier(GL_VERTEX_ATTRIB_ARRAY_BARRIER_BIT); //?
	//mHairVbo.draw(GL_POINTS,0,mParticles.size());
	glEnable(GL_PRIMITIVE_RESTART);
	mHairVbo.drawElements( GL_LINE_STRIP , mHairVbo.getNumIndices() );
	glDisable(GL_PRIMITIVE_RESTART);
	mHairshader.setUniform4f( "overrideColor", ofVec4f(1,1,1,1.0) );

	mHairshader.end();

	ofMatrix4x4 mirrorMatrix = mModelAnimation;

	ofColor red = ofColor::red;
	red.r *= 0.6;
	red.g *= 0.6;
	red.b *= 0.6;
	red.a *= 0.8;
	ofSetColor(red);
	ofPushMatrix();
	ofMultViewMatrix(mModelAnimation);
	mFurryMesh.draw();
	ofPopMatrix();

	ofPopMatrix();

	glDisable(GL_STENCIL_TEST );
}

void ofApp::algorithmChanged(const void* sender ) {
	ofxButton* button = (ofxButton*) sender;
	string name = button->getName();
	GLint subroutine = 0;

	if( name == "PBD Algorithm" )
		subroutine = mComputeShaderSimulation.getSubroutineLocation( GL_COMPUTE_SHADER , "PBDApproach");
	else if( name == "DFTL Algorithm" )
		subroutine = mComputeShaderSimulation.getSubroutineLocation( GL_COMPUTE_SHADER , "DFTLApproach");

	mSubroutineUniforms[0] = subroutine;
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
	mUseFilter.setName( "Use Filter" );

	gui.add( &mPBDAlgorithm);
	gui.add( &mDFTLAlgorithm);
	gui.add( mUseFilter );
	gui.add( mDrawBoundingBox );
	gui.add( mDrawVoxelGrid );
	gui.add( mDrawFur );
	gui.add( mShaderUniforms);
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
		ofLogVerbose("OpenGl debug message too long");
	}else{
		glPushDebugGroup(GL_DEBUG_SOURCE_APPLICATION, NULL , message.size() , message.data() );
	}
}

void ofApp::popGlDebugGroup(){
	glPopDebugGroup();
}

void GLAPIENTRY ofApp::glErrorCallback(GLenum source,
									   GLenum type,
									   GLuint id,
									   GLenum severity,
									   GLsizei length,
									   const GLchar* message,
									   const void* userParam){
										   if( severity == GL_DEBUG_SEVERITY_NOTIFICATION)
											   return ;

										   cout << "---------------------opengl-callback-start------------" << endl;
										   cout << "message: "<< message << endl;
										   cout << "type: ";
										   switch (type) {
										   case GL_DEBUG_TYPE_ERROR:
											   cout << "ERROR";
											   break;
										   case GL_DEBUG_TYPE_DEPRECATED_BEHAVIOR:
											   cout << "DEPRECATED_BEHAVIOR";
											   break;
										   case GL_DEBUG_TYPE_UNDEFINED_BEHAVIOR:
											   cout << "UNDEFINED_BEHAVIOR";
											   break;
										   case GL_DEBUG_TYPE_PORTABILITY:
											   cout << "PORTABILITY";
											   break;
										   case GL_DEBUG_TYPE_PERFORMANCE:
											   cout << "PERFORMANCE";
											   break;
										   case GL_DEBUG_TYPE_OTHER:
											   cout << "OTHER";
											   break;
										   }
										   cout << endl;

										   cout << "id: " << id << endl;
										   cout << "severity: ";
										   switch (severity){
										   case GL_DEBUG_SEVERITY_LOW:
											   cout << "LOW";
											   break;
										   case GL_DEBUG_SEVERITY_MEDIUM:
											   cout << "MEDIUM";
											   break;
										   case GL_DEBUG_SEVERITY_HIGH:
											   cout << "HIGH";
											   break;
										   }
										   cout << endl;
										   cout << "---------------------opengl-callback-end--------------" << endl;
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

	//ofSetColor(0, 255, 0);
	ofSetColor( ofColor::black );
	ofDrawBitmapString( info, 30, ofGetWindowHeight() - 150);
	ofSetColor(255, 255, 255);
}