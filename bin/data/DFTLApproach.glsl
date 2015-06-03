
// Dynamic Follow the Leader Approach
	
subroutine(hairSimulationAlgorithm) void DFTLApproach( const uint localStrandIndex,
	const uint localVertexIndex,
	const uint globalStrandIndex,
	const uint vertexIndexInStrand, 
	const vec4 position, 
	const vec4 prevPosition,
	const vec4 velocity,
	const vec4 color,
	const vec4 force
	){

	
	const vec4 oldPosition = position;
	sharedPos[localVertexIndex]  = positionIntegration( sharedPos[localVertexIndex], velocity, force, sharedFixed[localVertexIndex]);

	memoryBarrierShared();

	if(vertexIndexInStrand  == 0){

		for(int i= 0; i < g_numVerticesPerStrand-1; i++){
			bool fix = sharedFixed[localVertexIndex+i+1];
			sharedPos[localVertexIndex+i+1] = applyLengthConstraintDFTL( sharedPos[localVertexIndex+i], true, sharedPos[localVertexIndex+i+1], fix, g_strandLength/g_numVerticesPerStrand, g_stiffness);			

		}

	}

 	groupMemoryBarrier();
 	vec4 distanceToNext = vec4(0,0,0,0);
	if(vertexIndexInStrand < g_numVerticesPerStrand-1){
		distanceToNext.xyz = sharedPos[localVertexIndex].xyz - sharedPos[localVertexIndex+1].xyz ;
	}
	vec4 derivedVelocity = vec4((sharedPos[localVertexIndex].xyz - oldPosition.xyz) / g_timeStep - g_ftlDamping *distanceToNext.xyz / g_timeStep,0.0); 

	//memoryBarrierShared();

	updateParticle(sharedPos[gl_LocalInvocationID.x], oldPosition,derivedVelocity,color );
}