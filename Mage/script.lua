local tick_tween = require("tickTween")

local ITEM_FRONT_OFFSET = 10
local ITEM_SIDE_OFFSET = 11
local ITEM_UP_OFFSET = 2
local ITEM_STIFFNESS = 0.3
local ITEM_DAMPING = 0.4
local ITEM_SPEED_HELP = 0.6
local ITEM_BOB_INTENSITY = 2
local ITEM_BOB_ROTATION_INTENSITY = 5
local ITEM_BOB_SPEED = 0.13
local ITEM_USE_DISTANCE = 4
local ITEM_USE_HEIGHT_OFFSET = 1
local ITEM_THRUST_DURATION = 6
local ITEM_THRUST_BELND_START = 4
local ITEM_SPAWN_DOWN_OFFSET = 10
local VANILLA_WALK_SPEED = 0.21585
local WALK_ANIM_BASE_SPEED = 2
local VANILLA_WALK_SPEED_SNEAKING = 0.06475
local WALK_ANIM_BASE_SPEED_SNEAKING = 0.7
local VANILLA_WALK_SPEED_CRAWLING = 0.06475
local WALK_ANIM_BASE_SPEED_CRAWLING = 0.5
local VIEWMODEL_SCALE = 0.06
local FIRST_PERSON_ITEM_POS = vec(250, 0, 20)
local FIRST_PERSON_ITEM_SCALE = 10
local VIEWMODEL_STIFFNESS = 0.4
local VIEWMODEL_DAMPING = 0.5
local VIEWMODEL_BOB_INTENSITY = 10
local PRESPECTIVE_ROTATION = 1.5
local VIEWMODEL_USE_DIST_MULTIPLIER = 2
local VIEWMODEL_SPAWN_DOWN_OFFSET = 40
local VIEWMODEL_LAG = 0.001
local VIEWMODEL_POS_LAG = 150
local VIEWMODEL_POS_LAG_Z = 0.1
local VIEWMODEL_ARM_LAG = 0.015
local VIEWMODEL_ARM_POS_LAG = 3
local VIEWMODEL_ARM_STIFFNESS = 1.5

local world_part = models.model.World
local left_item_part = world_part.CustomLeftItem
local right_item_part = world_part.CustomRightItem
local left_item_pivot = left_item_part.PivotItemLeft
local right_item_pivot = right_item_part.PivotItemRight
local left_item_parent = left_item_pivot.OffsetItemLeft
local right_item_parent = right_item_pivot.OffsetItemRight
local root = models.model.root
local head = root.CustomHead
local gui = models.model.GUI
local viewmodel = gui.Viewmodel
local viewmodel_left_item_part = viewmodel.ViewmodelCustomLeftItem
local viewmodel_right_item_part = viewmodel.ViewmodelCustomRightItem
local viewmodel_left_item_rot = viewmodel_left_item_part.ViewmodelRotItemLeft
local viewmodel_right_item_rot = viewmodel_right_item_part.ViewmodelRotItemRight
local viewmodel_left_item_pivot = viewmodel_left_item_rot.ViewmodelPivotItemLeft
local viewmodel_right_item_pivot = viewmodel_right_item_rot.ViewmodelPivotItemRight
local viewmodel_left_item_parent = viewmodel_left_item_pivot.ViewmodelOffsetItemLeft
local viewmodel_right_item_parent = viewmodel_right_item_pivot.ViewmodelOffsetItemRight
local viewmodel_arms = viewmodel.ViewmodelArmsRoot

local always_playing_anims = {
	"stand",
	"walk_forward",
	"walk_forward_left_arm",
	"walk_forward_right_arm",
	"walk_back",
	"walk_back_left_arm",
	"walk_back_right_arm",
	"hold_item_left",
	"hold_item_right",
	"thrust_item_left",
	"thrust_item_right",
	"charge_item_left",
	"charge_item_right",
	"use_on_self_left",
	"use_on_self_right",
	"air_forward",
	"air_forward_left_arm",
	"air_forward_right_arm",
	"air_back",
	"air_back_left_arm",
	"air_back_right_arm",
	"sneak",
	"sneak_forward",
	"sneak_back",
	"sneak_left_arm",
	"sneak_right_arm",
	"sit",
	"sit_left_arm",
	"sit_right_arm",
	"elytra",
	"sleep",
	"swim",
	"crawl",
	"crawl_forward",
	"crawl_back",
	"spin_attack",
}

