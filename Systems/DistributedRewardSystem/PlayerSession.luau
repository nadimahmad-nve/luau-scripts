local PlayerSession = {}
PlayerSession.__index = PlayerSession

-- SERVICES -- 
local ServerScriptService = game:GetService("ServerScriptService")

-- GLOBAL EVENT MODULE -- 
local GlobalEventManager = require((script.Parent :: any).GlobalEventManager)

function PlayerSession.new(player, data)
	local self = setmetatable({}, PlayerSession)

	self.Player = player
	self.TotalPoints = data.TotalPoints
	self.PendingEventReward = data.PendingEventReward or false

	return self
end

function PlayerSession:AddPoints(amount)
	if not GlobalEventManager.IsActive then return end 
	
	self.TotalPoints += amount
	
	local leaderstats = self.Player:FindFirstChild("leaderstats")
	if leaderstats and leaderstats:FindFirstChild("Points") then
		leaderstats.Points.Value = self.TotalPoints
	end

	-- Send to global event manager to save to MemoryStore
	GlobalEventManager:AddUnsavedPoints(self.Player.UserId, amount)
end

return PlayerSession