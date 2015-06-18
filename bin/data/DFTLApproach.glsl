
// Dynamic Follow the Leader Approach
	
subroutine(hairSimulationAlgorithm) void DFTLApproach( const uint localStrandIndex,
	const uint localVertexIndex,
	const uint globalStrandIndex,
	const uint vertexIndexInStrand, 
	const vec4 position, 
	const vec4 prevPosition,
	const vec4 velocity,
	const vec4 color,
	const vec4 force,
	const float mass
	){

	
	const vec4 oldPosition = position;

	// calculate the velocity according to the ftl approach 
	// first approach was to calculate it at the end and add it to the newVelocity. But this results to that this "guiding" velocity appears in the voxel grid and distorts the all other calculation
	vec4 distanceToNext = vec4(0,0,0,0);
	if(vertexIndexInStrand < g_numVerticesPerStrand-1){
		distanceToNext.xyz = sharedPos[localVertexIndex].xyz - sharedPos[localVertexIndex+1].xyz ;
	}
	vec4 derivedVelocity = velocity - g_ftlDamping *distanceToNext / g_timeStep; 


	// explicit euler integration 
	sharedPos[localVertexIndex]  = positionIntegration( sharedPos[localVertexIndex], derivedVelocity, force, mass, sharedFixed[localVertexIndex]);

	memoryBarrierShared();
 	groupMemoryBarrier();

 	// apply length constraint
	if(vertexIndexInStrand  == 0){

		for(int i= 0; i < g_numVerticesPerStrand-1; i++){
			bool fix = sharedFixed[localVertexIndex+i+1];
			float mass = sharedMass[localVertexIndex+i+1];
			sharedPos[localVertexIndex+i+1] = applyLengthConstraintDFTL( sharedPos[localVertexIndex+i], true, sharedPos[localVertexIndex+i+1], fix, mass, g_strandLength/g_numVerticesPerStrand, g_stiffness);			

		}

	}

 	groupMemoryBarrier();

	vec4 newVelocity = vec4((sharedPos[localVertexIndex].xyz - oldPosition.xyz) / g_timeStep ,0.0); 

	updateParticle(sharedPos[gl_LocalInvocationID.x], oldPosition,newVelocity,color );
}