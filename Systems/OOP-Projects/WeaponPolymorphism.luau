-- Simple polymorphism in Luau

local Weapon = {}
Weapon.__index = Weapon

local StunBaton = {}
StunBaton.__index = setmetatable(StunBaton, Weapon)

local StunGun = {}
StunGun.__index = setmetatable(StunGun, Weapon)

function Weapon.new(name, stunDuration)
	local self = setmetatable({}, Weapon)
	
	self.Name = name 
	self.stunDuration = stunDuration
	
	return self 
end

function Weapon:Attack(targetName)
	print("Weapon used on ".. targetName)
end


function StunBaton.new(name, stunDuration)
	local self = Weapon.new(name, stunDuration)
	
	setmetatable(self, StunBaton)
	
	return self
end

function StunBaton:Attack(targetName)
	print(self.Name .. " swings at ".. targetName .. " stunning them for " .. tostring(self.stunDuration) .. " seconds.")
end

function StunGun.new(name, stunDuration)
	local self = Weapon.new(name, stunDuration)
	
	setmetatable(self , StunGun)
	
	return self 
end

function StunGun:Attack(targetName)
	print(self.Name .. " fires a tracking dart at ".. targetName .. " stunning them for " .. tostring(self.stunDuration) .. " seconds.")
end

local inventory = {StunGun.new("StunGun", 5), StunBaton.new("StunBaton", 3)}

for _, item in pairs(inventory) do
	item:Attack("Player1")
end


return Weapon
