local player = PLAYER_1
local lastTapNoteScore = "TapNoteScore_W2"
local displayMode = judgementDisplayMode and judgementDisplayMode() or "Minimal"

local function stats()
	local stage = STATSMAN:GetCurStageStats()
	return stage and stage:GetPlayerStageStats(player) or nil
end

local function scoreName(score)
	return tostring(score or "")
end

local function judgmentText(score)
	return ({
		TapNoteScore_W3 = "GREAT",
		TapNoteScore_W4 = "GOOD",
		TapNoteScore_W5 = "BAD",
		TapNoteScore_Miss = "MISS",
	})[scoreName(score)] or ""
end

local function currentCombo()
	local s = stats()
	return s and s.GetCurrentCombo and (tonumber(s:GetCurrentCombo()) or 0) or 0
end

local function maxCombo()
	local steps = GAMESTATE:GetCurrentSteps(player)
	if not steps then return 0 end
	local radar = steps:GetRadarValues(player)
	return radar and tonumber(radar:GetValue("RadarCategory_TapsAndHolds")) or 0
end

local function isFCOrHigher()
	local s = stats()
	if not s or not s.GetTapNoteScores then return false end
	return (tonumber(s:GetTapNoteScores("TapNoteScore_W4")) or 0) == 0
		and (tonumber(s:GetTapNoteScores("TapNoteScore_W5")) or 0) == 0
		and (tonumber(s:GetTapNoteScores("TapNoteScore_Miss")) or 0) == 0
end

local function currentClearType()
	local s = stats()
	if not s or not s.GetTapNoteScores then return "ClearType_FC" end
	local function count(name) return tonumber(s:GetTapNoteScores(name)) or 0 end
	local w1, w2, w3 = count("TapNoteScore_W1"), count("TapNoteScore_W2"), count("TapNoteScore_W3")
	if w2 == 0 and w3 == 0 then return "ClearType_MFC" end
	if w3 == 0 then return w2 == 1 and "ClearType_WF" or (w2 < 10 and "ClearType_SDP" or "ClearType_PFC") end
	return w3 == 1 and "ClearType_BF" or (w3 < 10 and "ClearType_SDG" or "ClearType_FC")
end

local function hideFallbackJudgment()
	local screen = SCREENMAN:GetTopScreen()
	local playerActor = screen and screen:GetChild("PlayerP1")
	local fallback = playerActor and playerActor:GetChild("Judgment")
	if fallback then fallback:visible(false) end
end

local function hideFallbackLifeBar()
	local screen = SCREENMAN:GetTopScreen()
	local meter = screen and screen.GetLifeMeter and screen:GetLifeMeter(player)
	if meter then meter:visible(false):diffusealpha(0) end
end

local function comboValue(params)
	if params then
		if params.PlayerStageStats and params.PlayerStageStats.GetCurrentCombo then
			return tonumber(params.PlayerStageStats:GetCurrentCombo()) or 0
		end
		if params.Combo ~= nil then return tonumber(params.Combo) or 0 end
		if params.OldCombo ~= nil then return tonumber(params.OldCombo) or 0 end
	end
	return currentCombo()
end

local comboTapScores = {
	TapNoteScore_W1 = true,
	TapNoteScore_W2 = true,
	TapNoteScore_W3 = true,
	TapNoteScore_W4 = true,
	TapNoteScore_W5 = true,
	TapNoteScore_Miss = true,
}

local function updateCombo(self, params)
	local tapScore = params and scoreName(params.TapNoteScore)
	if not tapScore or not comboTapScores[tapScore] or (params and params.HoldNoteScore) then return end
	if tapScore == "TapNoteScore_W4" or tapScore == "TapNoteScore_W5" or tapScore == "TapNoteScore_Miss" then
		self:stoptweening():settext(""):diffusealpha(0)
		return
	end
	local value = comboValue(params)
	-- The judgment message is emitted before CurrentCombo is updated.
	if tapScore == "TapNoteScore_W1" or tapScore == "TapNoteScore_W2" or tapScore == "TapNoteScore_W3" then
		value = value + 1
	end
	self:stoptweening()
	if value <= 0 then
		self:settext(""):diffusealpha(0)
		return
	end
	self:settext(tostring(value))
	self:diffuse(lastTapNoteScore == "TapNoteScore_W1" and color("#777777") or color("#FFFFFF"))
	self:diffusealpha(1):linear(0.8):diffusealpha(0.35)
end

