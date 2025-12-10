local tick_tween = require("tickTween")

local ITEM_FRONT_OFFSET = 10
local ITEM_SIDE_OFFSET = 11
local ITEM_UP_OFFSET = 2
local ITEM_STIFFNESS = 0.4
local ITEM_DAMPING = 0.5
local ITEM_SPEED_HELP = 0.5
local ITEM_BOB_INTENSITY = 2
local ITEM_BOB_ROTATION_INTENSITY = 5
local ITEM_BOB_SPEED = 0.13
local ITEM_USE_DISTANCE = 4
local ITEM_USE_HEIGHT_OFFSET = 1
local ITEM_THRUST_DURATION = 6
local ITEM_THRUST_BELND_START = 4
local ITEM_SPAWN_DOWN_OFFSET = 10
local ITEM_SPAWN_UP_SPEED = 10
local VANILLA_WALK_SPEED = 0.21585
local WALK_ANIM_BASE_SPEED = 2
local VANILLA_WALK_SPEED_SNEAKING = 0.06475
local WALK_ANIM_BASE_SPEED_SNEAKING = 0.7
local VANILLA_WALK_SPEED_CRAWLING = 0.06475
local WALK_ANIM_BASE_SPEED_CRAWLING = 0.5

local item_empty = models.model.ItemEmpty
local world = models.model.World
local left_item_part = world.CustomLeftItem
local right_item_part = world.CustomRightItem
local left_item_pivot = left_item_part.PivotItemLeft
local right_item_pivot = right_item_part.PivotItemRight
local left_item_parent = left_item_pivot.OffsetItemLeft
local right_item_parent = right_item_pivot.OffsetItemRight
local root = models.model.root
local head = root.CustomHead

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
		anim = "use_on_self",
		thrust = false,
	},
	DRINK = {
		front = 8,
		side = 0,
		up = -6,
		rot = vec(-45, 0, 0),
		anim = "use_on_self",
		thrust = false,
	},
	BLOCK = {
		front = ITEM_FRONT_OFFSET,
		side = 2,
		up = -13,
		rot = vec(0, 90, 0),
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
		thrust = false,
	},
	TOOT_HORN = {
		front = 7,
		side = 0,
		up = -6,
		rot = vec(0, 90, 0),
		anim = "use_on_self",
		thrust = false,
	},
}

local left_item_task
local right_item_task

local current_left_item
local current_right_item

local left_item_speed = vec(0, 0, 0)
local right_item_speed = vec(0, 0, 0)
local left_item_prev_desired_pos
local right_item_prev_desired_pos

local item_bob_progress = 0

local hold_item_left_blend
local hold_item_right_blend
local thrust_item_left_time_left = 0
local thrust_item_right_time_left = 0

local left_item_rot_override_action = "NONE"
local right_item_rot_override_action = "NONE"

vanilla_model.ALL:setVisible(false)

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

function degCos(x)
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
	if left then
		item_part = left_item_part
		item_pivot = left_item_pivot
	else
		item_part = right_item_part
		item_pivot = right_item_pivot
	end
	tick_tween:setPartRot(item_pivot, get_item_rotation(item_stack))
	tick_tween:teleportPart(item_pivot)
	tick_tween:setPartPos(item_part, get_item_desired_pos(left) + vec(0, -ITEM_SPAWN_DOWN_OFFSET, 0))
	tick_tween:teleportPart(item_part)
	local hold_item_blend
	if item_stack.id == "minecraft:air" then
		hold_item_blend = 0
	else
		hold_item_blend = 1
	end
	if left then
		current_left_item = item_stack
		hold_item_left_blend = hold_item_blend
		left_item_speed = vec(0, ITEM_SPAWN_UP_SPEED, 0)
	else
		current_right_item = item_stack
		hold_item_right_blend = hold_item_blend
		right_item_speed = vec(0, ITEM_SPAWN_UP_SPEED, 0)
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
		left_item_part:setPos(desired_pos)
		left_item_task = left_item_parent:newItem("left_item")
		left_item_task:setDisplayMode("THIRD_PERSON_LEFT_HAND")
	else
		right_item_prev_desired_pos = desired_pos
		right_item_part:setPos(desired_pos)
		right_item_task = right_item_parent:newItem("right_item")
		right_item_task:setDisplayMode("THIRD_PERSON_RIGHT_HAND")
	end
end

local function tick_item(left)
	local part
	local speed
	local prev_desired_pos
	local rot_override_action
	if left then
		part = left_item_part
		speed = left_item_speed
		prev_desired_pos = left_item_prev_desired_pos
		rot_override_action = left_item_rot_override_action
	else
		part = right_item_part
		speed = right_item_speed
		prev_desired_pos = right_item_prev_desired_pos
		rot_override_action = right_item_rot_override_action
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
		tick_tween:setPartRot(
			item_pivot,
			get_item_rotation(player:getHeldItem(player:isLeftHanded() ~= left)) + rotation_offset
		)
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
end

function events.entity_init()
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
	item_bob_progress = item_bob_progress + ITEM_BOB_SPEED
	if item_bob_progress > math.pi * 2 then
		item_bob_progress = item_bob_progress - (math.pi * 2)
	end
	tick_item(true)
	tick_item(false)
	tick_animations()
	tick_tween:endTick()
end

function events.world_render(delta)
	tick_tween:world_render(delta)
end

function events.render(delta)
	tick_tween:render(delta)
	head:setRot(vanilla_model.head:getOriginRot())
end

function events.item_render(item, mode, pos, rot, scale, left)
	if mode == "FIRST_PERSON_LEFT_HAND" or mode == "FIRST_PERSON_RIGHT_HAND" then
		return item_empty
	end
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

end

function pings.use_item(left, pos)
	if pos == nil then
		return
	end
	local item_part
	local speed
	if left then
		item_part = left_item_part
		speed = left_item_speed
	else
		item_part = right_item_part
		speed = right_item_speed
	end
	tick_tween:setPartPos(item_part, pos)
	speed:set(0, 0, 0)
	thrust_item(left)
end