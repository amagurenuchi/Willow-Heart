-- Willow Heart evaluation screen.


local pn = PLAYER_1
local stageStats = nil
local pss = nil
local score = nil
local song = nil
local steps = nil
local rate = 1
local offsets = {}
local tracks = {}
local noteRows = {}
local noteTypes = {}
local selectedColumn = 0 -- 0 = all columns, 1..N = selected column
local selectedJudge = GetTimingDifficulty()
local leaderboardPage = 1
local leaderboard = {}
local statRefreshActor = nil
local customTimingWindows = false
local plotLargestHit = false
local plotActorCapacity = 2000

-- Evaluation can load without the normal theme script bootstrap.
if not GetGradeForPercent then
	dofile(THEME:GetPathS("Scripts", "03 Grades.lua"))
end

-- Visual helper for judgement color
local function judgementColor(judgement)
	local colors = COLOR and COLOR.JudgementColors
	return color(colors and colors[tostring(judgement)] or "#4C4C4C")
end

local function call(object, method, fallback, ...)
	if object and object[method] then
		local ok, value = pcall(object[method], object, ...)
		if ok and value ~= nil then return value end
	end
	return fallback
end

local function getScore()
	local recent = SCOREMAN:GetMostRecentScore()
	if recent then return recent end
	local temp = SCOREMAN:GetTempReplayScore()
	if temp then return temp end
	return call(pss, "GetHighScore", nil)
end

local function loadReplayVectors()
	offsets, tracks, noteRows, noteTypes = {}, {}, {}, {}
	local replay = REPLAYS and REPLAYS:GetActiveReplay()
	local sources = { replay, score, pss }
	for _, source in ipairs(sources) do
		if source then
			local ok, o, t, n, ty = pcall(function()
				return source:GetOffsetVector(), source:GetTrackVector(), source:GetNoteRowVector(), source:GetTapNoteTypeVector()
			end)
			if ok and o then
				if o and #o > 0 then
					offsets = o
					tracks = t or {}
					noteRows = n or {}
					noteTypes = ty or {}
					return
				end
			end
		end
	end
end

local function wifePercentFor(vector)
	if not vector or #vector == 0 then return 0 end
	if getRescoredWife3Judge then
		local ok, result = pcall(function()
			return getRescoredWife3Judge(3, selectedJudge, {
				dvt = vector,
				totalTaps = #vector,
				totalHolds = 0,
				holdsHit = 0,
				holdsMissed = 0,
				minesHit = 0,
			})
		end)
		if ok and result then return result end
	end
	local valid = 0
	local total = 0
	for _, value in ipairs(vector) do
		if value ~= 1000 and value ~= -1100 then
			total = total + value
			valid = valid + 1
		end
	end
	if valid == 0 then return 0 end
	local mean = total / valid
	return math.max(0, 100 - math.abs(mean) / 22.5 * 5)
end

local function judgeScale()
	return ms and ms.JudgeScalers and ms.JudgeScalers[selectedJudge] or 1
end

local function timingCutoffs()
	local scale = judgeScale()
	if customTimingWindows then
		if type(getCurrentCustomWindowConfigJudgmentWindowTable) == "function" then
			local ok, configured = pcall(getCurrentCustomWindowConfigJudgmentWindowTable)
			if ok and type(configured) == "table" then
				return {
					configured.TapNoteScore_W1 or 22.5,
					configured.TapNoteScore_W2 or 45,
					configured.TapNoteScore_W3 or 90,
					configured.TapNoteScore_W4 or 135,
					configured.TapNoteScore_W5 or 180,
				}
			end
		end
		-- Keep the screen usable with fallback bundles predating custom windows.
		return {22.5 * scale, 45 * scale, 90 * scale, 135 * scale, 180 * scale}
	end
	return {22.5 * scale, 45 * scale, 90 * scale, 135 * scale, 180}
end

local function setCustomTimingWindows(enabled)
	if enabled and type(loadCurrentCustomWindowConfig) == "function" then
		local ok = pcall(loadCurrentCustomWindowConfig)
		customTimingWindows = ok
	elseif not enabled and type(unloadCustomWindowConfig) == "function" then
		pcall(unloadCustomWindowConfig)
		customTimingWindows = false
	else
		customTimingWindows = enabled
	end
end

local function customTimingWindowName()
	if type(getCurrentCustomWindowConfigName) == "function" then
		local ok, name = pcall(getCurrentCustomWindowConfigName)
		if ok and name then return tostring(name) end
	end
	return "CUSTOM"
end