local combo = LoadFont("multicolore  64px") .. {
	Name = "CustomCombo",
	InitCommand = function(self)
		self:xy(SCREEN_CENTER_X - 10, SCREEN_CENTER_Y - 150)
			:halign(0.5):valign(0.5):visible(displayMode == "Minimal"):diffusealpha(0)
	end,
	JudgmentMessageCommand = function(self, params)
		if not params or params.Player ~= player then return end
		hideFallbackJudgment()
		updateCombo(self, params)
	end,
}

local comboProgress = Def.Quad {
	Name = "ComboProgress",
	InitCommand = function(self)
		self:xy(SCREEN_CENTER_X, SCREEN_CENTER_Y - 106)
			:halign(0.5):valign(0.5):zoomto(100, 2):visible(false):diffuse(getClearTypeColor("ClearType_FC"))
	end,
	JudgmentMessageCommand = function(self, params)
		if displayMode ~= "Minimal" or not params or params.Player ~= player then return end
		local value = comboValue(params)
		local tapScore = scoreName(params.TapNoteScore)
		if tapScore == "TapNoteScore_W1" or tapScore == "TapNoteScore_W2" or tapScore == "TapNoteScore_W3" then
			value = value + 1
		end
		local maximum = maxCombo()
		local stillFC = tapScore ~= "TapNoteScore_W4" and tapScore ~= "TapNoteScore_W5" and tapScore ~= "TapNoteScore_Miss"
		self:diffuse(getClearTypeColor(currentClearType()))
			:visible(stillFC and isFCOrHigher() and maximum > 0 and value > maximum * 0.25)
	end,
}

local judgment = LoadFont("DFPGothic 64px") .. {
	Name = "CustomJudgment",
	InitCommand = function(self)
		self:xy(SCREEN_CENTER_X, SCREEN_CENTER_Y - 205)
			:halign(0.5):valign(0.5):zoom(0.5):visible(displayMode == "Minimal"):diffusealpha(0)
	end,
	JudgmentMessageCommand = function(self, params)
		if not params or params.Player ~= player then return end
		hideFallbackJudgment()
		lastTapNoteScore = scoreName(params.TapNoteScore)
		local text = judgmentText(params.TapNoteScore)
		self:stoptweening():settext(text):diffuse(color("#FFFFFF"))
		if text == "" then
			self:diffusealpha(0)
		else
			self:diffusealpha(1):sleep(0.45):linear(0.35):diffusealpha(0)
		end
	end,
}

local classicJudgmentFrames = {
	TapNoteScore_W1 = 0,
	TapNoteScore_W2 = 1,
	TapNoteScore_W3 = 2,
	TapNoteScore_W4 = 3,
	TapNoteScore_W5 = 4,
	TapNoteScore_Miss = 5,
}

local classicJudgment = Def.Sprite{
	Name = "ClassicJudgment",
	Texture = "../../../../" .. getAssetPath("judgment"),
	InitCommand = function(self)
		self:xy(SCREEN_CENTER_X, SCREEN_CENTER_Y + 40)
			:pause():visible(displayMode == "Classic"):diffusealpha(0)
	end,
	JudgmentMessageCommand = function(self, params)
		if displayMode ~= "Classic" or not params or params.Player ~= player or params.HoldNoteScore then return end
		local frame = classicJudgmentFrames[scoreName(params.TapNoteScore)]
		if frame == nil then return end
		if self:GetNumStates() == 12 then
			-- The asset is a 2-column by 6-row sheet:
			-- first column = early, second column = late.
			local earlyColumn = params.Early == true and 0 or 1
			frame = frame * 2 + earlyColumn
		end
		self:stoptweening():stopeffect():setstate(frame):visible(true):diffusealpha(1)
		self:sleep(0.8):linear(0.1):diffusealpha(0)
	end,
}

