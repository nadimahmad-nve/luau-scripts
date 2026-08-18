-- This is a script that uses simple Raycasting to heal players within a range.
-- If the player does not have line of sight (e.g. they are blocked by a wall), they do not receive healing.

-- SERVICES -- 
local Players = game:GetService("Players")

-- VARIABLES -- 
local totem = workspace:WaitForChild("Project2"):WaitForChild("Part")
local particleEmitter = totem:WaitForChild("ParticleEmitter") 

-- FUNCTIONS -- 
while true do
	task.wait(2)
	
	local playersInRange = {}
	local hitAtLeastOnePlayer = false 
	
	for _, player in pairs(Players:GetPlayers()) do
		local character = player.Character 
		if not character then continue end 
		
		local humanoidRootPart = character:FindFirstChild("HumanoidRootPart")
		if not humanoidRootPart then continue end 
		
		-- Check Distance -- 
		if (humanoidRootPart.Position - totem.Position).Magnitude <= 20 then 
			table.insert(playersInRange, player)
		end
	end
	
	for _, player in pairs(playersInRange) do

		local character = player.Character
		if not character then continue end
		local humanoidRootPart = character:FindFirstChild("HumanoidRootPart")
		if not humanoidRootPart then continue end 
		
		local playerHumanoid = character:FindFirstChild("Humanoid")
		if not playerHumanoid then continue end 
		
		local characterPosition = humanoidRootPart.Position
		
		local direction = (characterPosition - totem.Position)
		
		local raycastParams = RaycastParams.new() 
		raycastParams.FilterType = Enum.RaycastFilterType.Exclude
		raycastParams.FilterDescendantsInstances = {totem}
		
		local totemPosition = totem.Position
		local raycastResult = workspace:Raycast(totemPosition, direction, raycastParams)
		
		if raycastResult and raycastResult.Instance:IsDescendantOf(character) then 
			hitAtLeastOnePlayer = true 

			print("Healed " .. player.Name .. " for 5HP")
			playerHumanoid.Health += 5 
		end
	end
	
	particleEmitter.Enabled = hitAtLeastOnePlayer
end