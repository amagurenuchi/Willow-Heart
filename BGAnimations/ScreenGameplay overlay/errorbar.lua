local player = PLAYER_1
local barCount = 30
local barWidth = 3
local barHeight = 10
local frameWidth = 300
local frameY = SCREEN_CENTER_Y + 112
local fadeTime = 0.75
local currentBar = 1
local bars = {}
local lastOffset
local lastColor = color("#FFFFFF")

local judgmentColors = {
	TapNoteScore_W1 = color("#77CCFF"),
	TapNoteScore_W2 = color("#FFDD44"),
	TapNoteScore_W3 = color("#55EE77"),
	TapNoteScore_W4 = color("#AA66FF"),
	TapNoteScore_W5 = color("#FF8833"),
	TapNoteScore_Miss = color("#FF4444"),
}

local function updateBar(self)
	if lastOffset == nil then return end
	self:stoptweening():x(SCREEN_CENTER_X + math.max(-frameWidth / 2, math.min(frameWidth / 2, lastOffset * 1.5)))
		:y(frameY):zoomto(barWidth, barHeight):diffuse(lastColor):diffusealpha(1)
	self:linear(fadeTime):diffusealpha(0)
end

local t = Def.ActorFrame {
	Name = "ErrorBar",
	InitCommand = function(self)
		self:xy(0, 0)
	end,
	OnCommand = function(self)
		for i = 1, barCount do
			bars[i] = self:GetChild("Bar" .. i)
		end
	end,
	JudgmentMessageCommand = function(self, params)
		if not params or params.Player ~= player then return end
		local score = tostring(params.TapNoteScore or params.Judgment or "")
		local offsetMs = params.TapNoteOffset and tonumber(params.TapNoteOffset) * 1000 or tonumber(params.Offset)
		if offsetMs == nil or score == "TapNoteScore_HitMine" or score == "TapNoteScore_None" then return end
		lastOffset = offsetMs
		lastColor = judgmentColors[score] or color("#FFFFFF")
		currentBar = (currentBar % barCount) + 1
		bars[currentBar]:playcommand("UpdateErrorBar")
	end,
	PracticeModeResetMessageCommand = function(self)
		for _, bar in ipairs(bars) do bar:diffusealpha(0) end
	end,
}

t[#t + 1] = Def.Quad {
		InitCommand = function(self)
			self:xy(SCREEN_CENTER_X, frameY):zoomto(barWidth, barHeight):diffuse(color("#FFFFFF")):diffusealpha(0.9)
		end,
	}

for i = 1, barCount do
	local bar = Def.Quad {
		Name = "Bar" .. i,
		InitCommand = function(self)
			self:diffusealpha(0)
		end,
		UpdateErrorBarCommand = updateBar,
	}
	bars[i] = bar
	t[#t + 1] = bar
end

return t
