vec2 constrainMultiplier( bool fixed0 , bool fixed1){

	if( fixed0 ){

		if(fixed1)
			return vec2(0,0);
		else 
			return vec2(0,1);
	}else{

		if(fixed1)
			return vec2(1,0);
		else
			return vec2(0.5,0.5);
	}

}


vec4  applyLengthConstraintDFTL(  vec4 pos0 ,  bool fixed0,  vec4 pos1,  bool fixed1,  float targetLength, float stiffness = 1.0){

	vec3 delta = pos1.xyz - pos0.xyz; 
	float distance = max( length( delta ), 1e-7);
	float stretching  = 1.0 - targetLength / distance; 
	delta = stretching * delta; 
	vec2 multiplier = constrainMultiplier(fixed0, fixed1);

	return vec4(pos1.xyz - 1.0 * delta * stiffness,1.0);

}

void  applyLengthConstraint( inout vec4 pos0 , in bool fixed0, inout vec4 pos1, in bool fixed1,  float targetLength, float stiffness = 1.0){

	vec3 delta = pos1.xyz - pos0.xyz; 
	float distance = max( length( delta ), 1e-7);
	float stretching  = 1.0 - targetLength / distance; 
	delta = stretching * delta; 
	vec2 multiplier = constrainMultiplier(fixed0, fixed1);

	pos0.xyz += multiplier[0] * delta * stiffness;
	pos1.xyz -= multiplier[1] * delta * stiffness;

}



void calculateIndices( inout uint localVertexIndex , inout uint localStrandIndex ,
					 inout uint globalStrandIndex , inout uint vertexIndexInStrand,  uint numVerticesPerStrand, 
					 uint numStrandsPerThreadGroup    ){



	localVertexIndex = gl_LocalInvocationID.x; 
	localStrandIndex = uint(floor(gl_LocalInvocationID.x /  numVerticesPerStrand));
	globalStrandIndex = gl_WorkGroupID.x * numStrandsPerThreadGroup + localStrandIndex;
	vertexIndexInStrand = gl_LocalInvocationID.x %  numVerticesPerStrand; 



}

vec4 positionIntegration( vec4 position, vec4 velocity, vec4 force, bool fix){

	if( !fix){

		position.xyz +=   velocity.xyz * g_velocityDamping * g_timeStep  + force.xyz * g_timeStep * g_timeStep;

	}else{

		// first project it back to worldspace so rotations get handled properly
		position.xyz = (g_modelMatrixPrevInverted * vec4(position.xyz,1.0)).xyz ;
		position.xyz = (g_modelMatrix * vec4(position.xyz,1.0)).xyz ;

	}
	return position; 

}


vec4 verletIntegration(  vec4 position , vec4 previousPosition, vec4 force,  bool fix){
	//  TODO implement time correct verlet integration
	if( !fix){

		position.xyz +=   (position.xyz - previousPosition.xyz) * g_velocityDamping	  + force.xyz * g_timeStep * g_timeStep;

	}else{
		// first project it back to worldspace so rotations get handled properly
		position.xyz = (g_modelMatrixPrevInverted * vec4(position.xyz,1.0)).xyz ;
		position.xyz = (g_modelMatrix * vec4(position.xyz,1.0)).xyz ;

	}
	return position; 
}



void updateParticle( vec4 pos, vec4 prevPos, vec4 vel, vec4 color  ){


	p[gl_GlobalInvocationID.x].pos.xyz = pos.xyz;
	p[gl_GlobalInvocationID.x].prevPos.xyz = prevPos.xyz;
	p[gl_GlobalInvocationID.x].vel.xyz = vel.xyz;
	p[gl_GlobalInvocationID.x].color = color;
}


int  voxelIndex( const float x, const float y, const float z ) {

	return int(floor(x ) + floor(y ) * g_gridSize* g_gridSize  + floor(z ) *  g_gridSize);

}

int  voxelIndex( const vec4 position ) {

	// position in Voxelgrid space 
	vec4 scaledPosition = (position - vec4( g_modelTranslation.xyz, 0.0) ) / vec4((g_maxBB.xyz - g_minBB.xyz),1) + 0.5;
	scaledPosition *= g_gridSize; 
	return voxelIndex( scaledPosition.x, scaledPosition.y, scaledPosition.z);
}

vec4 getVelocity( const float x, const float y, const float z ){

	if (x < 0 || x >= g_gridSize) return vec4(0);
	if (y < 0 || y >= g_gridSize) return vec4(0); 
	if (z < 0 || z >= g_gridSize) return vec4(0); 
	
	const int index = voxelIndex(x, y, z );
	return g_voxelGrid[ index ].velocity;
	
}

