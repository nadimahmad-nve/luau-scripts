-- Simple FSM in Luau

local AIEntity = {}
AIEntity.__index = AIEntity

function AIEntity.new()
	local self = setmetatable({}, AIEntity)
	self.CurrentState = "Patrolling"
	
	return self 
end

function AIEntity:ExecuteAction()
	if self.CurrentState == "Patrolling" then 
		print("AI is pacing back and forth")
	elseif self.CurrentState == "Chasing" then 
		print("AI is locked onto a target and pursuing")
	elseif self.CurrentState == "Stunned" then 
		print("AI is immobilised! Cannot act.")
	end
end

function AIEntity:SetState(newState, forceOverride) 
	if not forceOverride then
		if self.CurrentState == "Stunned" or self.CurrentState == newState then 
			return 
		end 
	end

	self.CurrentState = newState 
	self:ExecuteAction()
end 

function AIEntity:Stun(duration)
	self:SetState("Stunned")

	task.delay(duration, function()
		self:SetState("Patrolling", true)
	end)
end

return AIEntity