local function splitHandData(hand)
	local columns = steps and call(steps, "GetNumColumns", 4) or 4
	local middle = columns / 2
	local result = {}
	for i, value in ipairs(offsets) do
		local column = tracks[i]
		if column and ((hand == "LEFT" and column < middle) or (hand == "RIGHT" and column >= middle)) then
			result[#result + 1] = value
		end
	end
	return result
end

local function comboBreaksFor(hand)
	local columns = steps and call(steps, "GetNumColumns", 4) or 4
	local middle = columns / 2
	local threshold = timingCutoffs()[3]
	local breaks = 0
	for i, value in ipairs(offsets) do
		local column = tracks[i]
		local belongs = hand == "LEFT" and column and column < middle or hand == "RIGHT" and column and column >= middle
		if belongs and math.abs(value) > threshold then breaks = breaks + 1 end
	end
	return breaks
end

local function columnStats(column)
	local values = {}
	for i, value in ipairs(offsets) do
		if selectedColumn == 0 or tracks[i] == selectedColumn - 1 then
			values[#values + 1] = value
		end
	end
	return values
end

local function formatRatio(a, b)
	if b == 0 then return a > 0 and "∞:1" or "0:1" end
	return string.format("%.2f:1", a / b)
end

local function statOffsets()
	local values = {}
	local missWindow = timingCutoffs()[5]
	for _, value in ipairs(offsets) do
		if math.abs(tonumber(value) or math.huge) < missWindow then values[#values + 1] = value end
	end
	return values
end

local function offsetMean()
	local values = statOffsets()
	return #values > 0 and wifeMean(values) or 0
end

local function offsetSd()
	local values = statOffsets()
	return #values > 1 and wifeSd(values) or 0
end

local function offsetMax()
	local values = statOffsets()
	local largest = 0
	for _, value in ipairs(values) do largest = math.max(largest, math.abs(tonumber(value) or 0)) end
	return largest
end

local getWife

local function getGrade()
	local sourceGrade = call(score, "GetWifeGrade", call(score, "GetGrade", nil))
	if tostring(sourceGrade) == "Grade_Failed" then return "Grade_Failed" end
	return GetGradeForPercent(getWife() * 100)
end

local function rescoredCounts()
	local c = {0, 0, 0, 0, 0, 0}
	local w = timingCutoffs()
	for _, value in ipairs(offsets) do
		local a = math.abs(tonumber(value) or math.huge)
		local j = a <= w[1] and 1 or a <= w[2] and 2 or a <= w[3] and 3 or a <= w[4] and 4 or a <= w[5] and 5 or 6
		c[j] = c[j] + 1
	end
	return c
end

local function rescoredMaxCombo()
	local w = timingCutoffs()[3]
	local best, current = 0, 0
	for _, value in ipairs(offsets) do
		if math.abs(tonumber(value) or math.huge) <= w then current = current + 1; best = math.max(best, current) else current = 0 end
	end
	return best
end

getWife = function()
	-- ReplayManager's custom callbacks do not expose a rescored percentage on
	-- every engine build. Reproduce the fallback config's tap score here so the
	-- displayed percentage still changes when the selected config changes.
	if customTimingWindows and customWindowsConfig and getCurrentCustomWindowConfig then
		local ok, config = pcall(function()
			return customWindowsConfig:get_data().customWindowConfigs[getCurrentCustomWindowConfig()]
		end)
		if ok and type(config) == "table" and #offsets > 0 then
			local windows = timingCutoffs()
			local worths = config.customWindowWorths
			local total, maxTap = 0, 2
			if config.customWindowTapNoteTypeWorths and config.customWindowTapNoteTypeWorths.Tap then
				maxTap = config.customWindowTapNoteTypeWorths.Tap
			end
			for _, offset in ipairs(offsets) do
				local absOffset = math.abs(tonumber(offset) or math.huge)
				local scoreValue
				if config.customWindowCurveFunction then
					scoreValue = config.customWindowCurveFunction((tonumber(offset) or 0) / 1000)
				elseif worths then
					local key = absOffset <= windows[1] and "W1" or absOffset <= windows[2] and "W2" or
						absOffset <= windows[3] and "W3" or absOffset <= windows[4] and "W4" or
						absOffset <= windows[5] and "W5" or "Miss"
					scoreValue = worths[key] or 0
				end
				total = total + (tonumber(scoreValue) or 0)
			end
			return math.max(0, total / (#offsets * maxTap))
		end
	end
	if getRescoredWife3Judge and #offsets > 0 then
		local ok, result = pcall(function()
			return getRescoredWife3Judge(3, selectedJudge, {
				dvt = offsets, totalTaps = #offsets, totalHolds = 0,
				holdsHit = 0, holdsMissed = 0, minesHit = 0,
			})
		end)
		if ok and result then return result > 1 and result / 100 or result end
	end
	if #offsets > 0 and wife3 and ms and ms.JudgeScalers then
		local scale = ms.JudgeScalers[selectedJudge] or 1
		local total = 0
		for _, value in ipairs(offsets) do
			local ok, result = pcall(wife3, math.abs(value), scale, "Wife3")
			if ok and result then total = total + result end
		end
		return total / #offsets
	end
	local value = call(score, "GetWifeScore", nil)
	if value == nil then value = call(pss, "GetWifeScore", 0) end
	return value > 1 and value / 100 or value
end

local function getJ4Wife()
	if #offsets == 0 or not getRescoredWife3Judge then return 0 end
	local ok, result = pcall(function()
		return getRescoredWife3Judge(3, 4, {
			dvt = offsets, totalTaps = #offsets, totalHolds = 0,
			holdsHit = 0, holdsMissed = 0, minesHit = 0,
		})
	end)
	if not ok or not result then return 0 end
	return result > 1 and result / 100 or result
end

local function getClear()
	if not steps or not pss then return "", COLOR.TextSub2 end
	local clear = getClearType(pn, steps, score or pss)
	return getClearTypeText(clear), getClearTypeColor(clear)
end

local function refreshState()
	stageStats = STATSMAN:GetCurStageStats()
	pss = stageStats and stageStats:GetPlayerStageStats(pn) or nil
	song = GAMESTATE:GetCurrentSong()
	steps = GAMESTATE:GetCurrentSteps(pn)
	score = getScore()
	local options = GAMESTATE:GetSongOptionsObject("ModsLevel_Current")
	rate = options and options.MusicRate and options:MusicRate() or call(score, "GetMusicRate", 1)
	loadReplayVectors()
	_G.WillowEvaluationOffsetData = {
		offsets = offsets, tracks = tracks, noteRows = noteRows, noteTypes = noteTypes,
		lastSecond = song and call(song, "GetLastSecond", 1) or 1,
	}
	local ok, scores
	if type(getScoreTable) == "function" then
		ok, scores = pcall(getScoreTable, pn, rate, steps)
	else
		local rateTable = type(getRateTable) == "function" and getRateTable() or nil
		local rateKeys = {string.format("%.1fx", rate), string.format("%.2fx", rate), "1.0x"}
		if rateTable then
			for _, key in ipairs(rateKeys) do
				if rateTable[key] then scores = rateTable[key]; break end
			end
		end
		ok = true
	end
	if not scores and type(getRateTable) == "function" then
		local rateTable = getRateTable()
		if rateTable then
			for _, key in ipairs({string.format("%.1fx", rate), string.format("%.2fx", rate), "1.0x"}) do
				if rateTable[key] then scores = rateTable[key]; break end
			end
		end
	end
	leaderboard = (ok and scores) or {}
	leaderboardPage = math.max(1, math.min(leaderboardPage, math.max(1, math.ceil(#leaderboard / 5))))
end

-- Enhanced Glassmorphic Card Container
local function card(width, height, title)
	local frame = Def.ActorFrame{}
	frame[#frame + 1] = Def.Quad{ InitCommand=function(self) self:xy(4,4):zoomto(width,height):diffuse(COLOR.MainHighlight):diffusealpha(0.35) end }
	frame[#frame + 1] = Def.Quad{ InitCommand=function(self) self:zoomto(width,height):diffuse(COLOR.MainBackground):diffusealpha(0.96) end }
	frame[#frame + 1] = Def.Quad{ InitCommand=function(self) self:zoomto(width-4,height-4):diffuse(COLOR.MainBorder):diffusealpha(0.04) end }
	frame[#frame + 1] = UIElements.Border(width,height,1)..{ InitCommand=function(self) self:diffuse(COLOR.MainBorder):diffusealpha(0.65) end }
	if title and title ~= "" then
		frame[#frame + 1] = LoadFont("Common Normal")..{ InitCommand=function(self) self:xy(-width/2+16,-height/2+16):halign(0):zoom(0.42):diffuse(COLOR.TextSub2):settext(title) end }
	end
	return frame
end

local railWidth = math.min(440, math.max(360, SCREEN_WIDTH * 0.32))
local gap = 16
local left = 24
local right = SCREEN_WIDTH - 24
local mainRight = right - railWidth - gap
local mainWidth = mainRight - left
local railX = mainRight + gap + railWidth / 2

local t = Def.ActorFrame{
	OnCommand = function(self)
		setCustomTimingWindows(false)
		refreshState()
		self:playcommand("RefreshEvaluation")
	end,
	RefreshEvaluationMessageCommand = function(self)
		refreshState()
		self:RunCommandsOnChildren(function(actor)
			actor:playcommand("RefreshEvaluation")
		end)
	end,
	InsertCoinMessageCommand = function(self)
		setCustomTimingWindows(not customTimingWindows)
		self:playcommand("RefreshEvaluation")
	end,
}

t[#t+1] = StandardDecorationFromFileOptional("Header", "Header")

-- Upper-left song metadata header card.
local metadataW = mainWidth
local metadataH = 106
local metadata = card(metadataW, metadataH, "")
metadata.InitCommand = function(self) self:xy(left + metadataW/2, 122) end

-- Main Song Title
metadata[#metadata+1] = LoadFont("DFPGothic 64px")..{
	InitCommand=function(self) self:xy(-metadataW/2+20,-28):halign(0):zoom(0.42):maxwidth((metadataW-40)/0.42):diffuse(COLOR.TextMain) end,
	RefreshEvaluationCommand=function(self) self:settext(song and song:GetDisplayMainTitle() or "No Song Selected") end,
}
-- Subtitle / Artist
metadata[#metadata+1] = LoadFont("Common Normal")..{
	InitCommand=function(self) self:xy(-metadataW/2+20,2):halign(0):zoom(0.46):maxwidth((metadataW-40)/0.46):diffuse(COLOR.TextSub1) end,
	RefreshEvaluationCommand=function(self)
		local artist = song and song:GetDisplayArtist() or "Unknown Artist"
		local subtitle = song and song:GetDisplaySubTitle() or ""
		self:settext(subtitle ~= "" and subtitle.." - "..artist or "// "..artist)
	end,
}

-- Difficulty & Rate Pill Badges Container
local badgeFrame = Def.ActorFrame{ InitCommand=function(self) self:xy(-metadataW/2+20, 29) end }

-- Difficulty Pill Badge
badgeFrame[#badgeFrame+1] = Def.Quad{
	Name="DiffBg",
	InitCommand=function(self) self:xy(45,0):zoomto(90,20):diffuse(color("#4C4C4C")) end,
}
badgeFrame[#badgeFrame+1] = UIElements.Border(90,20,1)..{
	Name="DiffBorder",
	InitCommand=function(self) self:xy(45,0):diffuse(color("#FFFFFF")):diffusealpha(0.3) end,
}
badgeFrame[#badgeFrame+1] = LoadFont("Common Normal")..{
	Name="DiffText",
	InitCommand=function(self) self:xy(45,0):zoom(0.36):diffuse(color("#FFFFFF")) end,
	RefreshEvaluationCommand=function(self)
		local diff = steps and steps:GetDifficulty() or ""
		local meter = steps and steps:GetMeter() or 0
		local diffStr = ToEnumShortString(diff)
		if diffStr ~= "" then
			self:settextf("%s %d", string.upper(diffStr), meter)
			local c = GetDifficultyColor(diff)
			self:GetParent():GetChild("DiffBg"):diffuse(c)
		else
			self:settext("STANDARD")
		end
	end,
}

-- Music Rate Pill Badge
badgeFrame[#badgeFrame+1] = Def.Quad{
	InitCommand=function(self) self:xy(120,0):zoomto(50,20):diffuse(COLOR.MainBorder):diffusealpha(0.6) end,
}
badgeFrame[#badgeFrame+1] = UIElements.Border(50,20,1)..{
	InitCommand=function(self) self:xy(120,0):diffuse(COLOR.MainBorder) end,
}
badgeFrame[#badgeFrame+1] = LoadFont("Common Normal")..{
	InitCommand=function(self) self:xy(120,0):zoom(0.36):diffuse(COLOR.TextMainLight) end,
	RefreshEvaluationCommand=function(self)
		self:settextf("%.2fx", rate)
	end,
}

-- Pack Name metadata label
badgeFrame[#badgeFrame+1] = LoadFont("Common Normal")..{
	InitCommand=function(self) self:xy(160,0):halign(0):zoom(0.38):diffuse(COLOR.TextSub2) end,
	RefreshEvaluationCommand=function(self)
		local packStr = song and song:GetGroupName() or "Standard"
		self:settextf("|   Pack: %s", packStr)
	end,
}
metadata[#metadata+1] = badgeFrame

-- Upper-right banner and MSD/SSR card.
local bannerW, bannerH = railWidth, metadataH
local banner = card(bannerW, bannerH, "")
banner.InitCommand = function(self) self:xy(railX, 122) end

banner[#banner+1] = Def.Quad{
	InitCommand=function(self) self:xy(-bannerW/2+80,0):zoomto(144,78):diffuse(COLOR.MainBorder):diffusealpha(0.25) end,
}
banner[#banner+1] = Def.Sprite{
	InitCommand=function(self) self:xy(-bannerW/2+80,0) end,
	RefreshEvaluationCommand=function(self)
		if song and song:HasBanner() then self:LoadBackground(song:GetBannerPath()); self:scaletoclipped(142,76); self:visible(true) else self:visible(false) end
	end,
}

-- MSD Rating Pill Box
local msdBox = Def.ActorFrame{ InitCommand=function(self) self:xy(bannerW/2-75,-18) end }
msdBox[#msdBox+1] = Def.Quad{ InitCommand=function(self) self:zoomto(120,30):diffuse(COLOR.MainBackground):diffusealpha(0.8) end }
msdBox[#msdBox+1] = UIElements.Border(120,30,1)..{ InitCommand=function(self) self:diffuse(COLOR.MainBorder):diffusealpha(0.4) end }
msdBox[#msdBox+1] = LoadFont("Common Normal")..{ InitCommand=function(self) self:xy(-52,0):halign(0):zoom(0.32):diffuse(COLOR.TextSub2):settext("MSD") end }
msdBox[#msdBox+1] = LoadFont("DFPGothic 64px")..{
	InitCommand=function(self) self:xy(52,0):halign(1):zoom(0.42):maxwidth(85/0.42) end,
	RefreshEvaluationCommand=function(self)
		local value = steps and call(steps,"GetMSD",0,rate,1) or 0
		self:settextf("%.2f",value):diffuse(GetRatingColor(value))
	end,
}
banner[#banner+1] = msdBox

-- SSR Skillscore Pill Box
local ssrBox = Def.ActorFrame{ InitCommand=function(self) self:xy(bannerW/2-75,20) end }
ssrBox[#ssrBox+1] = Def.Quad{ InitCommand=function(self) self:zoomto(120,30):diffuse(COLOR.MainBackground):diffusealpha(0.8) end }
ssrBox[#ssrBox+1] = UIElements.Border(120,30,1)..{ InitCommand=function(self) self:diffuse(COLOR.MainBorder):diffusealpha(0.4) end }
ssrBox[#ssrBox+1] = LoadFont("Common Normal")..{ InitCommand=function(self) self:xy(-52,0):halign(0):zoom(0.32):diffuse(COLOR.TextSub2):settext("SSR") end }
ssrBox[#ssrBox+1] = LoadFont("DFPGothic 64px")..{
	InitCommand=function(self) self:xy(52,0):halign(1):zoom(0.42):maxwidth(85/0.42) end,
	RefreshEvaluationCommand=function(self)
		local value = score and call(score,"GetSkillsetSSR",0,"Overall") or 0
		self:settextf("%.2f",value):diffuse(GetRatingColor(value))
	end,
}
banner[#banner+1] = ssrBox

t[#t+1] = metadata
t[#t+1] = banner

-- Main Result Card (Hero Performance Display).
local resultTop = 194
local resultH = math.min(430, SCREEN_HEIGHT - resultTop - 85)
local result = card(mainWidth, resultH, "")
result.InitCommand = function(self) self:xy(left + mainWidth/2, resultTop + resultH/2) end

-- 1. Hero Grade Display Container (Top Left)
local gradeContainer = Def.ActorFrame{ InitCommand=function(self) self:xy(-mainWidth/2 + 85, -resultH/2 + 62) end }
gradeContainer[#gradeContainer+1] = Def.Quad{
	Name="GradeBg",
	InitCommand=function(self) self:zoomto(120,68):diffuse(color("#000000")):diffusealpha(0.08) end,
}
gradeContainer[#gradeContainer+1] = UIElements.Border(120,68,1)..{
	Name="GradeBorder",
	InitCommand=function(self) self:diffuse(COLOR.MainBorder):diffusealpha(0.5) end,
}
gradeContainer[#gradeContainer+1] = LoadFont("DFPGothic 64px")..{
	Name="GradeText",
	InitCommand=function(self) self:zoom(0.85):maxwidth(110/0.85) end,
	RefreshEvaluationCommand=function(self)
		local grade = getGrade()
		local gradeStr = GetGradeString(grade)
		local gradeColor = GetGradeColor(grade)
		self:settext(gradeStr):diffuse(gradeColor)
		self:GetParent():GetChild("GradeBorder"):diffuse(gradeColor):diffusealpha(0.7)
		self:GetParent():GetChild("GradeBg"):diffuse(gradeColor):diffusealpha(0.12)
	end,
}
result[#result+1] = gradeContainer

-- 2. Hero WifeScore Display (Top Center)
local wifeContainer = Def.ActorFrame{ InitCommand=function(self) self:xy(0, -resultH/2 + 58) end }
wifeContainer[#wifeContainer+1] = LoadFont("Common Normal")..{
	InitCommand=function(self) self:xy(0, -24):zoom(0.32):diffuse(COLOR.TextSub2) end,
	RefreshEvaluationCommand=function(self)
		local visible = not customTimingWindows and selectedJudge ~= 4
		self:visible(visible)
		if visible then self:settextf("J4  %.4f%%", getJ4Wife() * 100) end
	end,
}
wifeContainer[#wifeContainer+1] = LoadFont("DFPGothic 64px")..{
	InitCommand=function(self) self:zoom(0.56):diffuse(COLOR.TextMain) end,
	RefreshEvaluationCommand=function(self) self:settextf("%.4f%%", getWife() * 100) end,
}
wifeContainer[#wifeContainer+1] = LoadFont("Common Normal")..{
	InitCommand=function(self) self:xy(0, 26):zoom(0.36):diffuse(COLOR.TextSub2) end,
	RefreshEvaluationCommand=function(self)
		self:settext(customTimingWindows and customTimingWindowName() or string.format("WIFESCORE (J%d)", selectedJudge))
	end,
}
result[#result+1] = wifeContainer

-- 3. Hero Clear Type Badge (Top Right)
local clearContainer = Def.ActorFrame{ InitCommand=function(self) self:xy(mainWidth/2 - 85, -resultH/2 + 62) end }
clearContainer[#clearContainer+1] = Def.Quad{
	Name="ClearBg",
	InitCommand=function(self) self:zoomto(120,44):diffuse(color("#000000")):diffusealpha(0.08) end,
}
clearContainer[#clearContainer+1] = UIElements.Border(120,44,1)..{
	Name="ClearBorder",
	InitCommand=function(self) self:diffuse(COLOR.MainBorder):diffusealpha(0.5) end,
}
clearContainer[#clearContainer+1] = LoadFont("Common Normal")..{
	Name="ClearText",
	InitCommand=function(self) self:zoom(0.48):maxwidth(110/0.48) end,
	RefreshEvaluationCommand=function(self)
		local text, c = getClear()
		self:settext(text):diffuse(c)
		self:GetParent():GetChild("ClearBorder"):diffuse(c):diffusealpha(0.7)
		self:GetParent():GetChild("ClearBg"):diffuse(c):diffusealpha(0.12)
	end,
}
result[#result+1] = clearContainer

-- Horizontal Divider below Hero Header
result[#result+1] = Def.Quad{ InitCommand=function(self) self:xy(0,-resultH/2+112):zoomto(mainWidth-32,1):diffuse(COLOR.MainBorder):diffusealpha(0.3) end }

-- Vertical Split Divider between Judgements and Stat Matrix
result[#result+1] = Def.Quad{ InitCommand=function(self) self:xy(mainWidth*0.04, -resultH/2+245):zoomto(1, resultH-165):diffuse(COLOR.MainBorder):diffusealpha(0.25) end }

-- Middle Left: Judgement breakdown rows with visual progress bars
local judgmentRows = {
	{"MARVELOUS","TapNoteScore_W1",judgementColor("TapNoteScore_W1")},
	{"PERFECT","TapNoteScore_W2",judgementColor("TapNoteScore_W2")},
	{"GREAT","TapNoteScore_W3",judgementColor("TapNoteScore_W3")},
	{"GOOD","TapNoteScore_W4",judgementColor("TapNoteScore_W4")},
	{"BAD","TapNoteScore_W5",judgementColor("TapNoteScore_W5")},
	{"MISS","TapNoteScore_Miss",judgementColor("TapNoteScore_Miss")},
}

local tableW = mainWidth * 0.44
local tableX = -mainWidth/2 + tableW/2 + 20

for i, row in ipairs(judgmentRows) do
	local rowIndex = i
	local y = -resultH/2 + 132 + i * 28
	local rowFrame = Def.ActorFrame{ InitCommand=function(self) self:xy(tableX, y) end }
	-- Progress track background
	rowFrame[#rowFrame+1] = Def.Quad{
		InitCommand=function(self) self:xy(0,0):zoomto(tableW, 24):diffuse(COLOR.MainBackground):diffusealpha(0.5) end,
	}
	-- Dynamic progress fill bar
	rowFrame[#rowFrame+1] = Def.Quad{
		Name="BarFill",
		InitCommand=function(self) self:xy(-tableW/2,0):halign(0):zoomto(0, 24):diffuse(row[3]):diffusealpha(0.22) end,
		RefreshEvaluationCommand=function(self)
			local count = rescoredCounts()[rowIndex]
			local totalTaps = #offsets > 0 and #offsets or 1
			local pct = math.min(1, math.max(0, count / totalTaps))
			self:zoomto(tableW * pct, 24)
		end,
	}
	-- Subtle border
	rowFrame[#rowFrame+1] = UIElements.Border(tableW, 24, 1)..{
		InitCommand=function(self) self:diffuse(COLOR.MainBorder):diffusealpha(0.3) end,
	}
	-- Judgement Label
	rowFrame[#rowFrame+1] = LoadFont("Common Normal")..{
		InitCommand=function(self) self:xy(-tableW/2+12, 0):halign(0):zoom(0.42):diffuse(row[3]) end,
		RefreshEvaluationCommand=function(self)
			local label = customTimingWindows and getCustomWindowConfigJudgmentName and getCustomWindowConfigJudgmentName(row[2]) or row[1]
			self:settext(label or row[1])
		end,
	}
	-- Tap Count & Percentage Text
	rowFrame[#rowFrame+1] = LoadFont("Common Normal")..{
		InitCommand=function(self) self:xy(tableW/2-12, 0):halign(1):zoom(0.42):diffuse(COLOR.TextMain) end,
		RefreshEvaluationCommand=function(self)
			local count = rescoredCounts()[rowIndex]
			local totalTaps = #offsets > 0 and #offsets or 1
			local pct = (count / totalTaps) * 100
			if count > 0 then
				self:settextf("%d  (%.1f%%)", count, pct)
			else
				self:settext("0")
			end
		end,
	}
	result[#result+1] = rowFrame
end

-- Holds & Mines Summary Bar below Judgement table
local holdMineY = -resultH/2 + 338
local holdMineFrame = Def.ActorFrame{ InitCommand=function(self) self:xy(tableX, holdMineY) end }
holdMineFrame[#holdMineFrame+1] = Def.Quad{ InitCommand=function(self) self:zoomto(tableW, 24):diffuse(COLOR.MainBackground):diffusealpha(0.6) end }
holdMineFrame[#holdMineFrame+1] = UIElements.Border(tableW, 24, 1)..{ InitCommand=function(self) self:diffuse(COLOR.MainBorder):diffusealpha(0.35) end }
holdMineFrame[#holdMineFrame+1] = LoadFont("Common Normal")..{
	InitCommand=function(self) self:zoom(0.38):diffuse(COLOR.TextSub1) end,
	RefreshEvaluationCommand=function(self)
		local held = call(pss,"GetHoldNoteScores",0,"HoldNoteScore_Held") or 0
		local letgo = call(pss,"GetHoldNoteScores",0,"HoldNoteScore_LetGo") or 0
		local mines = call(pss,"GetTapNoteScores",0,"TapNoteScore_HitMine") or 0
		self:settextf("HOLDS  %d OK / %d NG   |   MINES HIT  %d", held, letgo, mines)
	end,
}
result[#result+1] = holdMineFrame

-- Middle Right: Key Performance Metrics Matrix (6 Structured Cards in a 2x3 Grid)
local matrixX = mainWidth * 0.27
local matrixW = mainWidth * 0.42
local cardGridW = matrixW / 2 - 6
local cardGridH = 54

local matrixItems = {
	{ label = "MA", fn = function() local c=rescoredCounts(); return formatRatio(c[1],c[2]) end },
	{ label = "PA", fn = function() local c=rescoredCounts(); return formatRatio(c[2],c[3]) end },
	{ label = "MAX COMBO", fn = function() return string.format("%d", rescoredMaxCombo()) end },
	{ label = "MEAN", fn = function() return string.format("%.2fms", offsetMean()) end },
	{ label = "STD DEV", fn = function() return string.format("%.2fms", offsetSd()) end },
	{ label = "MAX", fn = function() return string.format("%.2fms", offsetMax()) end },
}

for i, item in ipairs(matrixItems) do
	local col = (i - 1) % 2
	local rowIdx = math.floor((i - 1) / 2)
	local cx = matrixX - matrixW/2 + cardGridW/2 + col * (cardGridW + 12)
	local cy = -resultH/2 + 158 + rowIdx * (cardGridH + 12)

	local miniCard = Def.ActorFrame{ InitCommand=function(self) self:xy(cx, cy) end }
	miniCard[#miniCard+1] = Def.Quad{ InitCommand=function(self) self:zoomto(cardGridW, cardGridH):diffuse(COLOR.MainBackground):diffusealpha(0.7) end }
	miniCard[#miniCard+1] = UIElements.Border(cardGridW, cardGridH, 1)..{ InitCommand=function(self) self:diffuse(COLOR.MainBorder):diffusealpha(0.35) end }
	miniCard[#miniCard+1] = LoadFont("Common Normal")..{ InitCommand=function(self) self:xy(0, -12):zoom(0.32):diffuse(COLOR.TextSub2):settext(item.label) end }
	miniCard[#miniCard+1] = LoadFont("Common Normal")..{
		InitCommand=function(self) self:xy(0, 8):zoom(0.44):diffuse(COLOR.TextMain) end,
		RefreshEvaluationCommand=function(self) self:settext(item.fn()) end,
	}
	result[#result+1] = miniCard
end

t[#t+1] = result

-- Right-side stacked card: Local Scores Leaderboard & Offset Scatterplot canvas
local sideH = resultH
local side = card(railWidth, sideH, "")
side.InitCommand = function(self)
	self:xy(railX, resultTop + sideH/2)
	self:SetUpdateFunction(function(actor) actor:playcommand("Update") end)
end

-- Header for Local Scores
side[#side+1] = LoadFont("Common Normal")..{
	InitCommand=function(self) self:xy(0, -sideH/2 + 16):zoom(0.36):diffuse(COLOR.TextSub2) end,
	RefreshEvaluationCommand=function(self) self:settextf("LOCAL SCORES  %d / %d", leaderboardPage, math.max(1, math.ceil(#leaderboard/5))) end,
}

-- Leaderboard 5 Rows
local cardW, cardH = railWidth - 32, 26
for i=1,5 do
	local y = -sideH/2 + 36 + (i-1) * 29
	local cardFrame = Def.ActorFrame{ Name="LeaderboardCard"..i, InitCommand=function(self) self:xy(0,y) end }
	cardFrame[#cardFrame+1] = Def.Quad{ Name="CardBg", InitCommand=function(self) self:zoomto(cardW, cardH):diffuse(COLOR.MainBackground):diffusealpha(0.6) end }
	cardFrame[#cardFrame+1] = UIElements.Border(cardW, cardH, 1)..{ Name="CardBorder", InitCommand=function(self) self:diffuse(COLOR.MainBorder):diffusealpha(0.4) end }
	
	local details = LoadFont("Common Normal")..{ Name="LeaderboardDetails"..i, InitCommand=function(self) self:xy(-cardW/2+10, -5):halign(0):zoom(0.35):diffuse(COLOR.TextMain) end }
	local judges = LoadFont("Common Normal")..{ Name="LeaderboardJudges"..i, InitCommand=function(self) self:xy(-cardW/2+10, 6):halign(0):zoom(0.30):diffuse(COLOR.TextSub1) end }
	
	cardFrame[#cardFrame+1] = details
	cardFrame[#cardFrame+1] = judges
	side[#side+1] = cardFrame
end

-- Divider between Leaderboard and Scatterplot
side[#side+1] = Def.Quad{ InitCommand=function(self) self:xy(0,-sideH/2+188):zoomto(railWidth-32,1):diffuse(COLOR.MainBorder):diffusealpha(0.35) end }

-- Scatterplot Frame & Canvas
local plotTop = -sideH/2 + 196
local plotW, plotH = railWidth - 36, sideH/2 - 68

-- Dark Canvas Background
side[#side+1] = Def.Quad{ InitCommand=function(self) self:xy(0, plotTop + plotH/2):zoomto(plotW, plotH):diffuse(color("#111318")):diffusealpha(0.9) end }
side[#side+1] = UIElements.Border(plotW, plotH, 1)..{ InitCommand=function(self) self:xy(0, plotTop + plotH/2):diffuse(COLOR.MainBorder):diffusealpha(0.5) end }

-- Zero-offset Horizontal Centerline
side[#side+1] = Def.Quad{ InitCommand=function(self) self:xy(0, plotTop + plotH/2):zoomto(plotW, 1):diffuse(color("#FFFFFF")):diffusealpha(0.2) end }

-- Timing-window guides and early/late orientation markers.
for i = 1, 4 do
	local guide = Def.Quad{ Name = "TimingGuide" .. i, InitCommand = function(self)
		self:zoomto(plotW, 1):diffuse(judgementColor("TapNoteScore_W" .. i)):diffusealpha(0.24)
	end }
	guide.RefreshEvaluationCommand = function(self)
		local cutoffs = timingCutoffs()
		self:y(plotTop + plotH/2 - cutoffs[i] / cutoffs[5] * plotH/2):visible(cutoffs[5] > 0)
	end
	side[#side+1] = guide
end
for _, marker in ipairs({{"EARLY", plotTop + 12}, {"LATE", plotTop + plotH - 12}}) do
	local markerName, markerY = marker[1], marker[2]
	side[#side+1] = LoadFont("Common Normal") .. {
		Name = markerName .. "Marker",
		InitCommand = function(self) self:xy(-plotW/2 + 18, markerY):halign(0):valign(0.5):zoom(0.30):diffuse(COLOR.TextSub2) end,
		RefreshEvaluationCommand = function(self) self:settext(markerName) end,
	}
end

-- Miss Lines & Plot Dots
for i=1,2000 do
	side[#side+1] = Def.Quad{ Name="MissLine"..i, InitCommand=function(self) self:zoomto(1,plotH):diffuse(judgementColor("TapNoteScore_Miss")):diffusealpha(0.65):visible(false) end }
end
for i=1,2000 do
	side[#side+1] = Def.Quad{ Name="PlotDot"..i, InitCommand=function(self) self:zoomto(2,2):visible(false) end }
end

-- Hand Stats Pill Container
local handFrame = Def.ActorFrame{ Name="HandFrame", InitCommand=function(self) self:xy(0, plotTop + plotH + 18) end }
handFrame[#handFrame+1] = Def.Quad{ InitCommand=function(self) self:zoomto(plotW, 38):diffuse(COLOR.MainBackground):diffusealpha(0.7) end }
handFrame[#handFrame+1] = UIElements.Border(plotW, 38, 1)..{ InitCommand=function(self) self:diffuse(COLOR.MainBorder):diffusealpha(0.3) end }
for _, hand in ipairs({"LEFT", "RIGHT"}) do
	local y = hand == "LEFT" and -9 or 9
	handFrame[#handFrame+1] = LoadFont("Common Normal")..{
		Name = hand .. "HandStats",
		InitCommand = function(self) self:xy(-plotW/2 + 10, y):halign(0):zoom(0.35):diffuse(COLOR.TextSub1) end,
	}
end
side[#side+1] = handFrame

-- Plot Caption & Column Filter prompt
local plotCaption = LoadFont("Common Normal")..{ InitCommand=function(self) self:xy(0, sideH/2 - 14):zoom(0.44):diffuse(COLOR.TextSub1) end }
plotCaption.Name = "PlotCaption"
side[#side+1] = plotCaption

local function getEntryJudgementString(entry)
	if not entry then return "" end
	local w1 = call(entry, "GetTapNoteScore", 0, "TapNoteScore_W1") or 0
	local w2 = call(entry, "GetTapNoteScore", 0, "TapNoteScore_W2") or 0
	local w3 = call(entry, "GetTapNoteScore", 0, "TapNoteScore_W3") or 0
	local w4 = call(entry, "GetTapNoteScore", 0, "TapNoteScore_W4") or 0
	local w5 = call(entry, "GetTapNoteScore", 0, "TapNoteScore_W5") or 0
	local miss = call(entry, "GetTapNoteScore", 0, "TapNoteScore_Miss") or 0
	return string.format("%d / %d / %d / %d / %d / %d", w1, w2, w3, w4, w5, miss)
end

side.RefreshEvaluationCommand=function(self)
	local first=(leaderboardPage-1)*5+1
	for i=1,5 do
		local entry=leaderboard[first+i-1]
		local cardActor=self:GetChild("LeaderboardCard"..i)
		if cardActor then
			local detailActor=cardActor:GetChild("LeaderboardDetails"..i)
			local judgeActor=cardActor:GetChild("LeaderboardJudges"..i)
			local bgActor=cardActor:GetChild("CardBg")
			local borderActor=cardActor:GetChild("CardBorder")
			if entry then
				cardActor:visible(true)
				local wife=call(entry,"GetWifeScore",0)*100
				local grade=GetGradeString(call(entry,"GetWifeGrade","Grade_None"))
				local combo=call(entry,"GetMaxCombo",0)
				local rankStr = string.format("#%d", first+i-1)
				
				detailActor:settextf("%s  %s  %.4f%%  x%d", rankStr, grade, wife, combo):diffuse(entry==score and COLOR.MainHighlight or COLOR.TextMain)
				judgeActor:settextf("%s", getEntryJudgementString(entry)):diffuse(entry==score and COLOR.MainHighlight or COLOR.TextSub1)
				
				if bgActor then bgActor:diffuse(entry==score and COLOR.MainHighlight or COLOR.MainBackground):diffusealpha(entry==score and 0.25 or 0.6) end
				if borderActor then borderActor:diffuse(entry==score and COLOR.MainHighlight or COLOR.MainBorder):diffusealpha(entry==score and 0.8 or 0.4) end
			else
				cardActor:visible(false)
			end
		end
	end
	local timingScale = judgeScale()
	local duration = song and call(song,"GetLastSecond",1) or (steps and call(steps,"GetLastSecond",1) or 1)
	local timingData = steps and steps:GetTimingData()
	local firstRow, lastRow = math.huge, -math.huge
	for _, row in ipairs(noteRows) do firstRow = math.min(firstRow,row); lastRow = math.max(lastRow,row) end
	local rowSpan = lastRow > firstRow and lastRow-firstRow or 1
	local timingWindows = timingCutoffs()
	local guideCutoffs = timingWindows
	for i = 1, 4 do
		local guide = self:GetChild("TimingGuide" .. i)
		if guide then guide:y(plotTop + plotH/2 - guideCutoffs[i] / guideCutoffs[5] * plotH/2) end
	end
	local judgeColors = {
		judgementColor("TapNoteScore_W1"), judgementColor("TapNoteScore_W2"),
		judgementColor("TapNoteScore_W3"), judgementColor("TapNoteScore_W4"),
		judgementColor("TapNoteScore_W5"), judgementColor("TapNoteScore_Miss"),
	}
	local plotDots = {}
	for i,value in ipairs(offsets) do
		if noteRows[i] and (selectedColumn == 0 or tracks[i] == selectedColumn-1) then
			local x = (noteRows[i]-firstRow) / rowSpan * plotW - plotW/2
			local absValue = math.abs(value)
			local judgeIndex = 6
			for j,window in ipairs(timingWindows) do
				local cutoff = window
				if absValue <= cutoff then judgeIndex = j; break end
			end
			local displayScale = judgeScale()
			local plotRange = plotLargestHit and math.max(1, offsetMax()) or timingWindows[5]
			plotDots[#plotDots+1] = {x, -value / plotRange * plotH/2, judgeColors[judgeIndex], i}
		end
	end
	-- Replay vectors can be longer than the initial actor pool. Grow it when
	-- needed so later points are not silently omitted from the plot.
	local plotCapacity = math.max(2000, #plotDots)
	for i=plotActorCapacity + 1,plotCapacity do
		self:AddChild(Def.Quad{ Name="MissLine"..i, InitCommand=function(actor)
			actor:zoomto(1,plotH):diffuse(judgementColor("TapNoteScore_Miss")):diffusealpha(0.65):visible(false)
		end })
		self:AddChild(Def.Quad{ Name="PlotDot"..i, InitCommand=function(actor)
			actor:zoomto(2,2):visible(false)
		end })
	end
	plotActorCapacity = math.max(plotActorCapacity, plotCapacity)
	for i=1,plotCapacity do
		local dot = self:GetChild("PlotDot"..i)
		local missLine = self:GetChild("MissLine"..i)
		local item = plotDots[i]
		if item and math.abs(offsets[item[4]] or 0) < timingWindows[5] then
			dot:xy(item[1],plotTop+plotH/2+item[2]):diffuse(item[3]):visible(true)
			missLine:visible(false)
		elseif item then
			dot:visible(false)
			missLine:xy(item[1],plotTop+plotH/2):visible(true)
		else
			dot:visible(false); missLine:visible(false)
		end
	end
	local leftData=splitHandData("LEFT")
	local rightData=splitHandData("RIGHT")
	local handFrameActor = self:GetChild("HandFrame")
	local leftScore, rightScore = wifePercentFor(leftData), wifePercentFor(rightData)
	if handFrameActor then
		local leftActor = handFrameActor:GetChild("LEFTHandStats")
		local rightActor = handFrameActor:GetChild("RIGHTHandStats")
		if leftActor then leftActor:settextf("LEFT   %.4f%% / %d CB", leftScore, comboBreaksFor("LEFT")):diffuse(GetGradeColor(GetGradeForPercent(leftScore))) end
		if rightActor then rightActor:settextf("RIGHT  %.4f%% / %d CB", rightScore, comboBreaksFor("RIGHT")):diffuse(GetGradeColor(GetGradeForPercent(rightScore))) end
	end
	local colText = selectedColumn == 0 and "All" or string.format("Col %d", selectedColumn)
	self:GetChild("PlotCaption"):settextf("Up/Down toggles highlights (%s)", colText)
end

t[#t+1]=side

local function updateLeaderboard()
	MESSAGEMAN:Broadcast("RefreshEvaluation")
end

local function evaluationInput(event)
	if event.type ~= "InputEventType_FirstPress" then return false end
	if event.button == "EffectUp" then
		if customTimingWindows and type(moveCustomWindowConfigIndex) == "function" then
			moveCustomWindowConfigIndex(1)
			setCustomTimingWindows(true)
		else
			selectedJudge = math.min(9, selectedJudge + 1)
		end
		refreshState()
		MESSAGEMAN:Broadcast("RefreshEvaluation")
		return true
	elseif event.button == "EffectDown" then
		if customTimingWindows and type(moveCustomWindowConfigIndex) == "function" then
			moveCustomWindowConfigIndex(-1)
			setCustomTimingWindows(true)
		else
			selectedJudge = math.max(4, selectedJudge - 1)
		end
		refreshState()
		MESSAGEMAN:Broadcast("RefreshEvaluation")
		return true
	elseif event.button == "InsertCoin" or event.button == "Coin" then
		setCustomTimingWindows(not customTimingWindows)
		refreshState()
		MESSAGEMAN:Broadcast("RefreshEvaluation")
		return true
	elseif event.button == "MouseLeft" then
		plotLargestHit = not plotLargestHit
		MESSAGEMAN:Broadcast("RefreshEvaluation")
		return true
	elseif event.button == "MenuDown" or event.button == "Down" then
		local columns=steps and call(steps,"GetNumColumns",4) or 4
		selectedColumn=selectedColumn%columns+1
		MESSAGEMAN:Broadcast("RefreshEvaluation")
		return true
	elseif event.button == "MenuUp" or event.button == "Up" then
		local columns=steps and call(steps,"GetNumColumns",4) or 4
		selectedColumn=(selectedColumn-2)%columns+1
		MESSAGEMAN:Broadcast("RefreshEvaluation")
		return true
	elseif event.button == "MenuLeft" then
		leaderboardPage=math.max(1,leaderboardPage-1)
		updateLeaderboard()
		return true
	elseif event.button == "MenuRight" then
		leaderboardPage=math.min(math.max(1,math.ceil(#leaderboard/5)),leaderboardPage+1)
		updateLeaderboard()
		return true
	end
	return false
end

t.BeginCommand=function(self)
	refreshState()
	updateLeaderboard()
	SCREENMAN:GetTopScreen():AddInputCallback(evaluationInput)
	self:RunCommandsOnChildren(function(actor) actor:playcommand("RefreshEvaluation") end)
end

-- Navigation & Keybind Toolbar Footer
local buttonW, buttonH, buttonY = 180, 38, SCREEN_HEIGHT-38

local function navButton(x,label,highlighted,action)
	local button=Def.ActorFrame{InitCommand=function(self) self:xy(x,buttonY) end}
	button[#button+1]=Def.Quad{InitCommand=function(self) self:zoomto(buttonW,buttonH):diffuse(highlighted and COLOR.MainHighlight or COLOR.MainBackground):diffusealpha(highlighted and 0.9 or 0.85) end}
	button[#button+1]=UIElements.Border(buttonW,buttonH,1)..{InitCommand=function(self) self:diffuse(COLOR.MainBorder):diffusealpha(0.6) end}
	button[#button+1]=LoadFont("Common Normal")..{InitCommand=function(self) self:zoom(0.50):diffuse(highlighted and COLOR.TextMainLight or COLOR.TextMain):settext(label) end}
	button[#button+1]=UIElements.QuadButton(1)..{
		InitCommand=function(self) self:zoomto(buttonW,buttonH):diffusealpha(0) end,
		MouseClickCommand=action,
	}
	return button
end

t[#t+1]=navButton(left+mainWidth/2-105,"<  SONG SELECT",false,function() local screen=SCREENMAN:GetTopScreen();screen:SetNextScreenName("ScreenSelectMusic");screen:StartTransitioningScreen("SM_GoToNextScreen") end)
t[#t+1]=navButton(left+mainWidth/2+105,"RETRY  >",true,function() local screen=SCREENMAN:GetTopScreen();screen:SetNextScreenName("ScreenStageInformation");screen:StartTransitioningScreen("SM_GoToNextScreen") end)
t[#t+1]=LoadActor("../_mouse.lua","ScreenEvaluation")

return t
