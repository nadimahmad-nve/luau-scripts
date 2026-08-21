-- This BlinkModule creates an object to deal with the visuals and mathematics behind the blink ability. 

--local ReplicatedStorage = game:GetService("ReplicatedStorage")
local AbilityFramework = require((script.Parent :: any).AbilityFramework)

local Blink = setmetatable({}, AbilityFramework)
Blink.__index = Blink

function Blink.new(character)
	local self = AbilityFramework.new("Blink", 4, "Instant")

	setmetatable(self, Blink)

	self.Distance = 50 
	self.Character = character

	return self
end

function Blink:RunVisuals()
	if not self.Character or not self.Character:FindFirstChild("HumanoidRootPart") then return end
	self.LastUsed = os.clock()
	print("Blinking!")

	local hrp = self.Character.HumanoidRootPart

	-- Calculate the distance vector
	local movementVector = hrp.CFrame.LookVector * self.Distance

	-- Apply the movement 
	hrp.CFrame = hrp.CFrame + movementVector
end

function Blink:RunServerLogic()
	print("Processing Blink")
end

return Blink 