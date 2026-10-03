local frameWidth = capWideScale(360, 400)
local frameX = SCREEN_WIDTH - frameWidth - 10
local frameY = 95

local t = Def.ActorFrame {
	BeginCommand = function(self)
		self:visible(false):queuecommand("Set")
		self:GetChild("GoalDisplay"):xy(frameX, frameY)
	end,
	OffCommand = function(self)
		self:decelerate(0.6):xy(SCREEN_WIDTH + 500, 0):diffusealpha(0)
		self:sleep(0.04):queuecommand("Invis")
	end,
	InvisCommand= function(self)
		self:visible(false)
	end,
	OnCommand = function(self)
		self:xy(SCREEN_WIDTH + 500, 0):decelerate(0.6):xy(0, 0):diffusealpha(1)
	end,
	SetCommand = function(self)
		self:finishtweening(1)
		if getTabIndex() == 6 then
			self:queuecommand("On")
			self:visible(true)
		else
			self:queuecommand("Off")
		end
	end,
	TabChangedMessageCommand = function(self)
		self:queuecommand("Set")
	end
}
t[#t + 1] = LoadActor("../GoalDisplay")

return t
