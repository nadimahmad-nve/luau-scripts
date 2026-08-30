--[[ 
This is the server script that handles the requests from InteractionInput (ClientScript). 
This ensures that the Generator Repairing is robust. Comments are throughout detailing the purpose of each section of code.
]]-- 

-- SERVICES -- 
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local CollectionService = game:GetService("CollectionService")
local TweenService = game:GetService("TweenService")
local Players = game:GetService("Players")
local Debris = game:GetService("Debris")

-- REMOTE EVENTS FOLDER --
local RemoteEvents = ReplicatedStorage:WaitForChild("RemoteEvents")

-- REMOTE EVENTS -- 
local RepairEvent = Instance.new("RemoteEvent")
RepairEvent.Name = "RepairEvent"
RepairEvent.Parent = ReplicatedStorage

local QTEFailedEvent = RemoteEvents:WaitForChild("QTEFailedEvent")
local ExterminatorPingEvent = RemoteEvents:WaitForChild("ExterminatorPingEvent") 

-- CONSTANTS -- 
local TARGET_TIME = 58 -- Exact amount of seconds the repair will take
local TICK_RATE = 0.1     
local REPAIR_AMOUNT = (100 / TARGET_TIME) * TICK_RATE 

-- STATE TRACKING --
local activeRepairers = {} -- Format: [Player] = TargetGenerator

-- FUNCTIONS -- 
local function getPlayerGUI(player)
	local pGui = player:FindFirstChild("PlayerGui")
	if pGui then return pGui:FindFirstChild("ProgressGUI") end
	return nil
end

local function updateVisuals(player, part)
	local current = part:GetAttribute("Progress") or 0

	local targetGUI = getPlayerGUI(player)
	if targetGUI then
		local progressBar = targetGUI:FindFirstChild("ProgressBar", true) 

		if progressBar then
			local fill = progressBar:FindFirstChild("Fill")
			local stroke = progressBar:FindFirstChild("UIStroke")

			if current >= 100 then
				local fadeInfo = TweenInfo.new(0.5, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)

				TweenService:Create(progressBar, fadeInfo, {BackgroundTransparency = 1}):Play()
				if fill then TweenService:Create(fill, fadeInfo, {BackgroundTransparency = 1}):Play() end
				if stroke then TweenService:Create(stroke, fadeInfo, {Transparency = 1}):Play() end
			else
				progressBar.BackgroundTransparency = 0.58 
				if fill then fill.BackgroundTransparency = 0 end
				if stroke then stroke.Transparency = 0.2 end

				if fill then
					local scale = current / 100
					local tweenInfo = TweenInfo.new(TICK_RATE, Enum.EasingStyle.Linear)
					TweenService:Create(fill, tweenInfo, {Size = UDim2.new(scale, 0, 1, 0)}):Play()
				end
			end
		end
	end
end


local function getActiveRepairerCount(targetGenerator)
	local count = 0
	for _, activeGen in pairs(activeRepairers) do
		if activeGen == targetGenerator then
			count += 1
		end
	end
	return count
end

