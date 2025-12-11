--#region UTILITY

local cos, sin, asin, acos, atan2, abs, sqrt = math.cos, math.sin, math.asin, math.acos, math.atan2, math.abs, math.sqrt
local pi = math.pi

-- function stolen from https://gist.github.com/hashmal/874792
local function tprint (tbl, indent)
  if not indent then indent = 0 end
  for k, v in pairs(tbl) do
    formatting = string.rep("  ", indent) ..tostring(k) .. ": "
    if type(v) == "table" then
      print(formatting)
      tprint(v, indent+1)
    else
      print(formatting .. tostring(v))
    end
  end
end

-- function stolen from wikipedia
local function QuatToEuler(q)

	local angles = vec(0, 0, 0)

	-- roll (x-axis rotation)
	local sinr_cosp = 2 * (q.w * q.x + q.y * q.z)
	local cosr_cosp = 1 - 2 * (q.x * q.x + q.y * q.y)
	angles.x = atan2(sinr_cosp, cosr_cosp)

	-- pitch (y-axis rotation)
	local sinp = sqrt(1 + 2 * (q.w * q.y - q.x * q.z))
	local cosp = sqrt(1 - 2 * (q.w * q.y - q.x * q.z))
	angles.y = 2 * atan2(sinp, cosp) - pi / 2

	-- yaw (z-axis rotation)
	local siny_cosp = 2 * (q.w * q.z + q.x * q.y)
	local cosy_cosp = 1 - 2 * (q.y * q.y + q.z * q.z)
	angles.z = atan2(siny_cosp, cosy_cosp)

	return angles:toDeg()
end

-- function stolen from wikipedia
local function EulerToQuat(euler)

	euler = euler:toRad()

	-- Abbreviations for the various angular functions
	local cr = cos(euler.x * 0.5)
	local sr = sin(euler.x * 0.5)
	local cp = cos(euler.y * 0.5)
	local sp = sin(euler.y * 0.5)
	local cy = cos(euler.z * 0.5)
	local sy = sin(euler.z * 0.5)

	local q = vec(0, 0, 0, 0);
	q.w = cr * cp * cy + sr * sp * sy
	q.x = sr * cp * cy - cr * sp * sy
	q.y = cr * sp * cy + sr * cp * sy
	q.z = cr * cp * sy - sr * sp * cy

	return q;
end

-- function stolen from Godot's source code
local function QuatDot(a, b)
	return a.x * b.x + a.y * b.y + a.z * b.z + a.w * b.w;
end

-- function stolen from Godot's source code
local function quatSlerp(from, to, weight)
	local to1 = vec(0, 0, 0, 0);
	local omega, cosom, sinom, scale0, scale1;

	-- calc cosine
	cosom = QuatDot(from, to);

	-- adjust signs (if necessary)
	if (cosom < 0.0) then
		cosom = -cosom;
		to1 = -to;
	else
		to1 = to;
	end
	
	-- calculate coefficients
	
	if ((1.0 - cosom) > 0.00001) then
		-- standard case (slerp)
		omega = acos(cosom);
		sinom = sin(omega);
		scale0 = sin((1.0 - weight) * omega) / sinom;
		scale1 = sin(weight * omega) / sinom;
	else
		-- "from" and "to" quaternions are very close
		--  ... so we can do a linear interpolation
		scale0 = 1.0 - weight;
		scale1 = weight;
	end
	-- calculate final values
	return vec(
		scale0 * from.x + scale1 * to1.x,
		scale0 * from.y + scale1 * to1.y,
		scale0 * from.z + scale1 * to1.z,
		scale0 * from.w + scale1 * to1.w
	);
end

local function isPartWorldParented(part)
	while true do
		if part == nil then
			return false
		end
		if part:getParentType() == "World" then
			return true
		end
		part = part:getParent()
	end
end

--#endregion

--#region CLASS DECLARATION

