-- SERVICE --
local PathfindingService = game:GetService("PathfindingService")

local PatrolService = {}
PatrolService.__index = PatrolService

function PatrolService.new(npc, nodes)
	local self = setmetatable({}, PatrolService)
	
	self.NPC = npc 
	self.Humanoid = npc:WaitForChild("Humanoid")
	self.RootPart = npc:WaitForChild("HumanoidRootPart")
	
	self.Nodes = nodes 
	self.PatrollingConnection = nil 
end

function PatrolService:Patrol()
	local nodes = self.Nodes
	
	self.PatrollingConnection = task.spawn(function()
		local count = 1
		while true do
			local path = PathfindingService:CreatePath()
			local success, result = pcall(function()
				return path:ComputeAsync(self.RootPart.Position, nodes[count].Position)
			end)
			
			if not success then PatrolService:Patrol() return end 
			
			if success and path.Status == Enum.PathStatus.Success then
				for _, waypoint in path:GetWaypoints() do
					self.Humanoid:MoveTo(waypoint.Position)
					self.Humanoid.MoveToFinished:Wait()
				end 
				
				count += 1
				if count > #nodes then count = 1 end 
			end 
		end
	end)
end

return PatrolService
