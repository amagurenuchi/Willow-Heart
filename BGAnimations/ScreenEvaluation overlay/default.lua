-- Willow Heart evaluation screen.
-- The screen intentionally keeps all score data in this file so the visual
-- layout does not depend on the profile card or on another screen's actors.

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
local leaderboardPage = 1
local leaderboard = {}
local plotActor = nil
local statRefreshActor = nil

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
			return getRescoredWife3Judge(3, GetTimingDifficulty(), {
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
	-- Wife's offset contribution is exposed by the same helper used by the
	-- stock Etterna evaluation screens.  Keep this as a percentage display.
	local mean = total / valid
	return math.max(0, 100 - math.abs(mean) / 22.5 * 5)
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
	local threshold = (ms and ms.JudgeScalers and ms.JudgeScalers[GetTimingDifficulty()] or 1) * 90
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

local function offsetMean()
	return #offsets > 0 and wifeMean(offsets) or 0
end

local function offsetSd()
	return #offsets > 1 and wifeSd(offsets) or 0
end

local function offsetMax()
	return #offsets > 0 and wifeMax(offsets) or 0
end

local function getGrade()
	return call(score, "GetWifeGrade", call(score, "GetGrade", "Grade_None"))
end

local function getWife()
	local value = call(score, "GetWifeScore", nil)
	if value == nil then value = call(pss, "GetWifeScore", 0) end
	return value > 1 and value / 100 or value
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
	-- getScoreTable is supplied by some themes, but not by Willow Heart's
	-- fallback scripts. Use the fallback rate table when it is unavailable.
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

local function card(width, height, title)
	local frame = Def.ActorFrame{}
	frame[#frame + 1] = Def.Quad{ InitCommand=function(self) self:xy(4,4):zoomto(width,height):diffuse(COLOR.MainHighlight):diffusealpha(0.55) end }
	frame[#frame + 1] = Def.Quad{ InitCommand=function(self) self:zoomto(width,height):diffuse(COLOR.MainBackground) end }
	frame[#frame + 1] = UIElements.Border(width,height,1)..{ InitCommand=function(self) self:diffuse(COLOR.MainBorder) end }
	if title and title ~= "" then
		frame[#frame + 1] = LoadFont("Common Normal")..{ InitCommand=function(self) self:xy(-width/2+18,-height/2+18):halign(0):zoom(0.5):diffuse(COLOR.TextSub2):settext(title) end }
	end
	return frame
end

local railWidth = math.min(430, math.max(350, SCREEN_WIDTH * 0.31))
local gap = 18
local left = 24
local right = SCREEN_WIDTH - 24
local mainRight = right - railWidth - gap
local mainWidth = mainRight - left
local railX = mainRight + gap + railWidth / 2

local t = Def.ActorFrame{
	OnCommand = function(self)
		refreshState()
		self:playcommand("RefreshEvaluation")
	end,
	RefreshEvaluationMessageCommand = function(self)
		refreshState()
		self:RunCommandsOnChildren(function(actor)
			actor:playcommand("RefreshEvaluation")
		end)
	end,
}

t[#t+1] = StandardDecorationFromFileOptional("Header", "Header")

-- Upper-left song metadata.
local metadataW = mainWidth
local metadata = card(metadataW, 110, "")
metadata.InitCommand = function(self) self:xy(left + metadataW/2, 125) end
metadata[#metadata+1] = LoadFont("DFPGothic 64px")..{
	InitCommand=function(self) self:xy(-metadataW/2+24,-27):halign(0):zoom(0.42):maxwidth((metadataW-40)/0.42):diffuse(COLOR.TextMain) end,
	RefreshEvaluationCommand=function(self) self:settext(song and song:GetDisplayMainTitle() or "No Song Selected") end,
}
metadata[#metadata+1] = LoadFont("Common Normal")..{
	InitCommand=function(self) self:xy(-metadataW/2+24,4):halign(0):zoom(0.48):maxwidth((metadataW-40)/0.48):diffuse(COLOR.TextSub1) end,
	RefreshEvaluationCommand=function(self)
		local artist = song and song:GetDisplayArtist() or "Unknown Artist"
		local subtitle = song and song:GetDisplaySubTitle() or ""
		self:settext(subtitle ~= "" and subtitle.." - "..artist or "// "..artist)
	end,
}
metadata[#metadata+1] = LoadFont("Common Normal")..{
	InitCommand=function(self) self:xy(-metadataW/2+24,31):halign(0):zoom(0.40):diffuse(COLOR.TextSub2) end,
	RefreshEvaluationCommand=function(self)
		local diffStr = steps and (THEME:GetString("CustomDifficulty", steps:GetDifficulty()) or steps:GetDifficulty()) or ""
		local packStr = song and song:GetGroupName() or "Standard"
		if diffStr ~= "" then
			self:settextf("Pack: %s   |   Chart: %s", packStr, diffStr)
		else
			self:settextf("Pack: %s", packStr)
		end
	end,
}

-- Upper-right banner, with MSD and SSR below it.
local bannerW, bannerH = railWidth, 110
local banner = card(bannerW, bannerH, "")
banner.InitCommand = function(self) self:xy(railX, 125) end
banner[#banner+1] = Def.Quad{
	InitCommand=function(self) self:xy(-bannerW/2+bannerH/2,0):zoomto(152,84):diffuse(COLOR.MainBorder):diffusealpha(0.3) end,
}
banner[#banner+1] = Def.Sprite{
	InitCommand=function(self) self:xy(-bannerW/2+bannerH/2,0) end,
	RefreshEvaluationCommand=function(self)
		if song and song:HasBanner() then self:LoadBackground(song:GetBannerPath()); self:scaletoclipped(150,82); self:visible(true) else self:visible(false) end
	end,
}
banner[#banner+1] = LoadFont("DFPGothic 64px")..{
	InitCommand=function(self) self:xy(bannerW/2-22,-22):halign(1):zoom(0.55):maxwidth(210/0.55) end,
	RefreshEvaluationCommand=function(self)
		local value = steps and call(steps,"GetMSD",0,rate,1) or 0
		self:settextf("%.2f",value):diffuse(GetRatingColor(value))
	end,
}
banner[#banner+1] = LoadFont("DFPGothic 64px")..{
	InitCommand=function(self) self:xy(bannerW/2-22,28):halign(1):zoom(0.42):maxwidth(210/0.42) end,
	RefreshEvaluationCommand=function(self)
		local value = score and call(score,"GetSkillsetSSR",0,"Overall") or 0
		self:settextf("SSR %.2f",value):diffuse(GetRatingColor(value))
	end,
}

t[#t+1] = metadata
t[#t+1] = banner

-- Main merged result card.
local resultTop = 205
local resultH = math.min(410, SCREEN_HEIGHT - resultTop - 95)
local result = card(mainWidth, resultH, "")
result.InitCommand = function(self) self:xy(left + mainWidth/2, resultTop + resultH/2) end

result[#result+1] = LoadFont("DFPGothic 64px")..{
	InitCommand=function(self) self:xy(-mainWidth*0.25,-resultH/2+72):zoom(1.0) end,
	RefreshEvaluationCommand=function(self) local grade=getGrade(); self:settext(GetGradeString(grade)):diffuse(GetGradeColor(grade)) end,
}
result[#result+1] = LoadFont("DFPGothic 64px")..{
	InitCommand=function(self) self:xy(0,-resultH/2+84):zoom(0.48):diffuse(COLOR.TextMain) end,
	RefreshEvaluationCommand=function(self) self:settextf("%.4f%%",getWife()*100) end,
}
result[#result+1] = LoadFont("Common Normal")..{ InitCommand=function(self) self:xy(0,-resultH/2+113):zoom(0.4):diffuse(COLOR.TextSub2):settext("WIFESCORE") end }
result[#result+1] = LoadFont("Common Normal")..{
	InitCommand=function(self) self:xy(mainWidth*0.25,-resultH/2+100):zoom(0.5):halign(0) end,
	RefreshEvaluationCommand=function(self) local text,c=getClear(); self:settext(text):diffuse(c) end,
}

-- Divider below the top third.
result[#result+1] = Def.Quad{ InitCommand=function(self) self:xy(0,-resultH/2+145):zoomto(mainWidth-36,1):diffuse(COLOR.MainBorder):diffusealpha(0.35) end }

local judgmentRows = {
	{"MARVELOUS","TapNoteScore_W1",color("#55BBFF")}, {"PERFECT","TapNoteScore_W2",color("#DDBB22")},
	{"GREAT","TapNoteScore_W3",color("#55AA66")}, {"GOOD","TapNoteScore_W4",color("#9966CC")},
	{"BAD","TapNoteScore_W5",color("#DD7733")}, {"MISS","TapNoteScore_Miss",color("#DD4444")},
}
for i, row in ipairs(judgmentRows) do
	local y = -resultH/2 + 178 + i*27
	result[#result+1] = LoadFont("Common Normal")..{ InitCommand=function(self) self:xy(-mainWidth/2+28,y):halign(0):zoom(0.45):diffuse(row[3]):settext(row[1]) end }
	result[#result+1] = LoadFont("Common Normal")..{
		InitCommand=function(self) self:xy(-18,y):halign(1):zoom(0.5):diffuse(COLOR.TextMain) end,
		RefreshEvaluationCommand=function(self)
			local count = call(pss,"GetTapNoteScores",0,row[2]) or 0
			self:settext(tostring(count))
		end,
	}
end
result[#result+1] = LoadFont("Common Normal")..{
	InitCommand=function(self) self:xy(-mainWidth/4,resultH/2-42):zoom(0.42):diffuse(COLOR.TextSub1) end,
	RefreshEvaluationCommand=function(self)
		self:settextf("HOLDS %d OK / %d NG  |  MINES %d",call(pss,"GetHoldNoteScores",0,"HoldNoteScore_Held"),call(pss,"GetHoldNoteScores",0,"HoldNoteScore_LetGo"),call(pss,"GetTapNoteScores",0,"TapNoteScore_HitMine"))
	end,
}

local function statText(y, label, valueFunction)
	result[#result+1] = LoadFont("Common Normal")..{
		InitCommand=function(self) self:xy(mainWidth/4,y):halign(0):zoom(0.42):diffuse(COLOR.TextSub1) end,
		RefreshEvaluationCommand=function(self) self:settextf("%s  %s",label,valueFunction()) end,
	}
end
statText(-resultH/2+178,"MA",function() return formatRatio(call(pss,"GetTapNoteScores",0,"TapNoteScore_W1"),call(pss,"GetTapNoteScores",0,"TapNoteScore_W2")) end)
statText(-resultH/2+205,"PA",function() return formatRatio(call(pss,"GetTapNoteScores",0,"TapNoteScore_W2"),call(pss,"GetTapNoteScores",0,"TapNoteScore_W3")) end)
statText(-resultH/2+232,"MAX COMBO",function() return tostring(call(score,"GetMaxCombo",call(pss,"MaxCombo",0))) end)
statText(-resultH/2+259,"MEAN",function() return string.format("%.2fms",offsetMean()) end)
statText(-resultH/2+286,"STD DEV",function() return string.format("%.2fms",offsetSd()) end)
statText(-resultH/2+313,"LARGEST",function() return string.format("%.2fms",offsetMax()) end)
t[#t+1] = result

-- Right-side stacked card: card-based local scores above the offset plot.
local sideH = resultH
local side = card(railWidth,sideH,"")
side.InitCommand = function(self) self:xy(railX,resultTop+sideH/2) end
side[#side+1] = Def.Quad{ InitCommand=function(self) self:xy(0,-sideH/2+178):zoomto(railWidth-36,1):diffuse(COLOR.MainBorder):diffusealpha(0.4) end }

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

local rowActors = {}
local cardW, cardH = railWidth - 36, 26
for i=1,5 do
	local y = -sideH/2 + 22 + (i-1)*30
	local cardFrame = Def.ActorFrame{ Name="LeaderboardCard"..i, InitCommand=function(self) self:xy(0,y) end }
	cardFrame[#cardFrame+1] = Def.Quad{ Name="CardBg", InitCommand=function(self) self:zoomto(cardW, cardH):diffuse(COLOR.MainBackground):diffusealpha(0.6) end }
	cardFrame[#cardFrame+1] = UIElements.Border(cardW, cardH, 1)..{ Name="CardBorder", InitCommand=function(self) self:diffuse(COLOR.MainBorder):diffusealpha(0.5) end }
	
	-- Line 1: Rank, Grade, WifeScore, Max Combo (Rate is hidden)
	local details = LoadFont("Common Normal")..{ Name="LeaderboardDetails"..i, InitCommand=function(self) self:xy(-cardW/2+10, -5):halign(0):zoom(0.35):diffuse(COLOR.TextMain) end }
	-- Line 2: Judgement counts (W1 / W2 / W3 / W4 / W5 / Miss)
	local judges = LoadFont("Common Normal")..{ Name="LeaderboardJudges"..i, InitCommand=function(self) self:xy(-cardW/2+10, 6):halign(0):zoom(0.30):diffuse(COLOR.TextSub1) end }
	
	cardFrame[#cardFrame+1] = details
	cardFrame[#cardFrame+1] = judges
	side[#side+1] = cardFrame
end

side[#side+1] = LoadFont("Common Normal")..{
	InitCommand=function(self) self:xy(0,-sideH/2+170):zoom(0.36):diffuse(COLOR.TextSub2) end,
	RefreshEvaluationCommand=function(self) self:settextf("LOCAL SCORES  %d / %d",leaderboardPage,math.max(1,math.ceil(#leaderboard/5))) end,
}

local plotTop = -sideH/2+194
local plotW, plotH = railWidth-42, sideH/2-62
side[#side+1] = Def.Quad{ InitCommand=function(self) self:xy(0,plotTop+plotH/2):zoomto(plotW,plotH):diffuse(COLOR.MainBackground):diffusealpha(0.8) end }
side[#side+1] = Def.Quad{ InitCommand=function(self) self:xy(0,plotTop+plotH/2):zoomto(plotW,1):diffuse(COLOR.MainBorder):diffusealpha(0.35) end }
for i=1,160 do
	local dot=Def.Quad{ Name="PlotDot"..i, InitCommand=function(self) self:zoomto(2,2):visible(false) end }
	side[#side+1]=dot
end
local plotCaption=LoadFont("Common Normal")..{ InitCommand=function(self) self:xy(0,sideH/2-23):zoom(0.38):diffuse(COLOR.TextSub1) end }
plotCaption.Name="PlotCaption"
side[#side+1]=plotCaption
local handStats=LoadFont("Common Normal")..{ InitCommand=function(self) self:xy(0,plotTop+plotH+17):zoom(0.36):diffuse(COLOR.TextSub1) end }
handStats.Name="HandStats"
side[#side+1]=handStats

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
	local totalColumns=steps and call(steps,"GetNumColumns",4) or 4
	local plotDots={}
	local duration=song and call(song,"GetLastSecond",1) or 1
	local maxOffset=180
	for i,value in ipairs(offsets) do
		if #plotDots >= 160 then break end
		if noteRows[i] and math.abs(value) < 1000 and (selectedColumn==0 or tracks[i]==selectedColumn-1) then
			local x=duration>0 and (call(steps:GetTimingData(),"GetElapsedTimeFromNoteRow",0,noteRows[i])/duration)*plotW-plotW/2 or 0
			local y=-value/maxOffset*plotH/2
			plotDots[#plotDots+1]={x,y,value}
		end
	end
	for i=1,160 do
		local dot=self:GetChild("PlotDot"..i)
		local item=plotDots[i]
		if item then
			dot:xy(item[1],plotTop+plotH/2+item[2]):visible(true):diffuse(item[3]<0 and color("#66AADD") or color("#DD8866"))
		else dot:visible(false) end
	end
	local leftData=splitHandData("LEFT")
	local rightData=splitHandData("RIGHT")
	self:GetChild("HandStats"):settextf("L %.2f%% / %d CB    R %.2f%% / %d CB",wifePercentFor(leftData),comboBreaksFor("LEFT"),wifePercentFor(rightData),comboBreaksFor("RIGHT"))
	self:GetChild("PlotCaption"):settext("Down toggle highlights")
end
t[#t+1]=side

local function updateLeaderboard()
	if side then side:playcommand("RefreshEvaluation") end
end

local function evaluationInput(event)
	if event.type ~= "InputEventType_FirstPress" then return false end
	if event.button == "MenuDown" or event.button == "Down" then
		local columns=steps and call(steps,"GetNumColumns",4) or 4
		selectedColumn=selectedColumn%columns+1
		if side then side:playcommand("RefreshEvaluation") end
		return true
	elseif event.button == "MenuUp" or event.button == "Up" then
		local columns=steps and call(steps,"GetNumColumns",4) or 4
		selectedColumn=(selectedColumn-2)%columns+1
		if side then side:playcommand("RefreshEvaluation") end
		return true
	elseif event.button == "MenuLeft" then
		leaderboardPage=math.max(1,leaderboardPage-1); updateLeaderboard(); return true
	elseif event.button == "MenuRight" then
		leaderboardPage=math.min(math.max(1,math.ceil(#leaderboard/5)),leaderboardPage+1); updateLeaderboard(); return true
	end
	return false
end

t.BeginCommand=function(self)
	refreshState()
	updateLeaderboard()
	SCREENMAN:GetTopScreen():AddInputCallback(evaluationInput)
	self:RunCommandsOnChildren(function(actor) actor:playcommand("RefreshEvaluation") end)
end

-- Navigation: Song Select remains unchanged; the primary action retries the
-- same chart through the existing StageInformation -> Gameplay path.
local buttonW, buttonH, buttonY = 190, 40, SCREEN_HEIGHT-45
local function navButton(x,label,highlighted,action)
	local button=Def.ActorFrame{InitCommand=function(self) self:xy(x,buttonY) end}
	button[#button+1]=Def.Quad{InitCommand=function(self) self:zoomto(buttonW,buttonH):diffuse(highlighted and COLOR.MainHighlight or COLOR.MainBackground) end}
	button[#button+1]=UIElements.Border(buttonW,buttonH,1)..{InitCommand=function(self) self:diffuse(COLOR.MainBorder) end}
	button[#button+1]=LoadFont("Common Normal")..{InitCommand=function(self) self:zoom(0.52):diffuse(highlighted and COLOR.TextMainLight or COLOR.TextMain):settext(label) end}
	button[#button+1]=UIElements.QuadButton(1)..{InitCommand=function(self) self:zoomto(buttonW,buttonH):diffusealpha(0);MouseClickCommand=action end}
	return button
end
t[#t+1]=navButton(left+mainWidth/2-105,"<  SONG SELECT",false,function() local screen=SCREENMAN:GetTopScreen();screen:SetNextScreenName("ScreenSelectMusic");screen:StartTransitioningScreen("SM_GoToNextScreen") end)
t[#t+1]=navButton(left+mainWidth/2+105,"RETRY  >",true,function() local screen=SCREENMAN:GetTopScreen();screen:SetNextScreenName("ScreenStageInformation");screen:StartTransitioningScreen("SM_GoToNextScreen") end)
t[#t+1]=LoadActor("../_mouse.lua","ScreenEvaluation")
return t
