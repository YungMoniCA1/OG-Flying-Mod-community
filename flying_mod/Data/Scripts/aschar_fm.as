#include "aircontrols_fm.as"

void UpdateEyeLookTarget() {
    if(tethered == _TETHERED_REARCHOKED){
        // Look around randomly if being choked
        if(time >= choke_look_time){
            vec3 dir = vec3(RangedRandomFloat(-1.0f, 1.0f),
                            RangedRandomFloat(-0.2f, 0.2f),
                            RangedRandomFloat(-1.0f, 1.0f));
            eye_look_target = this_mo.position + dir * 100.0f;
            choke_look_time = time + RangedRandomFloat(0.1f,0.3f);
        }
    } else if(trying_to_get_weapon != 0){
        // Look at weapon if trying to get it
        eye_look_target = get_weapon_pos;
    } else {
        // Look at throw target
        if(throw_knife_layer_id != -1 && target_id != -1){
            force_look_target_id = target_id;
        }
        if(force_look_target_id != -1){
            vec3 target_pos = ReadCharacterID(force_look_target_id).rigged_object().GetAvgIKChainPos("head");
            eye_look_target = target_pos;
        } else if(this_mo.controlled){
            vec3 dir_flat = camera.GetFacing();
            eye_look_target = this_mo.position + camera.GetFacing() * 100.0f;
			//FLYING MOD - disable head looking away from camera in air
			/*
            if(!on_ground){
                target_head_dir = mix(target_head_dir, this_mo.GetFacing(), 0.5f);
            }
			*/
            target_head_dir = normalize(target_head_dir);
            look_inertia = 0.8f;
        } else {
            if(look_target.type == _none){
                eye_look_target = random_look_target;
            } else if(look_target.type == _character){
                vec3 target_pos = ReadCharacterID(look_target.id).rigged_object().GetAvgIKChainPos("head");
                eye_look_target = target_pos;
            }
        }
    }
			//FLYING MOD - disable head looking away from camera in air
			/*
            if(!on_ground){
                target_head_dir = mix(target_head_dir, this_mo.GetFacing(), 0.5f);
            }
			*/
    }

void HandleAirCollisions(const Timestep &in ts) {
    vec3 initial_vel = this_mo.velocity;
    vec3 offset = this_mo.position - last_col_pos; 
    this_mo.position = last_col_pos;
    bool landing = false;
    vec3 landing_normal;
    vec3 old_vel = this_mo.velocity;
    for(int i=0; i<ts.frames(); ++i){                                        // Divide movement into multiple pieces to help prevent surface penetration
        if(on_ground){
            break;
        }
        this_mo.position += offset/ts.frames();
        vec3 col_offset;
        vec3 col_scale;
        float size;
        GetCollisionSphere(col_offset, col_scale, size);
        col.GetSlidingScaledSphereCollision(this_mo.position+col_offset, _leg_sphere_size, col_scale);
        if(_draw_collision_spheres){
            DebugDrawWireScaledSphere(this_mo.position+col_offset, _leg_sphere_size, col_scale, vec3(0.0f,1.0f,0.0f), _delete_on_update);
        }
        this_mo.position = sphere_col.adjusted_position-col_offset;         // Collide like a sliding sphere with verlet-integrated velocity response
        vec3 adjustment = (this_mo.position - (sphere_col.position-col_offset));
        adjustment.y = min(0.0f,adjustment.y);
        this_mo.velocity += adjustment / (ts.step());
        offset += (sphere_col.adjusted_position - sphere_col.position) * ts.frames();
        vec3 closest_point;
        float closest_dist = -1.0f;
        for(int j=0; j<sphere_col.NumContacts(); j++){
            const CollisionPoint contact = sphere_col.GetContact(j);
            if(contact.normal.y < _ground_normal_y_threshold){              // If collision with a surface that can't be walked on, check for wallrun
                float dist = distance_squared(contact.position, this_mo.position);
                if(closest_dist == -1.0f || dist < closest_dist){
                    closest_dist = dist;
                    closest_point = contact.position;
                }
            }
        }    
        if(closest_dist != -1.0f){
            jump_info.HitWall(normalize(closest_point-this_mo.position));
        }
        for(int j=0; j<sphere_col.NumContacts(); j++){
            if(landing){
                break;
            }
            const CollisionPoint contact = sphere_col.GetContact(j);
            if(contact.normal.y > _ground_normal_y_threshold ||
               (this_mo.velocity.y < 0.0f && contact.normal.y > 0.2f))
            {                                                               // If collision with a surface that can be walked on, then land
                if(air_time > 0.1f){
                    landing = true;
                    landing_normal = contact.normal;
                }
            }
        }
    }
    if(landing){
		//FLYING MOD - bounce if air dash
		if(air_dash > 0) {this_mo.velocity.y *=-1.0f; return;}
        CheckForVelocityShock(old_vel.y);                                   // Check landing damage from high-speed falls
        if(knocked_out == _awake){                                          // If still conscious, land properly
            ground_normal = landing_normal;
            Land(initial_vel, ts);
            if(state != _ragdoll_state){
                SetState(_movement_state);
            }
        }
    }
    if(this_mo.velocity.y < 0.0f && old_vel.y >= 0.0f){
        this_mo.velocity.y = 0.0f;
    }
    
    
}