RepairEvent.OnServerEvent:Connect(function(player, action, targetSlot, targetGenerator)

	if action == "Start" then
		if player:GetAttribute("RoundStatus") ~= "Alive" then return end 
		if player:GetAttribute("IsRepairing") == true then return end 

		-- SECURITY CHECKS --
		if not targetSlot or not targetGenerator then return end
		if not CollectionService:HasTag(targetGenerator, "Repairable") then return end
		if targetGenerator:GetAttribute("IsFixed") == true then return end -- Exploit patch!

		local character = player.Character
		if not character then return end
		
		targetSlot:SetAttribute("IsOccupied", true)
		
		for _, descendant in ipairs(targetSlot:GetDescendants()) do
			if descendant:IsA("ParticleEmitter") then
				descendant.Enabled = true 
			end
		end

		-- START REPAIR LOOP --
		player:SetAttribute("IsRepairing", true)
		activeRepairers[player] = targetGenerator -- Register the player
		
		-- SOUND LOGIC:
		local repairSound = targetGenerator.PrimaryPart:FindFirstChild("RepairSound")
		if repairSound and not repairSound.IsPlaying then
			repairSound:Play()
		end

		-- Show GUI
		local targetGUI = getPlayerGUI(player)
		if targetGUI then 
			local progressBar = targetGUI:FindFirstChild("ProgressBar", true)
			if progressBar then
				local fill = progressBar:FindFirstChild("Fill")
				local stroke = progressBar:FindFirstChild("UIStroke")
				local currentProgress = targetGenerator:GetAttribute("Progress") or 0

				progressBar.BackgroundTransparency = 0.58 
				if stroke then stroke.Transparency = 0.2 end
				if fill then 
					fill.BackgroundTransparency = 0 
					fill.Size = UDim2.new(currentProgress / 100, 0, 1, 0)
				end
			end
			targetGUI.Enabled = true 
		end

		task.spawn(function()
			while player:GetAttribute("IsRepairing") == true do

				if not character or not character.Parent or not targetGenerator.Parent then
					break
				end

				-- OVERLAP CHECK
				local overlapParams = OverlapParams.new()
				overlapParams.FilterDescendantsInstances = {character}
				overlapParams.FilterType = Enum.RaycastFilterType.Include
				
				local partsInSlot = workspace:GetPartsInPart(targetSlot, overlapParams)
				if #partsInSlot == 0 then
					break 
				end

				local currentProgress = targetGenerator:GetAttribute("Progress") or 0
				updateVisuals(player, targetGenerator)

				if currentProgress < 100 then
					local newProgress = math.min(currentProgress + REPAIR_AMOUNT, 100)
					targetGenerator:SetAttribute("Progress", newProgress)
					
					updateVisuals(player, targetGenerator)

					if newProgress >= 100 and targetGenerator:GetAttribute("IsFixed") ~= true then
						targetGenerator:SetAttribute("IsFixed", true)
						print("Generator Fixed: " .. targetGenerator.Name)
						
						-- SOUND LOGIC: Generator is done - stpo sound 
						if repairSound then
							repairSound:Stop()
						end

						-- Instantly award everyone currently working on this generator
						for activePlayer, activeGen in pairs(activeRepairers) do
							if activeGen == targetGenerator then
								local currentFixed = activePlayer:GetAttribute("ObjectsFixed") or 0 
								activePlayer:SetAttribute("ObjectsFixed", currentFixed + 1)
								activePlayer:SetAttribute("IsRepairing", false)
							end
						end
					end
				else
					-- Generator is already maxed, exit loop to prevent exploits
					break 
				end

				task.wait(TICK_RATE)
			end
			
			-- CLEANUP (Runs whenever the while loop breaks)
			player:SetAttribute("IsRepairing", false)
			activeRepairers[player] = nil -- Unregister the player
			
			-- SOUND LOGIC: If the player walks away, check if anyone else is still on it
			if getActiveRepairerCount(targetGenerator) == 0 then
				if repairSound then repairSound:Stop() end
			end
			
			for _, descendant in ipairs(targetSlot:GetDescendants()) do
				if descendant:IsA("ParticleEmitter") then
					descendant.Enabled = false
				end
			end
			
			targetSlot:SetAttribute("IsOccupied", false)

			local gui = getPlayerGUI(player)
			if gui then 
				if targetGenerator:GetAttribute("Progress") >= 100 then
					task.delay(0.5, function()
						gui.Enabled = false
					end)
				else
					gui.Enabled = false 
				end
			end
		end)

	elseif action == "Stop" then
		local targetGeneratorForStop = activeRepairers[player]
		-- STOP COMMAND --
		player:SetAttribute("IsRepairing", false)
		activeRepairers[player] = nil -- Unregister the player
		
		if targetGeneratorForStop and getActiveRepairerCount(targetGeneratorForStop) == 0 then
			local repairSound = targetGeneratorForStop:FindFirstChild("RepairSound")
			if repairSound then repairSound:Stop() end
		end

		local targetGUI = getPlayerGUI(player)
		if targetGUI then targetGUI.Enabled = false end
	end
end)


-- REMOTE EVENT CONNECTIONS -- 
QTEFailedEvent.OnServerEvent:Connect(function(player, targetObject)
	if not targetObject or not CollectionService:HasTag(targetObject, "Repairable") then return end 

	targetObject:SetAttribute("IsOverloaded", true)

	task.delay(3, function()
		if targetObject then 
			targetObject:SetAttribute("IsOverloaded", false)
		end
	end)

	-- Loop through everyone to distribute the sound and visual ping
	for _, p in ipairs(Players:GetPlayers()) do 
		local role = p:GetAttribute("Role")
		local isSpectating = p:GetAttribute("IsSpectating") 

		if role == "Exterminator" or role == "Mechanic" or isSpectating then 
			-- 1. Create a 2D Screen Sound for this specific player
			local pGui = p:FindFirstChild("PlayerGui")
			if pGui then
				local bangSound = Instance.new("Sound")
				bangSound.SoundId = "rbxassetid://12222084"
				bangSound.Volume = 0.55
				bangSound.Parent = pGui 
				bangSound:Play()

				Debris:AddItem(bangSound, 5)
			end

			-- 2. Send the visual ping
			ExterminatorPingEvent:FireClient(p, targetObject)
		end
	end
end)