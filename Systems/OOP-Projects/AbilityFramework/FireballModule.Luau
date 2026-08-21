-- This FireballModule creates an object to deal with the visuals and mathematics behind the fireball ability. 
-- We use Client-Side Prediction

local RunService = game:GetService("RunService")
--local ReplicatedStorage = game:GetService("ReplicatedStorage")

local AbilityFramework = require((script.Parent :: any).AbilityFramework)

local Fireball = setmetatable({}, AbilityFramework)
Fireball.__index = Fireball

function Fireball.new(character)
	local self = AbilityFramework.new("Fireball", 4, "Instant")

	setmetatable(self, Fireball)

	-- Fireball-specific stats
	self.FireDamage = 30
	self.Speed = 80
	self.Character = character -- Store the character 

	return self
end

-- Ran for clients
function Fireball:RunVisuals(targetPos)
	if not self.Character or not self.Character:FindFirstChild("HumanoidRootPart") then return end
	self.LastUsed = os.clock()
	print("Shooting a massive fireball!")

	local startPos = self.Character.HumanoidRootPart.Position
	local direction = (targetPos - startPos).Unit

	-- Create the Projectile
	local part = Instance.new("Part")
	part.Size = Vector3.new(2, 2, 2)
	part.Color = Color3.fromRGB(255, 85, 0)
	part.Material = Enum.Material.Neon
	part.Shape = Enum.PartType.Ball
	part.Anchored = true
	part.CanCollide = false
	part.CFrame = CFrame.new(startPos)
	part.Parent = workspace

	-- The Movement & Hit Logic
	local connection
	connection = RunService.Heartbeat:Connect(function(deltaTime)
		-- Kinematic Movement
		local movementThisFrame = direction * self.Speed * deltaTime
		local newPosition = part.Position + movementThisFrame
		part.CFrame = CFrame.lookAt(newPosition, newPosition + direction)

	end)

	-- Memory Cleanup 
	task.delay(4, function()
		if connection then connection:Disconnect() end
		if part then part:Destroy() end
	end)
end

-- Server deals with the mathematics
function Fireball:RunServerLogic(targetPos)
	if not self.Character or not self.Character:FindFirstChild("HumanoidRootPart") then return end
	self.LastUsed = os.clock()
	print("Shooting a massive fireball!")

	local startPos = self.Character.HumanoidRootPart.Position
	local direction = (targetPos - startPos).Unit

	local part = Instance.new("Part")
	part.Size = Vector3.new(2, 2, 2)
	part.Color = Color3.fromRGB(255, 85, 0)
	part.Transparency = 1 -- Invisible
	part.Material = Enum.Material.Neon
	part.Shape = Enum.PartType.Ball
	part.Anchored = true
	part.CanCollide = false
	part.CFrame = CFrame.new(startPos)
	part.Parent = workspace

	-- Spatial Querying (Ignore caster)
	local overlapParams = OverlapParams.new()
	overlapParams.FilterType = Enum.RaycastFilterType.Exclude
	overlapParams.FilterDescendantsInstances = {self.Character}

	local connection
	connection = RunService.Heartbeat:Connect(function(deltaTime)
		
		local movementThisFrame = direction * self.Speed * deltaTime
		local newPosition = part.Position + movementThisFrame
		part.CFrame = CFrame.lookAt(newPosition, newPosition + direction)

		-- Hit Detection
		local result = workspace:GetPartsInPart(part, overlapParams)

		for _, hitPart in ipairs(result) do
			local humanoid = hitPart.Parent:FindFirstChild("Humanoid")
			if humanoid then
				humanoid:TakeDamage(self.FireDamage)
				connection:Disconnect()
				part:Destroy()
				break
			end
		end
	end)

	-- 4. Memory Cleanup 
	task.delay(4, function()
		if connection then connection:Disconnect() end
		if part then part:Destroy() end
	end)
end

return Fireball