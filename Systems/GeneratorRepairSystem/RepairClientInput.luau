--[[ 
This is the local script that handles a client repairing a generator. 
It works with the RepairHandler ServerScript to ensure that the repair is handled by the server robustly. 
]]

local InteractionInput = {} 

-- SERVICES -- 
local ContextActionService = game:GetService("ContextActionService")
local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local StarterGui = game:GetService("StarterGui")
StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.Backpack, false)

-- REMOTE EVENT FOLDER --
local RemoteEvents = ReplicatedStorage:WaitForChild("RemoteEvents")

-- REMOTE EVENTS --
local RepairEvent = ReplicatedStorage:WaitForChild("RepairEvent")
local QTEFailedEvent = RemoteEvents:WaitForChild("QTEFailedEvent")

-- CONSTANTS -- 
local MAX_DISTANCE = 15 
local MAX_PROGRESS = 100 
local INTRO_ANIM_ID = "rbxassetid://133175676243916"
local LOOP_ANIM_ID = "rbxassetid://88885692090312"

-- VARIABLES -- 
local player = Players.LocalPlayer
local loadedIntroAnim = nil
local loadedLoopAnim = nil 

local isQTEActive = false 
local playerGui = player:WaitForChild("PlayerGui")
local qteGui = playerGui:WaitForChild("QTERadial")

-- New UI References
local radialContainer = qteGui:WaitForChild("RadialContainer")
local needle = radialContainer:WaitForChild("Needle")
local successZone = radialContainer:WaitForChild("SuccessZone")
local FButton = radialContainer:WaitForChild("FButton")
local sideFrame = qteGui:WaitForChild("SideFrame")
local FButtonSide = sideFrame:WaitForChild("FButtonSide")

-- SOUNDS -- 
local qteWarningSound = Instance.new("Sound")
qteWarningSound.SoundId = "rbxassetid://6042053626"
qteWarningSound.Volume = 1.5
qteWarningSound.Parent = game:GetService("SoundService")

-- New QTE Math Variables
local spinConnection = nil
local currentNeedleAngle = 0
local zoneStart = 0
local zoneEnd = 0
local SPIN_SPEED = 200 -- Degrees per second (Higher = Harder)

local repairSessionID = 0 

-- STATE TRACKING --
local activeGenerator = nil
local activeSlot = nil

-- ANIMATION PRELOADING -- 
local function onCharacterAdded(character)
	local humanoid = character:WaitForChild("Humanoid")
	local animator = humanoid:WaitForChild("Animator")

	local introObj = Instance.new("Animation")
	introObj.AnimationId = INTRO_ANIM_ID
	loadedIntroAnim = animator:LoadAnimation(introObj)
	loadedIntroAnim.Priority = Enum.AnimationPriority.Action 
	loadedIntroAnim.Looped = false 

	local loopObj = Instance.new("Animation")
	loopObj.AnimationId = LOOP_ANIM_ID
	loadedLoopAnim = animator:LoadAnimation(loopObj)
	loadedLoopAnim.Priority = Enum.AnimationPriority.Action 
	loadedLoopAnim.Looped = true 
end

if player.Character then onCharacterAdded(player.Character) end
player.CharacterAdded:Connect(onCharacterAdded)

-- HELPER FUNCTIONS -- 
local function attemptCancel()
	if player:GetAttribute("IsRepairing") == true then 

		-- Check if the generator is actually finished before failing the skillcheck
		if isQTEActive and activeGenerator and activeGenerator:GetAttribute("IsOverloaded") ~= true then
			local currentProgress = activeGenerator:GetAttribute("Progress") or 0

			if currentProgress >= MAX_PROGRESS then
				print("Skillcheck bypassed: Generator reached 100%!")
			else
				print("Cowardice detected! Skillcheck failed by walking away.")
				QTEFailedEvent:FireServer(activeGenerator)
			end
		end

		player:SetAttribute("IsRepairing", false)

		if loadedIntroAnim then loadedIntroAnim:Stop() end
		if loadedLoopAnim then loadedLoopAnim:Stop() end 

		if spinConnection then spinConnection:Disconnect() end
		radialContainer.Visible = false
		sideFrame.Visible = false
		isQTEActive = false

		RepairEvent:FireServer("Stop")

		-- Clear local targets
		activeGenerator = nil
		activeSlot = nil
	end
