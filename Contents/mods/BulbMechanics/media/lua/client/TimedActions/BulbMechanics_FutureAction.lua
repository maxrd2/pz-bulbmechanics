require "BulbMechanics"
require "TimedActions/ISBaseTimedAction"
require "ISTimedActionQueue"

-- action that will be created just before being executed in the future
-- IMPORTANT: "actionData.player" MUST contain reference to player object

BulbMechanics_FutureAction = ISBaseTimedAction:derive("BulbMechanics_FutureAction")

function BulbMechanics_FutureAction:isValid()
	return true;
end

function BulbMechanics_FutureAction:new(actionLambda, actionData)
	local o = {}
	setmetatable(o, self)
	self.__index = self
	o.character = actionData.player
	o.maxTime = 1;
	o.realActionLambda = actionLambda
	o.realActionData = actionData
	return o
end

function BulbMechanics_FutureAction:start()
	local que, act = ISTimedActionQueue.addAfter(self, self.realActionLambda(self.realActionData));
	if act == nil then
		BulbMechanics.error("FutureAction:begin() failed to queue action?!?")
	elseif que == nil then
		BulbMechanics.error("FutureAction:begin() queue is nil?!? " .. type(self.addAfter))
	else
		BulbMechanics.debug("FutureAction:begin() queued action " .. que:indexOf(act) .. " after " .. que:indexOf(self))
	end
-- 	ISBaseTimedAction.begin(self)
end