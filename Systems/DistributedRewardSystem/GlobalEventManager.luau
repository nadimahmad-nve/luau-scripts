local GlobalEventManager = {}

-- SERVICES -- 
local MemoryStoreService = game:GetService("MemoryStoreService")
local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")
local ServerStorage = game:GetService("ServerStorage")

-- EVENT STATE -- 
local GlobalEventStateStore = DataStoreService:GetDataStore("GlobalEventStates")
local PointsDatabase = DataStoreService:GetDataStore("PlayerPoints")

-- BINDABLE EVENT -- 
local RewardGrantedLive = ServerStorage:WaitForChild("BindableEvents"):WaitForChild("RewardGrantedLive")

-- SortedMap - shared across all servers 
GlobalEventManager.LeaderboardMap = MemoryStoreService:GetSortedMap("Event_Leaderboard")

-- This dictionary stores what points the player has earned since the last save 
GlobalEventManager.UnsavedPlayerPoints = {} -- Format [userId] = points 
GlobalEventManager.IsActive = true

-- END TIME -- 
local EVENT_END_TIME = 1787702400 -- Ends on 26th August 2026 

function GlobalEventManager:AddUnsavedPoints(userId, amount)
	if not self.IsActive then return end
	
	if self.UnsavedPlayerPoints[userId] then
		self.UnsavedPlayerPoints[userId] += amount
	else
		self.UnsavedPlayerPoints[userId] = amount
	end
end

local function SaveToMemoryStore(userId, pointsToAdd)
	-- Asynchronous so need pcall 
	local success, err = pcall(function()
		GlobalEventManager.LeaderboardMap:UpdateAsync(tostring(userId), function(currentGlobalScore)
			local score = currentGlobalScore or 0
			return score + pointsToAdd
		end, 2592000) 
	end)
	
	if not success then
		warn("failed to update MemoryStore for this user:", userId, err)
	end
end 

function GlobalEventManager:StartBatchingLoop()
	task.spawn(function()
		while task.wait(10) do
			if not self.IsActive then break end 
			
			local batchToSave = self.UnsavedPlayerPoints
			self.UnsavedPlayerPoints = {}

			for userId, pointsToAdd in pairs(batchToSave) do
				SaveToMemoryStore(userId, pointsToAdd)
			end
		end
	end)
end

function GlobalEventManager:CheckEventStatus()
	while task.wait(1) and self.IsActive do 
		if os.time() >= EVENT_END_TIME then 
			self.IsActive = false
			-- we need to save players points to the MemoryStore (final flush of data)
			for userId, pointsToAdd in pairs(self.UnsavedPlayerPoints) do
				SaveToMemoryStore(userId, pointsToAdd)
			end 
		end 
	end
	
	self:DistributeRewards()
end

function GlobalEventManager:DistributeRewards()
	local differentServerDistributing = false 
	
	local success, result = pcall(function()
		GlobalEventStateStore:UpdateAsync("Event_Rewards_Distributed", function(currentData)
			if currentData then 
				differentServerDistributing = true 
			end 
			
			return true 
		end)
	end)
	
	if not success then return end 
	
	if differentServerDistributing then 
		print("Different server handling the reward distribution")
		return 
	end
	
	-- If we get to this point, then this server is the lead server and will begin distributing the rewards 
	-- Get the top 10 players from the MemoryStore 
	local success, result = pcall(function()
		return GlobalEventManager.LeaderboardMap:GetRangeAsync(Enum.SortDirection.Descending, 10)
	end)
	
	if not success then 
		warn("failed to get leaderboard range")
		return 
	end
	
	-- Now we need to give the rewards to the players 
	for _, entry in pairs(result) do 
		local userId = tonumber(entry.key)
		local points = entry.value 
		
		local success, result = pcall(function()
			PointsDatabase:UpdateAsync(tostring(userId), function(currentData)
				if currentData then 
					currentData.PendingEventReward = true 
				end
				
				return currentData
			end)
		end)
		
		local player = Players:GetPlayerByUserId(userId)
		if player then
			print("Player is in the server: reward granted.")
			RewardGrantedLive:Fire(player)
		end
	end
end 

return GlobalEventManager
