-- This EarthquakeModule creates an object to deal with the visuals and mathematics behind the earthquake ability. 
-- We use Client-Side Prediction

-- local ReplicatedStorage = game:GetService("ReplicatedStorage")
local AbilityFramework = require((script.Parent :: any).AbilityFramework)

local Earthquake = setmetatable({}, AbilityFramework)
Earthquake.__index = Earthquake

function Earthquake.new(character)
	local self = AbilityFramework.new("Earthquake", 8, "Hold")
	setmetatable(self, Earthquake)

	self.Character = character
	self.KnockbackForce = 150
	self.Radius = 25
	self.IsCharging = false 

	return self
end

function Earthquake:RunVisuals(targetPos)
	self.IsCharging = true 
	
	local character = self.Character
	if not character or not character:FindFirstChild("HumanoidRootPart") then return end

    -- Slow the player down 
	local humanoid = character:FindFirstChild("Humanoid")
	if humanoid then
		humanoid.WalkSpeed = 8
	end
	
	print("Charging earthquake...")
end

-- The key is released (Client Visuals)
function Earthquake:RunReleaseVisuals(targetPos)
	self.IsCharging = false
	self.LastUsed = os.clock()
	print("BOOM! Visual shockwave expands!")
	
	local character = self.Character
	if not character or not character:FindFirstChild("HumanoidRootPart") then return end

	local humanoid = character:FindFirstChild("Humanoid")
	if humanoid then
		humanoid.WalkSpeed = 16
	end
end

-- The key is released (Server Hitbox & Math)
function Earthquake:RunReleaseHitbox(targetPos)
	self.LastUsed = os.clock()
	if not self.Character or not self.Character:FindFirstChild("HumanoidRootPart") then return end

	local hrp = self.Character.HumanoidRootPart

	-- Spatial Query: Grab everything in a 25-stud radius
	local overlapParams = OverlapParams.new()
	overlapParams.FilterType = Enum.RaycastFilterType.Exclude
	overlapParams.FilterDescendantsInstances = {self.Character}

	local hitParts = workspace:GetPartBoundsInRadius(hrp.Position, self.Radius, overlapParams)

	local hitHumanoids = {}

	for _, part in ipairs(hitParts) do
		local enemyHumanoid = part.Parent:FindFirstChild("Humanoid")
		local enemyHRP = part.Parent:FindFirstChild("HumanoidRootPart")

		if enemyHumanoid and enemyHRP and not hitHumanoids[enemyHumanoid] then
			hitHumanoids[enemyHumanoid] = true

			-- Calculate knockback direction (away from the caster)
			local direction = (enemyHRP.Position - hrp.Position).Unit

			-- Apply the physics knockback!
			enemyHRP:ApplyImpulse(direction * self.KnockbackForce * enemyHRP.AssemblyMass)
			enemyHumanoid:TakeDamage(15)
		end
	end
end

return Earthquake