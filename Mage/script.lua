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
local VANILLA_WALK_SPEED = 0.21585
local WALK_ANIM_BASE_SPEED = 2

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
	"air_forward",
	"air_back",
}

local walk_anims = {
	"walk_forward",
	"walk_forward_left_arm",
	"walk_forward_right_arm",
	"walk_back",
	"walk_back_left_arm",
	"walk_back_right_arm",
}

local block_face_normals = {
	["up"] = vec(0.0, 1.0, 0.0),
	["down"] = vec(0.0, -1.0, 0.0),
	["north"] = vec(0.0, 0.0, -1.0),
	["south"] = vec(0.0, 0.0, 1.0),
	["east"] = vec(1.0, 0.0, 0.0),
	["west"] = vec(-1.0, 0.0, 0.0)
}

local item_id_rotations = {
	["minecraft:fishing_rod"] = vec(55, 0, 0),
	["minecraft:carrot_on_a_stick"] = vec(55, 0, 0),
	["minecraft:trident"] = vec(90, 0, 0),
}

local item_tag_rotations = {
	["minecraft:swords"] = vec(80, 0, 0),
	["minecraft:shovels"] = vec(80, 0, 0),
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

local standard_anims_blend = 1
local hold_item_left_blend
local hold_item_right_blend
local empty_hand_left_blend
local empty_hand_right_blend

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

local function get_item_desired_pos(left)
	local rot = player:getRot().y
	local front = vec(degSin(-rot), 0, degCos(-rot)) * ITEM_FRONT_OFFSET
	local side = vec(-degCos(-rot), 0, degSin(-rot)) * ITEM_SIDE_OFFSET
	if left then
		side = side * -1
	end
	local up = vec(0, player:getEyeHeight() * 16 + ITEM_UP_OFFSET, 0)
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
	local item_pivot
	if left then
		item_pivot = left_item_pivot
	else
		item_pivot = right_item_pivot
	end
	item_pivot:setRot(get_item_rotation(item_stack))
	local hold_item_blend
	local empty_hand_blend
	if item_stack.id == "minecraft:air" then
		hold_item_blend = 0
		empty_hand_blend = 1
	else
		hold_item_blend = 1
		empty_hand_blend = 0
	end
	if left then
		current_left_item = item_stack
		hold_item_left_blend = hold_item_blend
		empty_hand_left_blend = empty_hand_blend
	else
		current_right_item = item_stack
		hold_item_right_blend = hold_item_blend
		empty_hand_right_blend = empty_hand_blend
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
	if left then
		part = left_item_part
		speed = left_item_speed
		prev_desired_pos = left_item_prev_desired_pos
	else
		part = right_item_part
		speed = right_item_speed
		prev_desired_pos = right_item_prev_desired_pos
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
		-player:getRot().y,
		0
	))
	prev_desired_pos:set(desired_pos)
end

local function set_walk_animation_speed(speed)
	for i, animation_name in ipairs(walk_anims) do
		animations.model[animation_name]:setSpeed(speed)
	end
end

local function tick_animations()
	local ground
	local air
	if player:isOnGround() then
		ground = 1
		air = 0
	else
		ground = 0
		air = 1
	end
	local velocity = player:getVelocity()
	local velocity_flat = vec(velocity.x, velocity.z)
	local speed = velocity_flat:length()
	if speed < VANILLA_WALK_SPEED then
		set_walk_animation_speed(speed * WALK_ANIM_BASE_SPEED / VANILLA_WALK_SPEED)
	else
		set_walk_animation_speed(WALK_ANIM_BASE_SPEED)
	end
	local moving = math.min(speed / VANILLA_WALK_SPEED, 1)
	local stopped = 1 - moving
	local rot = player:getRot().y
	local front = vec(degSin(-rot), degCos(-rot))
	local forward
	local back
	if front:dot(velocity_flat:normalized()) < -0.01 then
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
		hold_item_left_blend
	)
	tick_tween:setValue(
		"hold_item_right_anim_blend",
		hold_item_right_blend
	)
	tick_tween:setValue(
		"walk_forward_anim_blend",
		standard_anims_blend * ground * moving * forward
	)
	tick_tween:setValue(
		"walk_forward_left_arm_anim_blend",
		standard_anims_blend * ground * moving * forward * empty_hand_left_blend
	)
	tick_tween:setValue(
		"walk_forward_right_arm_anim_blend",
		standard_anims_blend * ground * moving * forward * empty_hand_right_blend
	)
	tick_tween:setValue(
		"walk_back_anim_blend",
		standard_anims_blend * ground * moving * back
	)
	tick_tween:setValue(
		"walk_back_left_arm_anim_blend",
		standard_anims_blend * ground * moving * back * empty_hand_left_blend
	)
	tick_tween:setValue(
		"walk_back_right_arm_anim_blend",
		standard_anims_blend * ground * moving * back * empty_hand_right_blend
	)
	tick_tween:setValue(
		"stand_anim_blend",
		standard_anims_blend * ground * stopped
	)
	tick_tween:setValue(
		"air_forward_anim_blend",
		standard_anims_blend * air * air_forward
	)
	tick_tween:setValue(
		"air_back_anim_blend",
		standard_anims_blend * air * air_back
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
end