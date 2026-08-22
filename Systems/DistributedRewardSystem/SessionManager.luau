local SessionManager = {}

-- SERVICES -- 
local ServerScriptService = game:GetService("ServerScriptService")
local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")
local ServerStorage = game:GetService("ServerStorage")

-- MODULES -- 
local PlayerSession = require((script.Parent :: any).PlayerSession)
local PointsDatabase = DataStoreService:GetDataStore("PlayerPoints")

-- BINDABLE EVENT -- 
local RewardGrantedLive = ServerStorage:WaitForChild("BindableEvents"):WaitForChild("RewardGrantedLive")

function SessionManager.GetSession(player)	
	return SessionManager[player]
end

function SessionManager.LoadProfile(player)
	local data 
	
	local success, err = pcall(function()
		data = PointsDatabase:GetAsync(tostring(player.UserId))
	end)
	
	if not success then 
		player:Kick("Data failed to load - rejoin please")
		return 
	end
	
	if data == nil then 
		data = {TotalPoints = 0, PendingEventReward = false}
	end
	
	SessionManager[player] = PlayerSession.new(player, data)
	
	-- LEADERSTATS --
	local leaderstats = Instance.new("Folder")
	leaderstats.Name = "leaderstats" 
	leaderstats.Parent = player

	local pointsValue = Instance.new("IntValue")
	pointsValue.Name = "Points" 
	pointsValue.Value = data.TotalPoints
	pointsValue.Parent = leaderstats
	
	if data.PendingEventReward then 
		print("Player has pending event reward - reward granted.")
		SessionManager[player].PendingEventReward = false 
		
		local success, err = pcall(function()
			PointsDatabase:UpdateAsync(tostring(player.UserId), function(currentData)
				currentData.PendingEventReward = false 
				
				return currentData
			end)
		end)
	end
end

function SessionManager.SaveProfile(player)
	local playerSession = SessionManager.GetSession(player)
	
	local success, err = pcall(function()
		PointsDatabase:UpdateAsync(tostring(player.UserId), function(currentData)
			
			-- cache coherence
			local pendingRewardResult = playerSession.PendingEventReward
			if currentData and currentData.PendingEventReward == true then
				pendingRewardResult = true
			end
			
			return {TotalPoints = playerSession.TotalPoints,
				PendingEventReward = pendingRewardResult
			} 
		end)
	end)
end

Players.PlayerAdded:Connect(function(player)
	SessionManager.LoadProfile(player)
end)

Players.PlayerRemoving:Connect(function(player)
	SessionManager.SaveProfile(player)
	
	-- Memory cleanup
	SessionManager[player] = nil
end)

game:BindToClose(function()
	for _, player in pairs(Players:GetPlayers()) do
		SessionManager.SaveProfile(player)			
	end
end)

RewardGrantedLive.Event:Connect(function(player)
	local session = SessionManager.GetSession(player)
	if session then
		session.PendingEventReward = false
		print("live session flag cleared (via the BindableEvent)")
	end
end)

-- This loop auto-saves every 60 seconds 
task.spawn(function()
	while task.wait(60) do
		for _, player in pairs(Players:GetPlayers()) do
			SessionManager.SaveProfile(player)
		end
	end
end)


return SessionManager