local tickTween = {}

--#endregion

--#region PRIVATE

tickTween.parts = {}
tickTween.values = {}
tickTween.worlParts = {}
tickTween.worldValues = {}

function tickTween:addPartIfNeccesary(part, table)
	if table[part] == nil then
		table[part] = {}
	end
end

function tickTween:startTickPartsTable(table)
	for part, transforms in pairs(table) do
		for transform, data in pairs(transforms) do
			if transform == "pos" then
				part:setPos(data.next)
			end
			if transform == "quat" then
				part:setRot(QuatToEuler(data.next))
			end
			if transform == "scale" then
				part:setScale(data.next)
			end
			data.prev = data.next
			data.next = nil
		end
	end
end

function tickTween:startTickValuesTable(table)
	for value, data in pairs(table) do
		data.change_func(data.next)
		data.prev = data.next
	end
end

function tickTween:endTickPartsTable(table)
	for part, transforms in pairs(table) do
		for transform, data in pairs(transforms) do
			if data.next == nil then
				transforms[transform] = nil
			elseif data.prev == nil then
				data.prev = data.next
			end
		end
		if transforms.pos == nil and transforms.quat == nil and transforms.scale == nil then
			table[part] = nil
		end
	end
end

function tickTween:renderPartsTable(table, delta)
	for part, transforms in pairs(table) do
		for transform, data in pairs(transforms) do
			if transform == "pos" then
				part:setPos(math.lerp(data.prev, data.next, delta))
			elseif transform == "quat" then
				part:setRot(QuatToEuler(quatSlerp(data.prev, data.next, delta)))
			elseif transform == "scale" then
				part:setScale(math.lerp(data.prev, data.next, delta))
			end
		end
	end
end

function tickTween:renderValuesTable(table, delta)
	for value, data in pairs(table) do
		if data.prev ~= data.next then
			data.change_func(math.lerp(data.prev, data.next, delta))
		end
	end
end

--#endregion

--#region PUBLIC

---@param name string
---@param starting_vaule number
---@param on_change function
---@param world boolean
---@return nil
function tickTween:createValue(name, starting_vaule, on_change, world)
	world = world or false
	local table
	if world then
		table = self.worldValues
	else
		table = self.values
	end
	table[name] = {
		next = starting_vaule,
		change_func = on_change,
	}
	on_change(starting_vaule)
end

---@return nil
function tickTween:startTick()
	self:startTickPartsTable(self.parts)
	self:startTickPartsTable(self.worlParts)
	self:startTickValuesTable(self.values)
	self:startTickValuesTable(self.worldValues)
end

---@param part ModelPart
---@param pos Vector3
---@return nil
function tickTween:setPartPos(part, pos)
	local table
	if isPartWorldParented(part) then
		table = self.worlParts
	else
		table = self.parts
	end
    self:addPartIfNeccesary(part, table)
	local transforms = table[part]
	if transforms.pos == nil then
		transforms.pos = {
			prev = part:getPos()
		}
	end
	transforms.pos.next = pos
end

---@param part ModelPart
---@param quat Vector4
---@return nil
function tickTween:setPartQuat(part, quat)
    local table
	if isPartWorldParented(part) then
		table = self.worlParts
	else
		table = self.parts
	end
    self:addPartIfNeccesary(part, table)
	local transforms = table[part]
	if transforms.quat == nil then
		transforms.quat = {
			prev = EulerToQuat(part:getRot())
		}
	end
	transforms.quat.next = quat
end

---@param part ModelPart
---@param rot Vector3
---@return nil
function tickTween:setPartRot(part, rot)
    tickTween:setPartQuat(part, EulerToQuat(rot))
end

---@param part ModelPart
---@param scale Vector3
---@return nil
function tickTween:setPartScale(part, scale)
	local table
	if isPartWorldParented(part) then
		table = self.worlParts
	else
		table = self.parts
	end
    self:addPartIfNeccesary(part, table)
	local transforms = table[part]
	if transforms.scale == nil then
		transforms.scale = {
			prev = part:getScale()
		}
	end
	transforms.scale.next = scale