local classicCombo = Def.ActorFrame{
	Name = "ClassicCombo",
	InitCommand = function(self)
		self:xy(SCREEN_CENTER_X + 30, SCREEN_CENTER_Y - 20):visible(displayMode == "Classic")
	end,
	JudgmentMessageCommand = function(self, params)
		if displayMode ~= "Classic" or not params or params.Player ~= player then return end
		self:playcommand("UpdateCombo", params)
	end,
	ComboChangedMessageCommand = function(self, params)
		if displayMode ~= "Classic" or not params or params.Player ~= player then return end
		self:playcommand("UpdateCombo", params)
	end,
	ComboCommand = function(self, params)
		if displayMode ~= "Classic" then return end
		self:playcommand("UpdateCombo", params)
	end,
	UpdateComboCommand = function(self, params)
		local value = comboValue(params)
		local tapScore = params and scoreName(params.TapNoteScore)
		if tapScore == "TapNoteScore_W1" or tapScore == "TapNoteScore_W2" or tapScore == "TapNoteScore_W3" then
			value = value + 1
		end
		local number = self:GetChild("Number")
		local label = self:GetChild("Label")
		if value <= 0 then
			number:settext(""):diffusealpha(0)
			label:visible(false)
			return
		end
		number:settext(tostring(value)):diffusealpha(1)
		label:visible(true)
		if params and params.FullComboW1 then
			number:diffuse(color("#FFFFFF"))
		elseif params and params.FullComboW2 then
			number:diffuse(color("#FFCC33"))
		elseif params and params.FullComboW3 then
			number:diffuse(color("#66FF88"))
		else
			number:diffuse(color("#FFFFFF"))
		end
		number:stoptweening():sleep(0.5):linear(0.35):diffusealpha(0.45)
	end,
	LoadFont("Common Large") .. {
		Name = "Number",
		InitCommand = function(self)
			self:x(-4):halign(1):valign(1):zoom(0.5):diffuse(color("#FFFFFF")):diffusealpha(0)
		end,
	},
	LoadFont("Common Normal") .. {
		Name = "Label",
		InitCommand = function(self)
			self:x(2):halign(0):valign(1):zoom(0.6):diffuse(color("#FFFFFF"))
				:settext("COMBO")
		end,
	},
}

local function updateAverage(self)
	local s = stats()
	if not s then self:settext("0.00%") return end
	if s.GetCurWifeScore and s.GetMaxWifeScore then
		local max = tonumber(s:GetMaxWifeScore()) or 0
		if max > 0 then self:settextf("%.2f%%", (s:GetCurWifeScore() / max) * 100) else self:settext("0.00%") end
	else
		self:settext("0.00%")
	end
end

local function updateAccumulated(self)
	local s = stats()
	if not s or not s.GetWifeScore then self:settext("0.00%") return end
	self:settextf("%.2f%%", s:GetWifeScore() * 100)
end

local wife = Def.ActorFrame{
	Name = "WifePercent",
	InitCommand = function(self)
		self:GetChild("Average"):playcommand("Update")
		self:GetChild("Accumulated"):playcommand("Update")
	end,
	JudgmentMessageCommand = function(self, params)
		if not params or params.Player ~= player then return end
		self:GetChild("Average"):playcommand("Update")
		self:GetChild("Accumulated"):playcommand("Update")
	end,
	LoadFont("hatsukoifriendsmini 24px") .. {
		Name = "Average",
		InitCommand = function(self)
			self:xy(SCREEN_CENTER_X, SCREEN_CENTER_Y):halign(0.5):valign(0.5):diffuse(color("#FFFFFF")):settext("0.00%")
		end,
		UpdateCommand = function(self)
			updateAverage(self)
		end,
	},
	LoadFont("hatsukoifriendsmini 24px") .. {
		Name = "Accumulated",
		InitCommand = function(self)
			self:xy(24, SCREEN_HEIGHT - 24):halign(0):valign(1):zoom(1.5):diffuse(color("#FFFFFF")):settext("0.00%")
		end,
		UpdateCommand = function(self)
			updateAccumulated(self)
		end,
	},
}

wife.BeginCommand = function(self)
	self:GetChild("Average"):settext("0.00%")
	self:GetChild("Accumulated"):settext("0.00%")
end

return Def.ActorFrame{
	-- Keep the stage-information handoff, but consume it when gameplay was
	-- entered from Stage Information so this cannot redirect in a loop.
	OnCommand = function(self)
		hideFallbackJudgment()
		hideFallbackLifeBar()
		if _G.willowHeartStageInformationShown then
			_G.willowHeartStageInformationShown = false
			return
		end
		local screen = SCREENMAN:GetTopScreen()
		if screen then
			screen:SetNextScreenName("ScreenStageInformation")
			screen:StartTransitioningScreen("SM_GoToNextScreen")
		end
	end,
	combo,
	comboProgress,
	judgment,
	classicJudgment,
	classicCombo,
	wife,
	LoadActor("judgecounter.lua"),
	LoadActor("errorbar.lua"),
	LoadActor("custom_lifebar.lua"),
	LoadActor("songinfo.lua"),
	LoadActor("progresscircle.lua"),
}
