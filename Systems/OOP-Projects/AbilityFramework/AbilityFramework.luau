-- This class is the superclass for abilities. 

local AbilityFramework = {}
AbilityFramework.__index = AbilityFramework

function AbilityFramework.new(name, cooldown, activationStyle)
	local self = setmetatable({}, AbilityFramework)

	self.Name = name 
	self.Cooldown = cooldown 
	self.LastUsed = 0 
	self.ActivationStyle = activationStyle -- "Instant", "Hold", "Toggle"

	return self 
end

function AbilityFramework:StartCast()
	print("Starting cast")
end

function AbilityFramework:ReleaseCast()
	print("Releasing cast")
end

function AbilityFramework:Cancel()
	print("Cancelling ability")
end

return AbilityFramework