end

---@param part ModelPart
---@return Vector3
function tickTween:getPartPos(part)
	local table
	if isPartWorldParented(part) then
		table = self.worlParts
	else
		table = self.parts
	end
	local transforms = table[part]
	if transforms == nil then
		return part:getPos()
	end
	local data = transforms.pos
	if data == nil then
		return part:getPos()
	end
	local next = data.next
	if next ~= nil then
		return next
	end
	local prev = data.prev
	if prev ~= nil then
		return prev
	end
	return part:getPos()
end

---@param part ModelPart
---@return Vector3
function tickTween:getPartRot(part)
	local table
	if isPartWorldParented(part) then
		table = self.worlParts
	else
		table = self.parts
	end
	local transforms = table[part]
	if transforms == nil then
		return part:getRot()
	end
	local data = transforms.pos
	if data == nil then
		return part:getRot()
	end
	local next = data.next
	if next ~= nil then
		return QuatToEuler(next)
	end
	local prev = data.prev
	if prev ~= nil then
		return QuatToEuler(prev)
	end
	return part:getRot()
end

---@param part ModelPart
---@return Vector3
function tickTween:getPartScale(part)
	local table
	if isPartWorldParented(part) then
		table = self.worlParts
	else
		table = self.parts
	end
	local transforms = table[part]
	if transforms == nil then
		return part:getScale()
	end
	local data = transforms.scale
	if data == nil then
		return part:getScale()
	end
	local next = data.next
	if next ~= nil then
		return next
	end
	local prev = data.prev
	if prev ~= nil then
		return prev
	end
	return part:getScale()
end

---@param part ModelPart
---@return nil
function tickTween:teleportPartPos(part)
	local table
	if isPartWorldParented(part) then
		table = self.worlParts
	else
		table = self.parts
	end
	local data = table[part]
	if data == nil then
		return
	end
	local pos_data = data.pos
	if pos_data == nil then
		return
	end
	pos_data.prev = nil
end

---@param part ModelPart
---@return nil
function tickTween:teleportPartRot(part)
	local table
	if isPartWorldParented(part) then
		table = self.worlParts
	else
		table = self.parts
	end
	local data = table[part]
	if data == nil then
		return
	end
	local quat_data = data.quat
	if quat_data == nil then
		return
	end
	quat_data.prev = nil
end

---@param part ModelPart
---@return nil
function tickTween:teleportPartScale(part)
	local table
	if isPartWorldParented(part) then
		table = self.worlParts
	else
		table = self.parts
	end
	local data = table[part]
	if data == nil then
		return
	end
	local scale_data = data.scale
	if scale_data == nil then
		return
	end
	scale_data.prev = nil
end

---@param part ModelPart
---@return nil
function tickTween:teleportPart(part)
	self:teleportPartPos(part)
	self:teleportPartRot(part)
	self:teleportPartScale(part)
end

---@param name string
---@param value number
---@return nil
function tickTween:setValue(name, value)
	self.values[name].next = value
end

---comment
---@param name any
---@param world any
function tickTween:teleportValue(name, world)
	local table
	if world then
		table = self.worldValues
	else
		table = self.values
	end
	table[name].prev = nil
end

---@return nil
function tickTween:endTick()
	self:endTickPartsTable(self.parts)
	self:endTickPartsTable(self.worlParts)
end

function tickTween:render(delta)
	self:renderPartsTable(self.parts, delta)
	self:renderValuesTable(self.values, delta)
end

function tickTween:world_render(delta)
	self:renderPartsTable(self.worlParts, delta)
	self:renderValuesTable(self.worldValues, delta)
end

--#endregion

--#region OUTPUT

return tickTween

--#endregion