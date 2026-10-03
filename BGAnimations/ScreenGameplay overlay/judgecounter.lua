local player = PLAYER_1

local judgmentOrder = {
	"TapNoteScore_W1",
	"TapNoteScore_W2",
	"TapNoteScore_W3",
	"TapNoteScore_W4",
	"TapNoteScore_W5",
	"TapNoteScore_Miss",
}

local labels = {
	TapNoteScore_W1 = "MARV",
	TapNoteScore_W2 = "PERF",
	TapNoteScore_W3 = "GREAT",
	TapNoteScore_W4 = "GOOD",
	TapNoteScore_W5 = "BAD",
	TapNoteScore_Miss = "MISS",
}

local counts = {}
for _, judgment in ipairs(judgmentOrder) do counts[judgment] = 0 end

local function resetCounts()
	for _, judgment in ipairs(judgmentOrder) do counts[judgment] = 0 end
end

local function updateCounts(self, latestJudgment)
	local stage = STATSMAN:GetCurStageStats()
	local stats = stage and stage:GetPlayerStageStats(player)
	if not stats or not stats.GetTapNoteScores then return end
	for _, judgment in ipairs(judgmentOrder) do
		counts[judgment] = tonumber(stats:GetTapNoteScores(judgment)) or counts[judgment]
		-- JudgmentMessageCommand fires before the stage stats include the tap.
		if judgment == latestJudgment then counts[judgment] = counts[judgment] + 1 end
		self:GetChild(judgment):settext(tostring(counts[judgment]))
	end
end

local t = Def.ActorFrame {
	Name = "JudgeCounter",
	InitCommand = function(self)
		self:xy(SCREEN_WIDTH - 78, SCREEN_HEIGHT - 166)
	end,
	BeginCommand = function(self)
		resetCounts()
		updateCounts(self)
	end,
	JudgmentMessageCommand = function(self, params)
		if not params or params.Player ~= player then return end
		updateCounts(self, params.TapNoteScore)
	end,
	PracticeModeResetMessageCommand = function(self)
		resetCounts()
		updateCounts(self)
	end,
	Def.Quad {
		InitCommand = function(self)
			self:halign(0.5):valign(0.5):zoomto(116, 94):diffuse(0, 0, 0, 0.48)
		end,
	},
}

for i, judgment in ipairs(judgmentOrder) do
	local y = -40 + (i - 1) * 16
	t[#t + 1] = LoadFont("Common Normal") .. {
		Name = judgment .. "Label",
		InitCommand = function(self)
			self:xy(-52, y):halign(0):zoom(0.30):diffuse(GetJudgementColor(judgment)):settext(labels[judgment])
		end,
	}
	t[#t + 1] = LoadFont("Common Normal") .. {
		Name = judgment,
		InitCommand = function(self)
			self:xy(52, y):halign(1):zoom(0.34):diffuse(color("#FFFFFF")):settext("0")
		end,
	}
end

return t
