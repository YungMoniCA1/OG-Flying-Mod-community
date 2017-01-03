#include "flying_mod.as"

void UpdateAirControls(const Timestep &in ts) {
        if(!follow_jump_path){
            if(WantsToAccelerateJump()){
                // if there's fuel left and character is not moving down, height can still be increased
                if(jetpack_fuel > 0.0 && this_mo.velocity.y > 0.0) {
                    jetpack_fuel -= _jump_fuel_burn * ts.step();
                    this_mo.velocity.y += _jump_fuel_burn * ts.step();
                }
            } else {
                jetpack_fuel = 0.0f; // Don't allow releasing jump and then pressing it again
                // the character is pushed downwards to allow for smaller, controlled jumps
                if(down_jetpack_fuel > 0.0){
                    down_jetpack_fuel -= _jump_fuel_burn * ts.step();
                    this_mo.velocity.y -= _jump_fuel_burn * ts.step();
                }
            }
        }

		//FLYING MOD
		UpdateFlying(ts);	
        if(!hit_wall){
            if(WantsToFlip()){
                if(!flip_info.IsFlipping()){
                    flip_info.StartFlip();
                }
            }
        }

        if(hit_wall){
            UpdateWallRun(ts);
        }

        if(WantsToGrabLedge() && (ledge_info.on_ledge || ledge_delay <= 0.0f)){
            ledge_info.CheckLedges();
            if(ledge_info.on_ledge){
                has_hit_wall = false;
                HitWall(ledge_info.ledge_dir);
                ledge_delay = 0.3f;
                //this_mo.position.x = ledge_info.ledge_grab_pos.x;
                //this_mo.position.z = ledge_info.ledge_grab_pos.z;
            }
        }

        // if not holding a ledge, the character is airborne and can get controlled by arrow keys
        if(!ledge_info.on_ledge){
            ledge_delay -= ts.step();
            if(!follow_jump_path){
				//FLYING MOD
				SetJumpVelocity(ts);
                //vec3 target_velocity = GetTargetVelocity();
                //this_mo.velocity += target_velocity * _air_control * ts.step();
            }
        }

        jump_launch -= _jump_launch_decay * ts.step();
        jump_launch = max(0.0f, jump_launch);
    }