end

local function getClosestRepairable()
	local character = player.Character
	if not character then return nil, nil end 

	local root = character:FindFirstChild("HumanoidRootPart")
	if not root then return nil, nil end 

	local overlapParams = OverlapParams.new() 
	overlapParams.FilterDescendantsInstances = {character} 
	overlapParams.FilterType = Enum.RaycastFilterType.Include 

	for _, generator in ipairs(CollectionService:GetTagged("Repairable")) do
		local repairSlots = generator:FindFirstChild("RepairSlots")
		if not repairSlots then continue end 

		for _, slot in ipairs(repairSlots:GetChildren()) do 
			if slot:GetAttribute("IsOccupied") then continue end 

			local partsInSlot = workspace:GetPartsInPart(slot, overlapParams)

			if #partsInSlot > 0 then 
				return slot, generator 
			end
		end
	end

	return nil, nil 
end 

-- INPUT HANDLERS --
local function qteCheck()
	if isQTEActive then 
		isQTEActive = false 

		-- Stop the needle and hide UI
		if spinConnection then spinConnection:Disconnect() end
		radialContainer.Visible = false 

		-- THE VALIDATION MATH
		if currentNeedleAngle >= zoneStart and currentNeedleAngle <= zoneEnd then
			print("Skillcheck Nailed!")
		else
			print("Skillcheck Failed! Overloading...")
			QTEFailedEvent:FireServer(activeGenerator)
			attemptCancel()
		end

		return Enum.ContextActionResult.Sink
	end
end

local function handleQTEInput(actionName, inputState, inputObject)
	if inputState == Enum.UserInputState.Begin then 
		qteCheck()
	end
	return Enum.ContextActionResult.Pass
end

-- MOBILE BUTTONS -- 
if FButton:IsA("GuiButton") then 
	FButton.Activated:Connect(function()
		qteCheck()
	end)
end

if FButtonSide:IsA("GuiButton") then 
	FButtonSide.Activated:Connect(function()
		qteCheck()
	end)
end

local function handleInteraction(actionName, inputState, inputObject) 
	if inputState == Enum.UserInputState.Begin then 

		-- Check Master States First
		if player:GetAttribute("Role") ~= "Mechanic" or player:GetAttribute("RoundStatus") ~= "Alive" then
			return Enum.ContextActionResult.Pass
		end 

		local movementState = player:GetAttribute("MovementState") or "Normal"
		if movementState == "Crouching" or movementState == "Stunned" then 
			return Enum.ContextActionResult.Pass 
		end

		if player:GetAttribute("IsRepairing") == true then return Enum.ContextActionResult.Pass end 

		local character = player.Character
		if not character then return Enum.ContextActionResult.Pass end 

		local targetSlot, targetGenerator = getClosestRepairable()

		if targetSlot and targetGenerator then 
			if targetGenerator:GetAttribute("IsOverloaded") == true then return end 
			if targetGenerator:GetAttribute("Progress") == MAX_PROGRESS then return end

			-- Establish Local State
			player:SetAttribute("IsRepairing", true)
			activeGenerator = targetGenerator
			activeSlot = targetSlot

			local rootPart = character:FindFirstChild("HumanoidRootPart")
			if rootPart then 
				rootPart.CFrame = CFrame.new(rootPart.Position) * targetSlot.CFrame.Rotation
			end

			if loadedIntroAnim and loadedLoopAnim then 
				loadedIntroAnim:Play() 

				task.spawn(function()
					loadedIntroAnim.Stopped:Wait()
					if player:GetAttribute("IsRepairing") == true then 
						loadedLoopAnim:Play(0)
					end
				end)
			end

			RepairEvent:FireServer("Start", targetSlot, targetGenerator)

			-- THREAD HANDLING -- 
			repairSessionID = repairSessionID + 1 
			local mySession = repairSessionID 

			task.spawn(function()
				while player:GetAttribute("IsRepairing") == true and mySession == repairSessionID do
					local progress = targetGenerator:GetAttribute("Progress") or 0  
					local nextQTEWait 
					
					if progress > 60 then 
						nextQTEWait = math.random(2,4)
					else 
						nextQTEWait = math.random(3,8)
					end
					
					task.wait(nextQTEWait)

					if player:GetAttribute("IsRepairing") == false or mySession ~= repairSessionID then break end 

					print("QTE Triggered! Press F")
					
					qteWarningSound:Play()
					
					isQTEActive = true 
					radialContainer.Visible = true

					-- 1. Setup the Random Success Zone
					local zoneSize = 45 -- 45 degrees wide
					zoneStart = math.random(80, 270)
					zoneEnd = zoneStart + zoneSize

					successZone.Rotation = zoneStart 

					-- 2. Reset and Spin the Needle
					currentNeedleAngle = 0
					needle.Rotation = 0

					spinConnection = RunService.RenderStepped:Connect(function(deltaTime)
						if not isQTEActive then return end 

						currentNeedleAngle = currentNeedleAngle + (SPIN_SPEED * deltaTime)
						needle.Rotation = currentNeedleAngle

						-- 3. Timeout Failure
						if currentNeedleAngle >= 360 then
							isQTEActive = false
							spinConnection:Disconnect()
							radialContainer.Visible = false

							local currentProgress = activeGenerator:GetAttribute("Progress") or 0

							-- prevent timeout punishment if the generator is fully repaired
							if currentProgress >= MAX_PROGRESS then
								print("Skillcheck timeout ignored: Generator reached 100%!")
							else
								print("Skillcheck Timeout! Overloading...")
								QTEFailedEvent:FireServer(activeGenerator)
							end

							attemptCancel() 
						end
					end)

					-- 4. Yield the while loop until the player succeeds or fails
					repeat task.wait(0.1) until isQTEActive == false
				end

				if mySession == repairSessionID then 
					isQTEActive = false
					radialContainer.Visible = false 
				end 
			end)

			return Enum.ContextActionResult.Sink
		else 
			return Enum.ContextActionResult.Pass
		end
	end 
