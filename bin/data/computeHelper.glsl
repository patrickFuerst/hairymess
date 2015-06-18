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
