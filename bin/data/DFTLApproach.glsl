
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
	const float strandLength = sharedLength[localStrandIndex]; 

	// calculate the velocity according to the ftl approach 
	// first approach was to calculate it at the end and add it to the newVelocity. But this results to that this "guiding" velocity appears in the voxel grid and distorts the all other calculations
	vec4 distanceToNext = vec4(0,0,0,0);
	if(vertexIndexInStrand < g_numVerticesPerStrand-1){
		distanceToNext.xyz = sharedPos[localVertexIndex].xyz - sharedPos[localVertexIndex+1].xyz ;
	}
	vec4 derivedVelocity = velocity - g_ftlDamping *distanceToNext / g_timeStep; 


	// explicit euler integration 
	sharedPos[localVertexIndex]  = positionIntegration( sharedPos[localVertexIndex], derivedVelocity, force, sharedFixed[localVertexIndex]);

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

	vec4 newVelocity = vec4((sharedPos[localVertexIndex].xyz - oldPosition.xyz) / g_timeStep ,0.0); 
	

	vec4 sphere = vec4(0,0,0,4) + g_modelTranslation;
	vec3 collisionPoint, normal; 
	if( calculateSphereCollision( oldPosition, sharedPos[localVertexIndex] , sphere , collisionPoint, normal ) ){

		// bounce particle on surface of sphere 

		vec3 u = dot(newVelocity.xyz , normal ) * normal; 
		vec3 w = velocity.xyz - u; 
		newVelocity.xyz = w - u; 
		sharedPos[localVertexIndex].xyz = collisionPoint;

	}

	vec3 planePosition = vec3(0,0,0);
	vec3 planeNormal = vec3(0,1,0);
	
	if( calculatePlaneCollision( oldPosition, sharedPos[localVertexIndex] ,  planePosition, planeNormal, collisionPoint ) ){

		// bounce particle on surface of sphere 

		vec3 u = dot(newVelocity.xyz , planeNormal ) * planeNormal; 
		vec3 w = velocity.xyz - u; 
		newVelocity.xyz = w -  u; 
		sharedPos[localVertexIndex].xyz = collisionPoint;

	}


	newVelocity = calculateFrictionAndRepulsionVelocityCorrection( newVelocity, sharedPos[localVertexIndex] );

	updateParticle(sharedPos[gl_LocalInvocationID.x], oldPosition,newVelocity,color );
}