end

-- LISTENERS --
RunService.Heartbeat:Connect(function()
	if player:GetAttribute("IsRepairing") == true then
		local character = player.Character
		if not character then return end 

		local humanoid = character:FindFirstChild("Humanoid")
		local movementState = player:GetAttribute("MovementState") or "Normal"

		-- Cancel if they move, or if they are forced into a crouch/sprint/stun
		if (humanoid and humanoid.MoveDirection.Magnitude > 0) or (movementState ~= "Normal" and movementState ~= "Slowed") then 
			attemptCancel()
		end
	end
end)

player:GetAttributeChangedSignal("IsRepairing"):Connect(function()
	local isRepairing = player:GetAttribute("IsRepairing")

	if isRepairing == false then
		if loadedIntroAnim then loadedIntroAnim:Stop() end 
		if loadedLoopAnim then loadedLoopAnim:Stop() end 
		print("Animation Force Stopped (Task Complete)")

		sideFrame.Visible = false 
		qteGui.Enabled = false -- HIDE THE ENTIRE GUI WHEN DONE
	elseif isRepairing == true then 
		qteGui.Enabled = true -- SHOW THE GUI IMMEDIATELY
		sideFrame.Visible = true 
	end
end)

-- The Death Safety Net
player:GetAttributeChangedSignal("RoundStatus"):Connect(function()
	if player:GetAttribute("RoundStatus") ~= "Alive" then 
		attemptCancel()
	end
end)

local function setupRepairable(part)
	part:GetAttributeChangedSignal("IsOverloaded"):Connect(function()

		if part:GetAttribute("IsOverloaded") == true and activeGenerator == part then
			print("Machine overloaded! Kicking player off.")
			attemptCancel()
		end
	end)
end

for _, part in ipairs(CollectionService:GetTagged("Repairable")) do 
	setupRepairable(part)
end

CollectionService:GetInstanceAddedSignal("Repairable"):Connect(setupRepairable)

-- MAIN -- 
ContextActionService:BindAction("RepairInteract", handleInteraction, false, Enum.UserInputType.MouseButton1, Enum.UserInputType.Touch)
ContextActionService:BindAction("QTEReact", handleQTEInput, false, Enum.KeyCode.F)