if host:isHost() then
	always_playing_anims[#always_playing_anims + 1] = "viewmodel_hold_left"
	always_playing_anims[#always_playing_anims + 1] = "viewmodel_hold_right"
	always_playing_anims[#always_playing_anims + 1] = "viewmodel_thrust_left"
	always_playing_anims[#always_playing_anims + 1] = "viewmodel_thrust_right"
	always_playing_anims[#always_playing_anims + 1] = "viewmodel_self_use_left"
	always_playing_anims[#always_playing_anims + 1] = "viewmodel_self_use_right"
	always_playing_anims[#always_playing_anims + 1] = "viewmodel_charge_left"
	always_playing_anims[#always_playing_anims + 1] = "viewmodel_charge_right"
end

local walk_anims = {
	"walk_forward",
	"walk_forward_left_arm",
	"walk_forward_right_arm",
	"walk_back",
	"walk_back_left_arm",
	"walk_back_right_arm",
	"sneak_forward",
	"sneak_back",
	"crawl_forward",
	"crawl_back",
}

local item_id_rotations = {
	["minecraft:fishing_rod"] = vec(55, 0, 0),
	["minecraft:carrot_on_a_stick"] = vec(55, 0, 0),
	["minecraft:trident"] = vec(90, 0, 0),
	["minecraft:spyglass"] = vec(-90, 0, 0),
}

local item_tag_rotations = {
	["minecraft:swords"] = vec(80, 0, 0),
	["minecraft:shovels"] = vec(80, 0, 0),
}

local use_actions = {
	EAT = {
		front = 8,
		side = 0,
		up = -6,
		rot = vec(-45, 0, 0),
		viewmodel_pos = vec(0, -90, 10),
		anim = "use_on_self",
		thrust = false,
	},
	DRINK = {
		front = 8,
		side = 0,
		up = -6,
		rot = vec(-45, 0, 0),
		viewmodel_pos = vec(0, -90, 10),
		anim = "use_on_self",
		thrust = false,
	},
	BLOCK = {
		front = ITEM_FRONT_OFFSET,
		side = 2,
		up = -13,
		rot = vec(0, 90, 0),
		viewmodel_pos = vec(50, -150, 20),
		anim = "use_on_self",
		thrust = false,
	},
	BOW = {
		front = ITEM_FRONT_OFFSET,
		side = ITEM_SIDE_OFFSET,
		up = ITEM_UP_OFFSET,
		anim = "charge",
		thrust = true,
	},
	SPEAR = {
		front = -10,
		side = ITEM_SIDE_OFFSET,
		up = 8,
		viewmodel_pos = vec(250, 0, 10),
		anim = "charge",
		thrust = true,
	},
	CROSSBOW = {
		front = ITEM_FRONT_OFFSET,
		side = ITEM_SIDE_OFFSET,
		up = ITEM_UP_OFFSET,
		anim = "charge",
		thrust = false,
	},
	SPYGLASS = {
		front = 8,
		side = 2,
		up = -1,
		anim = "use_on_self",
		viewmodel_pos = vec(20, 0, 5),
		thrust = false,
	},
	TOOT_HORN = {
		front = 7,
		side = 0,
		up = -6,
		rot = vec(0, 90, 0),
		viewmodel_pos = vec(0, -100, 15),
		anim = "use_on_self",
		thrust = false,
	},
}

local left_item_task
local right_item_task

local viewmodel_left_item_task
local viewmodel_right_item_task

local current_left_item
local current_right_item

local left_item_speed = vec(0, 0, 0)
local right_item_speed = vec(0, 0, 0)
local left_item_prev_desired_pos
local right_item_prev_desired_pos

local viewmodel_left_item_speed = vec(0, 0, 0)
local viewmodel_right_item_speed = vec(0, 0, 0)

local viewmodel_left_pos_3d = vec(0, 0, 0)
local viewmodel_right_pos_3d = vec(0, 0, 0)

local item_bob_progress = 0

local hold_item_left_blend
local hold_item_right_blend
local thrust_item_left_time_left = 0
local thrust_item_right_time_left = 0

local left_item_rot_override_action = "NONE"
local right_item_rot_override_action = "NONE"

local prev_player_rot
local prev_player_velocity = vec(0, 0, 0)

vanilla_model.ALL:setVisible(false)
viewmodel:setVisible(false)

for i, anim_name in ipairs(always_playing_anims) do
	local anim = animations.model[anim_name]
	anim:play()
	anim:blend(0)
	local function set_blend(blend)
		anim:blend(blend)
	end
	tick_tween:createValue(anim_name .. "_anim_blend", 0.0, set_blend)
end

local function degSin(x)
	return math.sin(math.rad(x))
end

local function degCos(x)
	return math.cos(math.rad(x))
end

local function itemEquals(a, b)
	if a == nil or b == nil then
		return false
	end
	if a.id ~= b.id then
		return false
	end
	return true
end

local function get_active_hand()
	if not player:isUsingItem() then
		return nil
	end
	local main_hand = player:getActiveHand() == "MAIN_HAND"
	return main_hand == player:isLeftHanded()
end

local function get_item_desired_pos(left)
	local offsets = nil
	if get_active_hand() == left then
		offsets = use_actions[player:getActiveItem():getUseAction()]
	end
	if offsets == nil then
		offsets = {
			front = ITEM_FRONT_OFFSET,
			side = ITEM_SIDE_OFFSET,
			up = ITEM_UP_OFFSET,
		}
	end
	local rot = player:getBodyYaw()
	local front = vec(degSin(-rot), 0, degCos(-rot)) * offsets.front
	local side = vec(-degCos(-rot), 0, degSin(-rot)) * offsets.side
	if left then
		side = side * -1
	end
	local up = vec(0, player:getEyeHeight() * 16 + offsets.up, 0)
	return player:getPos() * 16 + front + side + up
end

local function get_item_rotation(item_stack)
	if item_stack:isBlockItem() then
		return vec(45, 0, 0)
	end
	local id = item_stack.id
	local id_rot = item_id_rotations[id]
	if id_rot ~= nil then
		return id_rot
	end
	for i, tag in ipairs(item_stack:getTags()) do
		local tag_rot = item_tag_rotations[tag]
		if tag_rot ~= nil then
			return tag_rot
		end
	end
	return vec(0, 0, 0)
end

local function held_item_changed(item_stack, left)
	local item_part
	local item_pivot
	local viewmodel_item_part
	local viewmodel_item_pivot
	local viewmodel_pos_3d
	if left then
		item_part = left_item_part
		item_pivot = left_item_pivot
		viewmodel_item_part = viewmodel_left_item_part
		viewmodel_item_pivot = viewmodel_left_item_pivot
		viewmodel_pos_3d = viewmodel_left_pos_3d
	else
		item_part = right_item_part
		item_pivot = right_item_pivot
		viewmodel_item_part = viewmodel_right_item_part
		viewmodel_item_pivot = viewmodel_right_item_pivot
		viewmodel_pos_3d = viewmodel_right_pos_3d
	end
	local rot = get_item_rotation(item_stack)
	item_pivot:setRot(rot)
	tick_tween:setPartPos(item_part, get_item_desired_pos(left) + vec(0, -ITEM_SPAWN_DOWN_OFFSET, 0))
	tick_tween:teleportPart(item_part)
	if host:isHost() then
		viewmodel_item_pivot:setRot(rot)
		local first_person_item_pos
		if left then
			first_person_item_pos = FIRST_PERSON_ITEM_POS
		else
			first_person_item_pos = FIRST_PERSON_ITEM_POS * vec(-1, 1, 1)
		end
		first_person_item_pos = first_person_item_pos + vec(0, -VIEWMODEL_SPAWN_DOWN_OFFSET, 0)
		viewmodel_pos_3d:set(first_person_item_pos)
		tick_tween:teleportPart(viewmodel_item_part)
	end
	local hold_item_blend
	if item_stack.id == "minecraft:air" then
		hold_item_blend = 0
	else
		hold_item_blend = 1
	end
	if left then
		current_left_item = item_stack
		hold_item_left_blend = hold_item_blend
		left_item_speed = player:getVelocity() * 16
	else
		current_right_item = item_stack
		hold_item_right_blend = hold_item_blend
		right_item_speed = player:getVelocity() * 16
	end
end

local function thrust_item(left)
	if left then
		thrust_item_left_time_left = ITEM_THRUST_DURATION
	else
		thrust_item_right_time_left = ITEM_THRUST_DURATION
	end
end

local function init_item(left)
	local desired_pos = get_item_desired_pos(left)
	if left then
		left_item_prev_desired_pos = desired_pos
		left_item_task = left_item_parent:newItem("left_item")
		left_item_task:setDisplayMode("THIRD_PERSON_LEFT_HAND")
		if host:isHost() then
			viewmodel_left_item_part:setScale(vec(FIRST_PERSON_ITEM_SCALE, FIRST_PERSON_ITEM_SCALE, FIRST_PERSON_ITEM_SCALE))
			viewmodel_left_item_task = viewmodel_left_item_parent:newItem("viewmodel_left_item")
			viewmodel_left_item_task:setDisplayMode("THIRD_PERSON_LEFT_HAND")
		end
	else
		right_item_prev_desired_pos = desired_pos
		right_item_task = right_item_parent:newItem("right_item")
		right_item_task:setDisplayMode("THIRD_PERSON_RIGHT_HAND")
		if host:isHost() then
			viewmodel_right_item_part:setScale(vec(FIRST_PERSON_ITEM_SCALE, FIRST_PERSON_ITEM_SCALE, FIRST_PERSON_ITEM_SCALE))
			viewmodel_right_item_task = viewmodel_right_item_parent:newItem("viewmodel_right_item")
			viewmodel_right_item_task:setDisplayMode("THIRD_PERSON_RIGHT_HAND")
		end
	end
end

local function tick_item(left)
	local part
	local speed
	local prev_desired_pos
	local rot_override_action
	local viewmodel_item_pivot
	if left then
		part = left_item_part
		speed = left_item_speed
		prev_desired_pos = left_item_prev_desired_pos
		rot_override_action = left_item_rot_override_action
		viewmodel_item_pivot = viewmodel_left_item_pivot
	else
		part = right_item_part
		speed = right_item_speed
		prev_desired_pos = right_item_prev_desired_pos
		rot_override_action = right_item_rot_override_action
		viewmodel_item_pivot = viewmodel_right_item_pivot
	end
	local current_rot_override_action = "NONE"
	if get_active_hand() == left then
		current_rot_override_action = player:getActiveItem():getUseAction()
	end
	if current_rot_override_action ~= rot_override_action then
		local rotation_offset = vec(0, 0, 0)
		local use_action_data = use_actions[current_rot_override_action]
		if use_action_data ~= nil then
			local possible_rot_offset = use_action_data.rot
			if possible_rot_offset ~= nil then
				rotation_offset = possible_rot_offset
				if left then
					rotation_offset = rotation_offset * vec(1, -1, 1)
				end
			end
		end
		local item_pivot
		if left then
			item_pivot = left_item_pivot
		else
			item_pivot = right_item_pivot
		end
		local rot = get_item_rotation(player:getHeldItem(player:isLeftHanded() ~= left)) + rotation_offset
		tick_tween:setPartRot(item_pivot, rot)
		if host:isHost() then
			tick_tween:setPartRot(viewmodel_item_pivot, rot)
		end
		local action_data = use_actions[rot_override_action]
		if action_data ~= nil then
			if action_data.thrust then
				thrust_item(left)
			end
		end
		rot_override_action = current_rot_override_action
	end
	local bob_progress = item_bob_progress
	if left then
		bob_progress = bob_progress + math.pi / 2
	end
	local desired_pos = (
		get_item_desired_pos(left)
		+ vec(0, math.sin(bob_progress) * ITEM_BOB_INTENSITY, 0)
	)
	local desired_speed = desired_pos - prev_desired_pos
	local part_pos = tick_tween:getPartPos(part)
	speed:add((desired_pos - part_pos) * ITEM_STIFFNESS)
	speed:set(math.lerp(speed, desired_speed * ITEM_SPEED_HELP, ITEM_DAMPING))
	tick_tween:setPartPos(part, part_pos + speed)
	tick_tween:setPartRot(part, vec(
		math.sin(bob_progress + math.pi / 2) * ITEM_BOB_ROTATION_INTENSITY,
		-player:getBodyYaw(),
		0
	))
	prev_desired_pos:set(desired_pos)
	if left then
		left_item_rot_override_action = rot_override_action
	else
		right_item_rot_override_action = rot_override_action
	end
end

local function tick_viewmodel(left)
	local pos_3d
	local part
	local rot_part
	local speed
	if left then
		pos_3d = viewmodel_left_pos_3d
		part = viewmodel_left_item_part
		rot_part = viewmodel_left_item_rot
		speed = viewmodel_left_item_speed
	else
		pos_3d = viewmodel_right_pos_3d
		part = viewmodel_right_item_part
		rot_part = viewmodel_right_item_rot
		speed = viewmodel_right_item_speed
	end
	local bob_progress = item_bob_progress
	if left then
		bob_progress = bob_progress + math.pi / 2
	end
	local item_pos = FIRST_PERSON_ITEM_POS
	if get_active_hand() == left then
		local use_action_data = use_actions[player:getActiveItem():getUseAction()]
		if use_action_data ~= nil then
			local pos_override = use_action_data.viewmodel_pos
			if pos_override ~= nil then
				item_pos = pos_override
			end
		end
	end
	if not left then
		item_pos = item_pos * vec(-1, 1, 1)
	end
	local desired_pos = (
		item_pos
		+ vec(0, math.sin(bob_progress) * VIEWMODEL_BOB_INTENSITY, 0)
	)
	speed:add((desired_pos - pos_3d) * VIEWMODEL_STIFFNESS)
	speed:set(speed * (1.0 - VIEWMODEL_DAMPING))
	pos_3d:add(speed)
	tick_tween:setPartPos(part, part_pos)
	tick_tween:setPartRot(rot_part, vec(math.sin(bob_progress + math.pi / 2) * ITEM_BOB_ROTATION_INTENSITY, 0, 0))
	if pos_3d.z > 0.01 then
		tick_tween:setPartPos(part, vec(pos_3d.x / pos_3d.z, pos_3d.y / pos_3d.z, pos_3d.z))
		tick_tween:setPartScale(part, FIRST_PERSON_ITEM_SCALE / pos_3d.z)
		local rot = vec(pos_3d.y, -pos_3d.x, 0)
		rot = rot * PRESPECTIVE_ROTATION
		rot = rot / pos_3d.z
		tick_tween:setPartRot(part, rot)
	end
end

local function render_item(left)
	if not world:exists() then
		return
	end
	local item_part
	if left then
		item_part = left_item_part
	else
		item_part = right_item_part
	end
	if item_part == nil then
		return
	end
	local pos = item_part:getPos() / 16
	local blockLight = world.getBlockLightLevel(pos)
	local skyLight = world.getSkyLightLevel(pos)
	item_part:setLight(blockLight, skyLight)
end

local function set_walk_animation_speed(speed)
	for i, animation_name in ipairs(walk_anims) do
		animations.model[animation_name]:setSpeed(speed)
	end
end

local function tick_animations()
	local left_arm_anim = "none"
	local right_arm_anim = "none"
	local active_item = player:getActiveItem()
	if active_item.id ~= "minecraft:air" then
		local item_action_data = use_actions[active_item:getUseAction()]
		if item_action_data ~= nil then
			if get_active_hand() then
				left_arm_anim = item_action_data.anim
			else
				right_arm_anim = item_action_data.anim
			end
		end
	end
	local thrust_item_left = 0
	if thrust_item_left_time_left > 0 then
		if thrust_item_left_time_left > ITEM_THRUST_BELND_START then
			thrust_item_left = 1
		else
			thrust_item_left = thrust_item_left_time_left / ITEM_THRUST_BELND_START
		end
		thrust_item_left_time_left = thrust_item_left_time_left - 1
	end
	local charge_item_left = 0
	local self_use_item_left = 0
	if left_arm_anim == "charge" then
		charge_item_left = 1 - thrust_item_left
	elseif left_arm_anim == "use_on_self" then
		self_use_item_left = 1 - thrust_item_left
	end
	local hold_item_left = hold_item_left_blend * (1 - (thrust_item_left + charge_item_left + self_use_item_left))
	local empty_hand_left = 1 - (thrust_item_left + hold_item_left + charge_item_left + self_use_item_left)
	local thrust_item_right = 0
	if thrust_item_right_time_left > 0 then
		if thrust_item_right_time_left > ITEM_THRUST_BELND_START then
			thrust_item_right = 1
		else
			thrust_item_right = thrust_item_right_time_left / ITEM_THRUST_BELND_START
		end
		thrust_item_right_time_left = thrust_item_right_time_left - 1
	end
	local charge_item_right = 0
	local self_use_item_right = 0
	if right_arm_anim == "charge" then
		charge_item_right = 1 - thrust_item_right
	elseif right_arm_anim == "use_on_self" then
		self_use_item_right = 1 - thrust_item_right
	end
	local hold_item_right = hold_item_right_blend * (1 - (thrust_item_right + charge_item_right + self_use_item_right))
	local empty_hand_right = 1 - (thrust_item_right + hold_item_right + charge_item_right + self_use_item_right)
	local standard_pose = 1
	local elytra_gliding = 0
	local sleeping = 0
	local swimming = 0
	local crawling = 0
	local spin_attacking = 0
	local not_crouching = 1
	local crouching = 0
	local pose = player:getPose()
	if pose == "FALL_FLYING" then
		standard_pose = 0
		elytra_gliding = 1
	elseif pose == "SLEEPING" then
		standard_pose = 0
		sleeping = 1
	elseif player:riptideSpinning() then
		standard_pose = 0
		spin_attacking = 1
	elseif pose == "SWIMMING" then
		standard_pose = 0
		if player:isInWater() then
			swimming = 1
		else
			crawling = 1
		end
	elseif pose == "CROUCHING" then
		not_crouching = 0
		crouching = 1
	end
	local ground
	local air
	if player:isOnGround() then
		ground = 1
		air = 0
	else
		ground = 0
		air = 1
	end
	local not_sitting
	local sitting
	if player:getVehicle() == nil then
		not_sitting = 1
		sitting = 0
	else
		not_sitting = 0
		sitting = 1
	end
	local velocity = player:getVelocity()
	local velocity_flat = vec(velocity.x, velocity.z)
	local speed = velocity_flat:length()
	local walk_speed
	local base_speed
	if crawling == 1 then
		walk_speed = VANILLA_WALK_SPEED_CRAWLING
		base_speed = WALK_ANIM_BASE_SPEED_CRAWLING
	elseif crouching == 1 then
		walk_speed = VANILLA_WALK_SPEED_SNEAKING
		base_speed = WALK_ANIM_BASE_SPEED_SNEAKING
	else
		walk_speed = VANILLA_WALK_SPEED
		base_speed = WALK_ANIM_BASE_SPEED
	end
	if speed > walk_speed then
		set_walk_animation_speed(speed * base_speed / walk_speed)
	else
		set_walk_animation_speed(base_speed)
	end
	local moving = math.min(speed / walk_speed, 1)
	local stopped = 1 - moving
	local rot = player:getRot().y
	local front = vec(degSin(-rot), degCos(-rot))
	local forward
	local back
	if front:dot(velocity_flat:normalized()) < -0.1 then
		forward = 0
		back = 1
	else
		forward = 1
		back = 0
	end
	local air_forward = math.lerp(0.5, forward, moving)
	local air_back = 1 - air_forward
	tick_tween:setValue(
		"hold_item_left_anim_blend",
		standard_pose * hold_item_left
	)
	tick_tween:setValue(
		"hold_item_right_anim_blend",
		standard_pose * hold_item_right
	)
	tick_tween:setValue(
		"thrust_item_left_anim_blend",
		standard_pose * thrust_item_left
	)
	tick_tween:setValue(
		"thrust_item_right_anim_blend",
		standard_pose * thrust_item_right
	)
	tick_tween:setValue(
		"charge_item_left_anim_blend",
		standard_pose * charge_item_left
	)
	tick_tween:setValue(
		"charge_item_right_anim_blend",
		standard_pose * charge_item_right
	)
	tick_tween:setValue(
		"use_on_self_left_anim_blend",
		standard_pose * self_use_item_left
	)
	tick_tween:setValue(
		"use_on_self_right_anim_blend",
		standard_pose * self_use_item_right
	)
	tick_tween:setValue(
		"stand_anim_blend",
		standard_pose * not_sitting * not_crouching * ground * stopped
	)
	tick_tween:setValue(
		"walk_forward_anim_blend",
		standard_pose * not_sitting * not_crouching * ground * moving * forward
	)
	tick_tween:setValue(
		"walk_forward_left_arm_anim_blend",
		standard_pose * not_sitting * not_crouching * ground * moving * forward * empty_hand_left
	)
	tick_tween:setValue(
		"walk_forward_right_arm_anim_blend",
		standard_pose * not_sitting * not_crouching * ground * moving * forward * empty_hand_right
	)
	tick_tween:setValue(
		"walk_back_anim_blend",
		standard_pose * not_sitting * not_crouching * ground * moving * back
	)
	tick_tween:setValue(
		"walk_back_left_arm_anim_blend",
		standard_pose * not_sitting * not_crouching * ground * moving * back * empty_hand_left
	)
	tick_tween:setValue(
		"walk_back_right_arm_anim_blend",
		standard_pose * not_sitting * not_crouching * ground * moving * back * empty_hand_right
	)
	tick_tween:setValue(
		"air_forward_anim_blend",
		standard_pose * not_sitting * not_crouching * air * air_forward
	)
	tick_tween:setValue(
		"air_forward_left_arm_anim_blend",
		standard_pose * not_sitting * not_crouching * air * air_forward * empty_hand_left
	)
	tick_tween:setValue(
		"air_forward_right_arm_anim_blend",
		standard_pose * not_sitting * not_crouching * air * air_forward * empty_hand_right
	)
	tick_tween:setValue(
		"air_back_anim_blend",
		standard_pose * not_sitting * not_crouching * air * air_back
	)
	tick_tween:setValue(
		"air_back_left_arm_anim_blend",
		standard_pose * not_sitting * not_crouching * air * air_back * empty_hand_left
	)
	tick_tween:setValue(
		"air_back_right_arm_anim_blend",
		standard_pose * not_sitting * not_crouching * air * air_back * empty_hand_right
	)
	tick_tween:setValue(
		"sneak_anim_blend",
		standard_pose * not_sitting * crouching * stopped
	)
	tick_tween:setValue(
		"sneak_forward_anim_blend",
		standard_pose * not_sitting * crouching * moving * forward
	)
	tick_tween:setValue(
		"sneak_back_anim_blend",
		standard_pose * not_sitting * crouching * moving * back
	)
	tick_tween:setValue(
		"sneak_left_arm_anim_blend",
		standard_pose * not_sitting * crouching * empty_hand_left
	)
	tick_tween:setValue(
		"sneak_right_arm_anim_blend",
		standard_pose * not_sitting * crouching * empty_hand_right
	)
	tick_tween:setValue(
		"sit_anim_blend",
		standard_pose * sitting
	)
	tick_tween:setValue(
		"sit_left_arm_anim_blend",
		standard_pose * sitting * empty_hand_left
	)
	tick_tween:setValue(
		"sit_right_arm_anim_blend",
		standard_pose * sitting * empty_hand_right
	)
	tick_tween:setValue(
		"elytra_anim_blend",
		elytra_gliding
	)
	tick_tween:setValue(
		"sleep_anim_blend",
		sleeping
	)
	tick_tween:setValue(
		"swim_anim_blend",
		swimming
	)
	tick_tween:setValue(
		"crawl_anim_blend",
		crawling * stopped
	)
	tick_tween:setValue(
		"crawl_back_anim_blend",
		crawling * moving * back
	)
	tick_tween:setValue(
		"crawl_forward_anim_blend",
		crawling * moving * forward
	)
	tick_tween:setValue(
		"spin_attack_anim_blend",
		spin_attacking
	)
	if host:isHost() then
		tick_tween:setValue(
			"viewmodel_hold_left_anim_blend",
			hold_item_left
		)
		tick_tween:setValue(
			"viewmodel_hold_right_anim_blend",
			hold_item_right
		)
		tick_tween:setValue(
			"viewmodel_thrust_left_anim_blend",
			thrust_item_left
		)
		tick_tween:setValue(
			"viewmodel_thrust_right_anim_blend",
			thrust_item_right
		)
		tick_tween:setValue(
			"viewmodel_self_use_left_anim_blend",
			self_use_item_left
		)
		tick_tween:setValue(
			"viewmodel_self_use_right_anim_blend",
			self_use_item_right
		)
		tick_tween:setValue(
			"viewmodel_charge_left_anim_blend",
			charge_item_left
		)
		tick_tween:setValue(
			"viewmodel_charge_right_anim_blend",
			charge_item_right
		)
	end
end

function events.entity_init()
	prev_player_rot = player:getRot()
	init_item(true)
	init_item(false)
end

function events.tick()
	tick_tween:startTick()
	local left_item = player:getHeldItem(not player:isLeftHanded())
	local right_item = player:getHeldItem(player:isLeftHanded())
	if not itemEquals(left_item, current_left_item) then
		held_item_changed(left_item, true)
	end
	if not itemEquals(right_item, current_right_item) then
		held_item_changed(right_item, false)
	end
	left_item_task:setItem(left_item)
	right_item_task:setItem(right_item)
	if host:isHost() then
		viewmodel_left_item_task:setItem(left_item)
		viewmodel_right_item_task:setItem(right_item)
	end
	item_bob_progress = item_bob_progress + ITEM_BOB_SPEED
	if item_bob_progress > math.pi * 2 then
		item_bob_progress = item_bob_progress - (math.pi * 2)
	end
	tick_item(true)
	tick_item(false)
	if host:isHost() then
		local rot = player:getRot()
		local rot_offset = vec(0, 0, 0)
		rot_offset.x = math.shortAngle(prev_player_rot.y, rot.y)
		rot_offset.y = math.shortAngle(prev_player_rot.x, rot.x)
		local rot_offset_items = rot_offset * VIEWMODEL_LAG
		local rot_offset_arms = rot_offset * VIEWMODEL_ARM_LAG
		viewmodel_left_pos_3d:add(rot_offset_items * viewmodel_left_pos_3d.z * viewmodel_left_pos_3d.z)
		viewmodel_right_pos_3d:add(rot_offset_items * viewmodel_right_pos_3d.z * viewmodel_right_pos_3d.z)
		local velocity = player:getVelocity()
		local speed_offset = velocity - prev_player_velocity
		speed_offset = vectors.rotateAroundAxis(rot.y, speed_offset, vec(0, 1, 0))
		speed_offset = vectors.rotateAroundAxis(rot.x, speed_offset, vec(-1, 0, 0))
		local speed_offset_arms = speed_offset * -VIEWMODEL_ARM_POS_LAG
		speed_offset = speed_offset * -VIEWMODEL_POS_LAG
		speed_offset.z = speed_offset.z * VIEWMODEL_POS_LAG_Z
		viewmodel_left_item_speed:add(speed_offset)
		viewmodel_right_item_speed:add(speed_offset)
		tick_tween:setPartPos(viewmodel_arms, tick_tween:getPartPos(viewmodel_arms) / VIEWMODEL_ARM_STIFFNESS + rot_offset_arms + speed_offset_arms)
		prev_player_rot = rot
		prev_player_velocity = velocity
		tick_viewmodel(true)
		tick_viewmodel(false)
	end
	tick_animations()
	tick_tween:endTick()
end

function events.world_render(delta)
	tick_tween:world_render(delta)
	render_item(true)
	render_item(false)
end

function events.render(delta)
	tick_tween:render(delta)
	head:setRot(vanilla_model.head:getOriginRot())
end

if host:isHost() then

	local item_use_pos

	local function update_item_use_pos()
		local entity = host:getPickEntity()
		local block, block_hit_pos, face = host:getPickBlock()
		if entity ~= nil then
			local bounding_box = entity:getBoundingBox()
			local entity_pos = entity:getPos()
			item_use_pos = (
				entity_pos
				+ vec(
					0,
					bounding_box.y / 2.0,
					0
				)
			) * 16
			local pos_offset = player:getPos() - entity_pos
			pos_offset.y = 0
			pos_offset:normalize()
			pos_offset = pos_offset * (
				bounding_box.x
				* 8
				+ ITEM_USE_DISTANCE
			)
			item_use_pos.y = item_use_pos.y + ITEM_USE_HEIGHT_OFFSET
			item_use_pos:add(pos_offset)
		elseif block.id ~= "minecraft:air" then
			item_use_pos = block_hit_pos * 16
		end
	end
	local use_key = keybinds:fromVanilla("key.use")
	local attack_key = keybinds:fromVanilla("key.attack")
	use_key:setOnPress(update_item_use_pos)
	attack_key:setOnPress(update_item_use_pos)

	function events.tick()
		local swing_arm = player:getSwingArm()
		if swing_arm ~= nil and player:getSwingTime() == 0 then
			if item_use_pos == nil then
				update_item_use_pos()
			end
			local left = (swing_arm == "MAIN_HAND") == player:isLeftHanded()
			pings.use_item(left, item_use_pos)
		end
		item_use_pos = nil
	end

	function events.render(delta, context, matrix)
		if not renderer:isFirstPerson() then
			viewmodel:setVisible(false)
			return
		end
		viewmodel:setVisible(player:getActiveItem().id ~= "minecraft:spyglass")
		local window_size = client:getScaledWindowSize()
		local viewmodelPos2d = window_size * -0.5
		viewmodel:setPos(vec(viewmodelPos2d.x, viewmodelPos2d.y, 0.0))
		local viewmodel_scale = window_size.y * VIEWMODEL_SCALE
		viewmodel:setScale(vec(viewmodel_scale, viewmodel_scale, viewmodel_scale))
		if world.exists() then
			local view_pos = player:getPos() + vec(0, player:getEyeHeight(), 0)
			local blockLight = world.getBlockLightLevel(view_pos)
			local skyLight = world.getSkyLightLevel(view_pos)
			viewmodel:setLight(blockLight, skyLight)
		end
	end

	function events.world_render()
		left_item_part:setVisible(not renderer:isFirstPerson())
		right_item_part:setVisible(not renderer:isFirstPerson())
	end

end

function pings.use_item(left, pos)
	thrust_item(left)
	if pos == nil then
		return
	end
	local item_part
	local speed
	local viewmodel_pos_3d
	local viewmodel_speed
	if left then
		item_part = left_item_part
		speed = left_item_speed
		viewmodel_pos_3d = viewmodel_left_pos_3d
		viewmodel_speed = viewmodel_left_item_speed
	else
		item_part = right_item_part
		speed = right_item_speed
		viewmodel_pos_3d = viewmodel_right_pos_3d
		viewmodel_speed = viewmodel_right_item_speed
	end
	tick_tween:setPartPos(item_part, pos)
	speed:set(0, 0, 0)
	if host:isHost() then
		local dist = (pos - (player:getPos() + vec(0, player:getEyeHeight(), 0)) * 16):length()
		dist = dist * VIEWMODEL_USE_DIST_MULTIPLIER
		viewmodel_pos_3d:set(0, 0, dist)
		viewmodel_speed:set(0, 0, 0)
	end
end