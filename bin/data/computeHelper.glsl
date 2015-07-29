
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

	vec3 delta       = pos1.xyz - pos0.xyz; 
	float distance   = max( length( delta ), 1e-7);
	float stretching = 1.0 - targetLength / distance; 
	delta            = stretching * delta; 
	vec2 multiplier  = constrainMultiplier(fixed0, fixed1);

	return vec4(pos1.xyz - 1.0 * delta * stiffness,1.0);

}

void  applyLengthConstraint( inout vec4 pos0 , in bool fixed0, inout vec4 pos1, in bool fixed1,  float targetLength, float stiffness = 1.0){

	vec3 delta       = pos1.xyz - pos0.xyz; 
	float distance   = max( length( delta ), 1e-7);
	float stretching = 1.0 - targetLength / distance; 
	delta            = stretching * delta; 
	vec2 multiplier  = constrainMultiplier(fixed0, fixed1);
	
	pos0.xyz         += multiplier[0] * delta * stiffness;
	pos1.xyz         -= multiplier[1] * delta * stiffness;

}

bool calculateSphereCollision( vec4 prevPosition, vec4 position, vec4 sphere, inout vec3 collisionPoint , inout vec3 normal ){


	const vec3 spherePosition = sphere.xyz; 
	const float radius        = sphere.w;
	const vec3 collisionRay   =  position.xyz - prevPosition.xyz;
	const vec3 ppS            = spherePosition - prevPosition.xyz; // previousPosition to sphere position ray
	const vec3 pS             = spherePosition - position.xyz;
	
	// first check if the new point lies within the sphere 
	if(  length(pS) < radius  ){

		// // calculate ray->sphere collision point 

		// // project sphere position onto the collision ray 
		// const vec3 pSpherePosition = prevPosition.xyz +  dot(collisionRay , ppS ) / length(collisionRay) * collisionRay;

		// // pythagoras to get the distance from pSpherePosition to the collision point
		// float dist = sqrt( radius * radius  - pow(length( pSpherePosition - spherePosition ),2)  );
		// // calculate the final position with the previous one and  dist
		// collisionPoint = pSpherePosition -  normalize(collisionRay) * dist; 

		// normal = normalize( collisionPoint - spherePosition); 


		// not correct, easy approach
		normal = normalize( position.xyz - spherePosition); 
		collisionPoint = spherePosition + radius * normal; 

		return true; 

	}
	return false; 
}

bool calculatePlaneCollision(const vec4 prevPosition, const vec4 position, const  vec3 planePosition ,const vec3 planeNormal, inout vec3 collisionPoint  ){

	
	const vec3 ray              =  normalize(position.xyz - prevPosition.xyz);
	const float collisionFactor = dot((position.xyz - planePosition), planeNormal ); 

	// check if the new point lies behind the plane
	if(  collisionFactor < 0  ){

		// calculate line - plane intersection 

		// delta from prevPosition to position where the intesections is
		const float delta = -dot( prevPosition.xyz - planePosition, planeNormal ) / dot( ray , planeNormal ); 

		collisionPoint =  prevPosition.xyz +  delta  * ray;

		return true; 
	}
	return false; 
}

void calculateIndices( inout uint localVertexIndex , inout uint localStrandIndex ,
					 inout uint globalStrandIndex , inout uint vertexIndexInStrand,  uint numVerticesPerStrand, 
					 uint numStrandsPerThreadGroup    ){

	localVertexIndex    = gl_LocalInvocationID.x; 
	localStrandIndex    = uint(floor(gl_LocalInvocationID.x /  numVerticesPerStrand));
	globalStrandIndex   = gl_WorkGroupID.x * numStrandsPerThreadGroup + localStrandIndex;
	vertexIndexInStrand = gl_LocalInvocationID.x %  numVerticesPerStrand; 

}

vec4 positionIntegration( vec4 position, vec4 velocity, vec4 force ){

	position.xyz +=   velocity.xyz * g_velocityDamping * g_timeStep  + force.xyz * g_timeStep * g_timeStep;
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

vec3 mapPositionToGridIndex( const vec4 position, out vec3 delta ){
	
	vec4 scaledPosition = (position - g_minBB ) / (g_maxBB - g_minBB ) ;
	scaledPosition *= g_gridSize; 
	vec3 cellIndex = floor( scaledPosition.xyz ); 
	delta = scaledPosition.xyz - cellIndex; 
	return cellIndex;
}

int  voxelIndex( const float x, const float y, const float z ) {

	return int(floor(x ) + floor(y ) * g_gridSize* g_gridSize  + floor(z ) *  g_gridSize);
}
 
int  voxelIndex( const vec4 position ) {

	// position in Voxelgrid space 
	vec3 delta;
	vec3 cellIndex = mapPositionToGridIndex( position, delta); 
	return voxelIndex( cellIndex.x, cellIndex.y, cellIndex.z);
}

int  voxelIndex( const int x, const int y, const int z ) {

	return x + y  * g_gridSize* g_gridSize  + z *  g_gridSize;
}