vec4 getGradient( const float x, const float y, const float z ){

	if (x < 0 || x >= g_gridSize) return vec4(0);
	if (y < 0 || y >= g_gridSize) return vec4(0); 
	if (z < 0 || z >= g_gridSize) return vec4(0); 
	
	const int index = voxelIndex(x, y, z );
	return g_voxelGrid[ index ].gradient;
	
}

vec4 trilinearVelocityInterpolation( const vec4 position ){

	// position in Voxelgrid space 
	vec4 scaledPosition = (position - vec4( g_modelTranslation.xyz, 0.0) ) / vec4((g_maxBB.xyz - g_minBB.xyz),1) + 0.5;
	scaledPosition *= g_gridSize; 
	vec3 cellIndex = floor( scaledPosition.xyz  ); 
	vec3 delta = scaledPosition.xyz - cellIndex; 

	return getVelocity(cellIndex.x, cellIndex.y, cellIndex.z )  * (1.0 - delta.x) * (1.0 - delta.y ) * (1.0 - delta.z) +
	getVelocity(cellIndex.x, cellIndex.y, cellIndex.z + 1 ) * (1.0 - delta.x) * (1.0 - delta.y ) *  delta.z +
	getVelocity(cellIndex.x, cellIndex.y + 1 , cellIndex.z )  * (1.0 - delta.x) * delta.y * (1.0 - delta.z) +
	getVelocity(cellIndex.x, cellIndex.y + 1, cellIndex.z + 1 ) * (1.0 - delta.x) *  delta.y *  delta.z +
	getVelocity(cellIndex.x + 1, cellIndex.y, cellIndex.z ) * delta.x * (1.0 - delta.y ) * (1.0 - delta.z) + 
	getVelocity(cellIndex.x + 1, cellIndex.y, cellIndex.z + 1  ) * delta.x * (1.0 - delta.y ) * delta.z +
	getVelocity(cellIndex.x + 1, cellIndex.y + 1, cellIndex.z ) * delta.x * delta.y * (1.0 - delta.z) +
	getVelocity(cellIndex.x + 1, cellIndex.y + 1, cellIndex.z  + 1) *  delta.x * delta.y * delta.z;


}

vec4 trilinearGradientInterpolation( const vec4 position ){

	// position in Voxelgrid space 
	vec4 scaledPosition = (position - vec4( g_modelTranslation.xyz, 0.0) ) / vec4((g_maxBB.xyz - g_minBB.xyz),1) + 0.5;
	scaledPosition *= g_gridSize; 
	vec3 cellIndex = floor( scaledPosition.xyz  ); 
	vec3 delta = scaledPosition.xyz - cellIndex; 

	return getGradient(cellIndex.x, cellIndex.y, cellIndex.z )  * (1.0 - delta.x) * (1.0 - delta.y ) * (1.0 - delta.z) +
	getGradient(cellIndex.x, cellIndex.y, cellIndex.z + 1 ) * (1.0 - delta.x) * (1.0 - delta.y ) *  delta.z +
	getGradient(cellIndex.x, cellIndex.y + 1 , cellIndex.z )  * (1.0 - delta.x) * delta.y * (1.0 - delta.z) +
	getGradient(cellIndex.x, cellIndex.y + 1, cellIndex.z + 1 ) * (1.0 - delta.x) *  delta.y *  delta.z +
	getGradient(cellIndex.x + 1, cellIndex.y, cellIndex.z ) * delta.x * (1.0 - delta.y ) * (1.0 - delta.z) + 
	getGradient(cellIndex.x + 1, cellIndex.y, cellIndex.z + 1  ) * delta.x * (1.0 - delta.y ) * delta.z +
	getGradient(cellIndex.x + 1, cellIndex.y + 1, cellIndex.z ) * delta.x * delta.y * (1.0 - delta.z) +
	getGradient(cellIndex.x + 1, cellIndex.y + 1, cellIndex.z  + 1) *  delta.x * delta.y * delta.z;


}

vec4 calculateFrictionAndRepulsionVelocityCorrection( vec4 velocity, vec4 position){

	const vec4 interpolatedVelocity = trilinearVelocityInterpolation( position ); 
	
	//const vec4 gridVelocity = g_voxelGrid[ voxelIndex ].velocity; 
	// friction 
	velocity =  (1.0 - g_friction ) * velocity + g_friction * (interpolatedVelocity ); 

	// repulsion
	const vec4 gridGradient = trilinearGradientInterpolation(position) ;
	//velocity = velocity + g_repulsion * vec4(gridGradient.xyz,0.0)/g_timeStep; // this one for normalize gradient 
	velocity = velocity + g_repulsion * vec4(gridGradient.xyz,0.0) * g_timeStep; // this one for non normalize gradient
	return velocity; 

}