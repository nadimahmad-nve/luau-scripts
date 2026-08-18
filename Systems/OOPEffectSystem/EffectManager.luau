-- This is a small ModuleScript that implements effects as a centralised system, using OOP. 

local StatusEffect = {}
StatusEffect.__index = StatusEffect

local PoisonEffect = {}
PoisonEffect.__index = setmetatable(PoisonEffect, StatusEffect)

local SpeedEffect = {}
SpeedEffect.__index = setmetatable(SpeedEffect, StatusEffect)

local activeEffects = {}

local EffectRegistry = {
	["Poison"] = PoisonEffect,
	["Speed"] = SpeedEffect
}

function StatusEffect.Apply(player, effectName)
	if not activeEffects[player] then
		activeEffects[player] = {}
	end

	if activeEffects[player][effectName] then
		activeEffects[player][effectName]:Refresh()
		return
	end

	local ClassBlueprint = EffectRegistry[effectName]

	if ClassBlueprint then
		local newEffect = ClassBlueprint.new(player)
		activeEffects[player][effectName] = newEffect
		newEffect:Start()
	else
		warn("Attempted to apply unknown status effect: " .. tostring(effectName))
	end
end

function StatusEffect:Destroy(effectName)
	if activeEffects[self.Player] then
		activeEffects[self.Player][effectName] = nil
	end
end

-- Poison Sub-Class Setup 
function PoisonEffect.new(player)
	local self = setmetatable({}, PoisonEffect)
	
	self.Player = player
	self.Duration = 5
	self.Damage = 5

	return self
end

function PoisonEffect:Start()
	task.spawn(function()
		local character = self.Player.Character
		if not character then return end
		local humanoid = character:FindFirstChild("Humanoid")
		if not humanoid then return end
		
		while self.Duration > 0 do
			task.wait(1)
			self.Duration -= 1
			humanoid.Health -= self.Damage
			print("Poisoned " .. self.Player.Name .. " for 5HP.")
		end
		
		self:Destroy("Poison")
		print("Poison effect ended for " .. self.Player.Name)
	end)
end

function PoisonEffect:Refresh()
	self.Duration = 5 -- Reset duration
end


-- Speed Sub-Class Setup
function SpeedEffect.new(player)
	local self = setmetatable({}, SpeedEffect)
	
	self.Player = player
	self.Duration = 5
	self.Speed = 10
	
	return self
end

function SpeedEffect:Start()
	task.spawn(function()
		local character = self.Player.Character
		if not character then return end
		local humanoid = character:FindFirstChild("Humanoid")
		if not humanoid then return end
		
		humanoid.WalkSpeed += self.Speed
		
		while self.Duration > 0 do
			task.wait(1)
			self.Duration -= 1
		end
		
		humanoid.WalkSpeed -= self.Speed
		self:Destroy("Speed")
		print("Speed effect ended for " .. self.Player.Name)
	end)
end

function SpeedEffect:Refresh()
	self.Duration = 5 -- Reset duration
end

return StatusEffect