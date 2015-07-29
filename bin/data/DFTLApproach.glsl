
// Dynamic Follow the Leader Approach
	
subroutine(hairSimulationAlgorithm) void DFTLApproach( const uint localStrandIndex,
	const uint localVertexIndex,
	const uint globalStrandIndex,
	const uint vertexIndexInStrand, 
	const vec4 position, 
	const vec4 prevPosition,
	const vec4 color,
	const vec4 force
	){

	
	const vec4 oldPosition = position;
	const float strandLength = sharedLength[localStrandIndex]; 

	vec4 velocity = vec4(0);

	if( !sharedFixed[localVertexIndex] ) {

		velocity = sharedPos[localVertexIndex] - prevPosition; 
		velocity /= g_timeStep; 
		
		checkCollision(prevPosition, sharedPos[localVertexIndex], velocity );
		memoryBarrierShared();


		// calculate the corrected velocity according to the ftl approach 
		vec4 distanceToNext = vec4(0,0,0,0);
		if(vertexIndexInStrand < g_numVerticesPerStrand-1){
			distanceToNext.xyz = sharedPos[localVertexIndex].xyz - sharedPos[localVertexIndex+1].xyz ;
		}
		velocity = velocity - g_ftlDamping *distanceToNext / g_timeStep; 

		velocity = calculateFrictionAndRepulsionVelocityCorrection( velocity, sharedPos[localVertexIndex] );


		sharedPos[localVertexIndex]  = positionIntegration( sharedPos[localVertexIndex], velocity, force );

	}

	
	memoryBarrierShared();
 	groupMemoryBarrier();

 	// apply length constraint
	if(vertexIndexInStrand  == 0){

		for(int i= 0; i < g_numVerticesPerStrand-1; i++){
			bool fix = sharedFixed[localVertexIndex+i+1];
			sharedPos[localVertexIndex+i+1] = applyLengthConstraintDFTL( sharedPos[localVertexIndex+i], true, sharedPos[localVertexIndex+i+1], fix, strandLength/g_numVerticesPerStrand, g_stiffness);			

		}

	}

 	groupMemoryBarrier();

	updateParticle(sharedPos[localVertexIndex], oldPosition,vec4(0),color );
}