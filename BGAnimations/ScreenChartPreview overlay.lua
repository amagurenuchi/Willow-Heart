local pn = PLAYER_1
local song = GAMESTATE:GetCurrentSong()
local steps = GAMESTATE:GetCurrentSteps(pn)

local function StepsForSong(song)
	if not song then return {} end
	if song.GetChartsMatchingFilter then return song:GetChartsMatchingFilter() or {} end
	return song.GetAllSteps and song:GetAllSteps() or {}
end

local function OverallMSD(chart, rate)
	if not chart or not chart.GetMSD then return 0 end
	local value = chart:GetMSD(rate or 1, 1)
	return value and value == value and value >= 0 and value or 0
end

local function radar(category)
	if not steps or not steps.GetRadarValues then return 0 end
	local ok, values = pcall(function() return steps:GetRadarValues(pn) end)
	if not ok or not values then return 0 end
	local okValue, value = pcall(function() return values:GetValue(category) end)
	return okValue and math.floor(value or 0) or 0
end

local counts = {
	{"TAPS", "RadarCategory_Notes"},
	{"HOLDS", "RadarCategory_Holds"},
	{"ROLLS", "RadarCategory_Rolls"},
	{"MINES", "RadarCategory_Mines"},
	{"LIFTS", "RadarCategory_Lifts"},
	{"FAKES", "RadarCategory_Fakes"},
}

local function closePreview()
	local top = SCREENMAN:GetTopScreen()
	if top and top.Cancel then top:Cancel() end
end

local function seekToSecond(sec)
	local top = SCREENMAN:GetTopScreen()
	if top and top.SetSecond then pcall(function() top:SetSecond(sec) end) end
	if top and top.SetSongPosition then pcall(function() top:SetSongPosition(sec) end) end
	if top and top.SetMusicPosition then pcall(function() top:SetMusicPosition(sec) end) end
	if GAMESTATE and GAMESTATE.SetCurMusicSeconds then pcall(function() GAMESTATE:SetCurMusicSeconds(sec) end) end
end

local function togglePreviewPause()
	local top = SCREENMAN:GetTopScreen()
	if top and top.PauseGame then
		local paused = top.IsPaused and top:IsPaused() or false
		pcall(function() top:PauseGame(not paused) end)
		return
	end

	-- ScreenChartPreview is a ScreenWithMenuElements, so it does not expose
	-- ScreenGameplay:PauseGame().  Keep the preview's pause state in GameState
	-- when the screen-level gameplay helper is unavailable.
	if GAMESTATE and GAMESTATE.GetPaused and GAMESTATE.SetPaused then
		local paused = GAMESTATE:GetPaused()
		pcall(function() GAMESTATE:SetPaused(not paused) end)
	end
end

local function bar(vertices, x, y, width, height, c)
	vertices[#vertices+1] = {{x, y-height, 0}, c}
	vertices[#vertices+1] = {{x+width, y-height, 0}, c}
	vertices[#vertices+1] = {{x+width, y, 0}, c}
	vertices[#vertices+1] = {{x, y, 0}, c}
end

local function densityColor(column, columns)
	if columns <= 1 then return COLOR.MainHighlight end
	local factor = (columns - column) / math.max(1, columns - 1)
	return color(string.format("%.2f,%.2f,%.2f,1", 0.3 + 0.5 * factor, 0.3 + 0.2 * factor, 0.4 + 0.3 * factor))
end

-- Layout Parameters
local margin = 20
local leftW = 210
local leftX = margin + leftW/2
local rightW = 210
local rightX = SCREEN_WIDTH - margin - rightW/2

-- Top Right Song Info Parameters (No Pack Name, No Meter Badge)
local infoW = 660
local infoH = 65
local infoX = SCREEN_WIDTH - infoW/2 - margin
local infoY = 50
local bannerW = 130
local bannerH = infoH - 4

-- Main Vertical Area
local topY = 100
local bottomY = SCREEN_HEIGHT - 20
local mainH = bottomY - topY
local panelY = topY + mainH/2

-- CD Graph & Rate Card Parameters
local rateCardH = 75
local cdGraphH = mainH - rateCardH - 10
local rateCardY = topY + rateCardH/2
local cdGraphY = topY + rateCardH + 10 + cdGraphH/2

-- Left Cards (Steps List + Note Count)
local stepsListH = 220
local noteCountH = mainH - stepsListH - 10
local stepsListY = topY + stepsListH/2
local noteCountY = topY + stepsListH + 10 + noteCountH/2

-- CD Graph Data Variables for Hover / Seeking
local cdVectors = nil
local cdMaxNPS = 1
local cdRows = 0

local function getMusicRate()
	local options = GAMESTATE:GetSongOptionsObject("ModsLevel_Current")
	return options and options.MusicRate and options:MusicRate() or 1.0
end

local function setMusicRate(newRate)
	local oldRate = getMusicRate()
	newRate = math.max(0.05, math.min(3.0, math.floor(newRate * 100 + 0.5) / 100))
	for _, level in ipairs({"ModsLevel_Preferred", "ModsLevel_Song", "ModsLevel_Current"}) do
		local options = GAMESTATE:GetSongOptionsObject(level)
		if options and options.MusicRate then
			options:MusicRate(newRate)
		end
	end
	MESSAGEMAN:Broadcast("CurrentRateChanged", {oldRate = oldRate, rate = newRate})
end

local function drawDensity(self)
	steps = GAMESTATE:GetCurrentSteps(pn)
	if not steps or not steps.GetCDGraphVectors then return end
	local rate = getMusicRate()
	local ok, vectors = pcall(function()
		return steps:GetCDGraphVectors(math.max(0.05, rate))
	end)
	if not ok or not vectors or not vectors[1] then return end

	cdVectors = vectors
	local columns = steps:GetNumColumns()
	cdRows = #vectors[1]
	local graphH = cdGraphH
	local rowH = graphH / math.max(1, cdRows)
	cdMaxNPS = 1
	for _, row in ipairs(vectors[1]) do cdMaxNPS = math.max(cdMaxNPS, row * 2) end
	local graphW = rightW
	local vertices = {}
	for column = 1, columns do
		if vectors[column] then
			for row = 1, cdRows do
				local value = vectors[column][row] or 0
				if value > 0 then
					bar(vertices, -rightW/2, cdGraphH/2 - (cdRows - row) * rowH, value * 2 * graphW / cdMaxNPS, math.max(1, rowH), densityColor(column, columns))
				end
			end
		end
	end
	self:SetVertices(vertices)
	self:SetDrawState{Mode="DrawMode_Quads", First=1, Num=#vertices}
end

local t = Def.ActorFrame{
	OnCommand=function(self)
		self:playcommand("UpdateScreenHeader", {Header = "Chart Preview"})
		MESSAGEMAN:Broadcast("UpdateScreenHeader", {Header = "Chart Preview"})
		local top = SCREENMAN:GetTopScreen()
		if not top then return end
		top:AddInputCallback(function(event)
			local deviceButton = event.DeviceInput and event.DeviceInput.button
			if event.type == "InputEventType_Release" and deviceButton == "DeviceButton_left mouse button" and song then
				local mouseX = INPUTFILTER:GetMouseX()
				local mouseY = INPUTFILTER:GetMouseY()
				if mouseX >= rightX - rightW/2 and mouseX <= rightX + rightW/2 and
					mouseY >= cdGraphY - cdGraphH/2 and mouseY <= cdGraphY + cdGraphH/2 then
					local ratio = math.max(0, math.min(1, (mouseY - (cdGraphY - cdGraphH/2)) / cdGraphH))
					seekToSecond(ratio * (song:GetLastSecond() or 1))
					return true
				end
			end
			if event.type == "InputEventType_FirstPress" and deviceButton == "DeviceButton_right mouse button" then
				togglePreviewPause()
				return true
			end
			if event.type == "InputEventType_FirstPress" and
				(deviceButton == "DeviceButton_space" or event.button == "Back" or event.button == "Start") then
				closePreview()
				return true
			end
			if event.type == "InputEventType_FirstPress" or event.type == "InputEventType_Repeat" then
				if event.button == "EffectUp" then
					setMusicRate(getMusicRate() + 0.05)
					return true
				elseif event.button == "EffectDown" then
					setMusicRate(getMusicRate() - 0.05)
					return true
				end
			end
			return false
		end)
	end,
	CurrentRateChangedMessageCommand=function(self)
		self:PlayCommandsOnChildren("RateUpdate")
	end,
	CurrentStepsP1ChangedMessageCommand=function(self)
		steps = GAMESTATE:GetCurrentSteps(pn)
		self:PlayCommandsOnChildren("StepsUpdate")
	end,
}

t[#t+1] = StandardDecorationFromFileOptional("Header","Header")..{
	OnCommand = function(self)
		self:playcommand("UpdateScreenHeader", {Header = "Chart Preview"})
	end
}
t[#t+1] = LoadActor("_mouse.lua", "ScreenChartPreview")


-- Top Right Song & Chart Info Card (No Pack Name, No Step Type/Meter Badge)
t[#t+1] = Def.ActorFrame{
	InitCommand = function(self)
		self:xy(infoX, infoY)
	end,

	-- Card Shadow
	Def.Quad{
		InitCommand = function(self)
			self:zoomto(infoW, infoH):xy(4, 4):diffuse(COLOR.MainHighlight)
		end
	},
	-- Card Border
	UIElements.Border(infoW, infoH, 1)..{
		InitCommand = function(self)
			self:diffuse(COLOR.MainBorder)
		end
	},
	-- Card Background
	Def.Quad{
		InitCommand = function(self)
			self:zoomto(infoW, infoH):diffuse(COLOR.MainBackground)
		end
	},

	-- Song Title
	LoadFont("DFPGothic 64px")..{
		InitCommand = function(self)
			self:xy(-infoW/2 + 20, -12):halign(0):zoom(0.40):diffuse(COLOR.TextMain)
			self:maxwidth((infoW - bannerW - 140) / 0.40)
		end,
		OnCommand = function(self)
			if song then
				self:settext(song:GetDisplayMainTitle())
			else
				self:settext("CHART PREVIEW")
			end
		end
	},

	-- Subtitle & Artist
	LoadFont("Common Normal")..{
		InitCommand = function(self)
			self:xy(-infoW/2 + 20, 14):halign(0):zoom(0.48):diffuse(COLOR.TextSub1)
			self:maxwidth((infoW - bannerW - 140) / 0.48)
		end,
		OnCommand = function(self)
			if song then
				local artist = song:GetDisplayArtist()
				local subtitle = song:GetDisplaySubTitle()
				if subtitle ~= "" then
					self:settext(subtitle .. " - " .. artist)
				else
					self:settext("// " .. artist)
				end
			else
				self:settext("// Unknown Artist")
			end
		end
	},

	-- Rate Text
	LoadFont("Common Normal")..{
		Name = "RateText",
		InitCommand = function(self)
			self:xy(infoW/2 - bannerW - 35, 0):zoom(0.50):diffuse(COLOR.TextSub1)
			self:settextf("%.2fx Rate", getMusicRate())
		end,
		RateUpdateCommand = function(self)
			self:settextf("%.2fx Rate", getMusicRate())
		end
	},

	-- Song Banner Image (Rightmost)
	Def.Sprite{
		InitCommand = function(self)
			self:xy(infoW/2 - bannerW/2 - 2, 0)
		end,
		OnCommand = function(self)
			if song and song:HasBanner() then
				self:visible(true)
				self:LoadBackground(song:GetBannerPath())
				self:scaletoclipped(bannerW, bannerH)
			else
				self:visible(false)
			end
		end
	}
}


-- Left Column Card 1: Steps List Display (Song Select Screen Style)
local stepsListCard = Def.ActorFrame{
	InitCommand = function(self)
		self:xy(leftX, stepsListY)
	end,

	-- Card Shadow
	Def.Quad{
		InitCommand = function(self)
			self:zoomto(leftW, stepsListH):xy(4, 4):diffuse(COLOR.MainHighlight)
		end
	},
	-- Card Border
	UIElements.Border(leftW, stepsListH, 1)..{
		InitCommand = function(self)
			self:diffuse(COLOR.MainBorder)
		end
	},
	-- Card Background
	Def.Quad{
		InitCommand = function(self)
			self:zoomto(leftW, stepsListH):diffuse(COLOR.MainBackground)
		end
	},

	-- Title Bar
	LoadFont("Common Normal")..{
		InitCommand = function(self)
			self:xy(0, -stepsListH/2 + 16):zoom(0.52):diffuse(COLOR.TextSub2)
			self:settext("DIFFICULTIES")
		end
	},
}

for i = 1, 6 do
	local itemY = -stepsListH/2 + 38 + (i - 1) * 28
	stepsListCard[#stepsListCard+1] = Def.ActorFrame{
		InitCommand = function(self)
			self:xy(0, itemY)
		end,

		-- Quad Highlight
		Def.Quad{
			Name = "ItemBg",
			InitCommand = function(self)
				self:zoomto(leftW - 20, 24)
			end,
			UpdateCommand = function(self)
				local chartList = StepsForSong(song)
				local chart = chartList[i]
				if chart then
					self:visible(true)
					self:diffuse(GetDifficultyColor(chart:GetDifficulty()))
					self:diffusealpha(chart == steps and 0.38 or 0.12)
				else
					self:visible(false)
				end
			end,
			OnCommand = function(self) self:playcommand("Update") end,
			StepsUpdateCommand = function(self) self:playcommand("Update") end,
			RateUpdateCommand = function(self) self:playcommand("Update") end,
		},

		-- Difficulty Name
		LoadFont("Common Normal")..{
			Name = "DiffText",
			InitCommand = function(self)
				self:xy(-leftW/2 + 20, 0):halign(0):zoom(0.44)
			end,
			UpdateCommand = function(self)
				local chartList = StepsForSong(song)
				local chart = chartList[i]
				if chart then
					self:settext(GetDifficultyLabel(chart:GetDifficulty()))
					self:diffuse(chart == steps and COLOR.MainHighlight or COLOR.TextMain)
				else
					self:settext("")
				end
			end,
			OnCommand = function(self) self:playcommand("Update") end,
			StepsUpdateCommand = function(self) self:playcommand("Update") end,
		},

		-- MSD Value
		LoadFont("Common Normal")..{
			Name = "MsdText",
			InitCommand = function(self)
				self:xy(leftW/2 - 20, 0):halign(1):zoom(0.42)
			end,
			UpdateCommand = function(self)
				local chartList = StepsForSong(song)
				local chart = chartList[i]
				if chart then
					local rate = getMusicRate()
					self:settextf("MSD %.2f", OverallMSD(chart, rate))
					self:diffuse(GetDifficultyColor(chart:GetDifficulty()))
				else
					self:settext("")
				end
			end,
			OnCommand = function(self) self:playcommand("Update") end,
			StepsUpdateCommand = function(self) self:playcommand("Update") end,
			RateUpdateCommand = function(self) self:playcommand("Update") end,
		},

		-- Interactive Click Button
		UIElements.QuadButton(1, 1)..{
			InitCommand = function(self)
				self:zoomto(leftW - 20, 24):diffusealpha(0)
			end,
			MouseClickCommand = function(self)
				local chartList = StepsForSong(song)
				local chart = chartList[i]
				if chart then
					steps = chart
					GAMESTATE:SetCurrentSteps(pn, chart)
					MESSAGEMAN:Broadcast("CurrentStepsP1Changed", {ptr = chart, Steps = chart})
				end
			end
		}
	}
end

t[#t+1] = stepsListCard


-- Left Column Card 2: Note Count Breakdown
local noteCountCard = Def.ActorFrame{
	InitCommand = function(self)
		self:xy(leftX, noteCountY)
	end,

	-- Card Shadow
	Def.Quad{
		InitCommand = function(self)
			self:zoomto(leftW, noteCountH):xy(4, 4):diffuse(COLOR.MainHighlight)
		end
	},
	-- Card Border
	UIElements.Border(leftW, noteCountH, 1)..{
		InitCommand = function(self)
			self:diffuse(COLOR.MainBorder)
		end
	},
	-- Card Background
	Def.Quad{
		InitCommand = function(self)
			self:zoomto(leftW, noteCountH):diffuse(COLOR.MainBackground)
		end
	},

	-- Title Bar
	LoadFont("Common Normal")..{
		InitCommand = function(self)
			self:xy(0, -noteCountH/2 + 20):zoom(0.55):diffuse(COLOR.TextSub2)
			self:settext("NOTE COUNT")
		end
	},
}

local numRows = #counts
local rowSpacing = (noteCountH - 60) / numRows

for i, entry in ipairs(counts) do
	local rowY = -noteCountH/2 + 45 + (i - 1) * rowSpacing
	noteCountCard[#noteCountCard+1] = Def.ActorFrame{
		InitCommand = function(self)
			self:xy(0, rowY)
		end,

		LoadFont("Common Normal")..{
			InitCommand = function(self)
				self:xy(-leftW/2 + 20, 0):halign(0):zoom(0.48):diffuse(COLOR.TextSub1)
				self:settext(entry[1])
			end
		},
		LoadFont("DFPGothic 64px")..{
			InitCommand = function(self)
				self:xy(leftW/2 - 20, 0):halign(1):zoom(0.32):diffuse(COLOR.TextMain)
			end,
			UpdateCommand = function(self)
				self:settext(tostring(radar(entry[2])))
			end,
			OnCommand = function(self) self:playcommand("Update") end,
			StepsUpdateCommand = function(self) self:playcommand("Update") end,
		}
	}
end

t[#t+1] = noteCountCard


-- Center Note Field Area with Dark Filter
t[#t+1] = Def.ActorFrame{
	InitCommand = function(self) self:xy(SCREEN_CENTER_X, panelY) end,

	-- Dark Semi-Translucent Filter Quad Behind Notefield
	Def.Quad{
		InitCommand = function(self)
			self:zoomto(260, mainH):diffuse(color("#000000")):diffusealpha(0.65)
		end
	},

	-- NoteFieldPreview Component
	Def.NoteFieldPreview{
		Name = "NFPreview",
		InitCommand = function(self)
			if steps then pcall(function() self:LoadNoteData(steps) end) end
			self:zoom(0.95):draworder(10)
		end,
		StepsUpdateCommand = function(self)
			if steps then pcall(function() self:LoadNoteData(steps) end) end
		end,
	},
}


-- Right Column Area: Rate Control & BPM Card + Chord Density Graph Card
local rightArea = Def.ActorFrame{
	InitCommand = function(self) self:xy(rightX, 0) end,
}

-- Right Card 1: Rate Control & BPM Card
local rateCard = Def.ActorFrame{
	InitCommand = function(self)
		self:xy(0, rateCardY)
	end,

	-- Card Shadow
	Def.Quad{
		InitCommand = function(self)
			self:zoomto(rightW, rateCardH):xy(4, 4):diffuse(COLOR.MainHighlight)
		end
	},
	-- Card Border
	UIElements.Border(rightW, rateCardH, 1)..{
		InitCommand = function(self)
			self:diffuse(COLOR.MainBorder)
		end
	},
	-- Card Background
	Def.Quad{
		InitCommand = function(self)
			self:zoomto(rightW, rateCardH):diffuse(COLOR.MainBackground)
		end
	},

	-- BPM Display
	LoadFont("Common Normal")..{
		Name = "BpmDisplay",
		InitCommand = function(self)
			self:xy(0, -18):zoom(0.52):diffuse(COLOR.TextMain)
		end,
		UpdateCommand = function(self)
			if not steps or not steps.GetTimingData then
				self:settext("")
				return
			end

			local ok, bpms = pcall(function()
				return steps:GetTimingData():GetActualBPM()
			end)
			if not ok or not bpms or not bpms[1] or not bpms[2] then
				self:settext("")
				return
			end

			local rate = getMusicRate()
			local minBpm = math.floor(bpms[1] * rate + 0.5)
			local maxBpm = math.floor(bpms[2] * rate + 0.5)
			if minBpm == maxBpm then
				self:settextf("%d BPM", minBpm)
			else
				self:settextf("%d - %d BPM", minBpm, maxBpm)
			end
		end,
		OnCommand = function(self) self:playcommand("Update") end,
		RateUpdateCommand = function(self) self:playcommand("Update") end,
		StepsUpdateCommand = function(self) self:playcommand("Update") end,
	},

	-- Rate Adjust - Button
	Def.ActorFrame{
		InitCommand = function(self) self:xy(-55, 15) end,

		Def.Quad{
			Name = "MinusBg",
			InitCommand = function(self)
				self:zoomto(35, 24):diffuse(COLOR.MainBackground)
			end
		},
		UIElements.Border(35, 24, 1)..{
			InitCommand = function(self) self:diffuse(COLOR.MainBorder) end
		},
		LoadFont("Common Normal")..{
			InitCommand = function(self) self:zoom(0.6):diffuse(COLOR.TextMain):settext("-") end
		},
		UIElements.QuadButton(1, 1)..{
			InitCommand = function(self) self:zoomto(35, 24):diffusealpha(0) end,
			MouseClickCommand = function(self)
				setMusicRate(getMusicRate() - 0.05)
			end
		}
	},

	-- Current Rate Text
	LoadFont("Common Normal")..{
		Name = "RateDisplay",
		InitCommand = function(self)
			self:xy(0, 15):zoom(0.50):diffuse(COLOR.TextSub1)
		end,
		UpdateCommand = function(self)
			self:settextf("%.2fx", getMusicRate())
		end,
		OnCommand = function(self) self:playcommand("Update") end,
		RateUpdateCommand = function(self) self:playcommand("Update") end,
	},

	-- Rate Adjust + Button
	Def.ActorFrame{
		InitCommand = function(self) self:xy(55, 15) end,

		Def.Quad{
			Name = "PlusBg",
			InitCommand = function(self)
				self:zoomto(35, 24):diffuse(COLOR.MainBackground)
			end
		},
		UIElements.Border(35, 24, 1)..{
			InitCommand = function(self) self:diffuse(COLOR.MainBorder) end
		},
		LoadFont("Common Normal")..{
			InitCommand = function(self) self:zoom(0.6):diffuse(COLOR.TextMain):settext("+") end
		},
		UIElements.QuadButton(1, 1)..{
			InitCommand = function(self) self:zoomto(35, 24):diffusealpha(0) end,
			MouseClickCommand = function(self)
				setMusicRate(getMusicRate() + 0.05)
			end
		}
	}
}

rightArea[#rightArea+1] = rateCard


-- Right Card 2: Full Area CD Graph with Cursor Hover & Seeking
local hoverY = 0
local hoverActive = false

local function updateGraphHover(button, params)
	if not song or cdRows <= 0 then return end
	local parent = button:GetParent()
	local mouseX = INPUTFILTER:GetMouseX()
	local mouseY = INPUTFILTER:GetMouseY()
	local inside = mouseX >= rightX - rightW/2 and mouseX <= rightX + rightW/2 and
		mouseY >= cdGraphY - cdGraphH/2 and mouseY <= cdGraphY + cdGraphH/2
	if not inside then
		hoverActive = false
		parent:GetChild("HoverTooltip"):visible(false)
		parent:GetChild("HoverLine"):visible(false)
		return
	end
	local localY = mouseY - cdGraphY
	localY = math.max(-cdGraphH/2, math.min(cdGraphH/2, localY))
	local ratio = (localY + cdGraphH/2) / cdGraphH
	local duration = song:GetLastSecond() or 1
	local targetSec = ratio * duration

	local rowIdx = math.max(1, math.min(cdRows, math.floor(ratio * cdRows + 1)))
	local rowNPS = 0
	if cdVectors and cdVectors[1] and cdVectors[1][rowIdx] then
		-- GetCDGraphVectors()[1] is the already-aggregated NPS vector.
		-- The remaining vectors are the per-column density layers used to draw the graph.
		rowNPS = cdVectors[1][rowIdx]
	end

	local hoverLine = parent:GetChild("HoverLine")
	hoverLine:visible(true):y(localY)
	local hoverTooltip = parent:GetChild("HoverTooltip")
	hoverTooltip:visible(true):y(localY)
	if localY < -cdGraphH/2 + 30 then
		hoverTooltip:y(localY + 18)
	elseif localY > cdGraphH/2 - 30 then
		hoverTooltip:y(localY - 18)
	end
	local minutes = math.floor(targetSec / 60)
	local seconds = math.floor(targetSec % 60)
	hoverTooltip:GetChild("HoverText"):settextf("%.1f NPS  %d:%02d", rowNPS, minutes, seconds)
end

local function getCurrentMusicSecond()
	local second
	if GAMESTATE and GAMESTATE.GetCurMusicSeconds then
		second = GAMESTATE:GetCurMusicSeconds()
	end
	if (not second or second < 0) and SCREENMAN:GetTopScreen() then
		local top = SCREENMAN:GetTopScreen()
		if top.GetMusicSeconds then second = top:GetMusicSeconds() end
	end
	return math.max(0, second or 0)
end

local function updateSeekLine(card)
	if not song or cdRows <= 0 or hoverActive then return end
	local duration = song:GetLastSecond() or 1
	local ratio = math.max(0, math.min(1, getCurrentMusicSecond() / duration))
	local line = card:GetChild("HoverLine")
	line:visible(true):y(ratio * cdGraphH - cdGraphH/2)
end

local cdGraphCard = Def.ActorFrame{
	InitCommand = function(self)
		self:xy(0, cdGraphY)
		self:SetUpdateFunction(function(actor)
			if hoverActive then
				updateGraphHover(actor:GetChild("GraphButton"), {})
			else
				updateSeekLine(actor)
			end
			return false
		end)
	end,

	-- Card Shadow
	Def.Quad{
		InitCommand = function(self)
			self:zoomto(rightW, cdGraphH):xy(4, 4):diffuse(COLOR.MainHighlight)
		end
	},
	-- Card Border
	UIElements.Border(rightW, cdGraphH, 1)..{
		InitCommand = function(self)
			self:diffuse(COLOR.MainBorder)
		end
	},
	-- Card Background
	Def.Quad{
		InitCommand = function(self)
			self:zoomto(rightW, cdGraphH):diffuse(COLOR.MainBackground)
		end
	},

	-- MultiVertex CD Graph
	Def.ActorMultiVertex{
		Name="DensityGraph",
		InitCommand=function(self) self:queuecommand("DrawDensity") end,
		DrawDensityCommand=drawDensity,
		RateUpdateCommand=drawDensity,
		StepsUpdateCommand=drawDensity,
	},

	-- Hover Line Quad
	Def.Quad{
		Name = "HoverLine",
		InitCommand = function(self)
			self:zoomto(rightW, 2):diffuse(COLOR.MainHighlight):visible(false)
		end
	},

	-- Hover Info Tooltip Badge
	Def.ActorFrame{
		Name = "HoverTooltip",
		InitCommand = function(self)
			self:visible(false)
		end,

		Def.Quad{
			InitCommand = function(self)
				self:zoomto(130, 24):diffuse(color("#000000")):diffusealpha(0.85)
			end
		},
		LoadFont("Common Normal")..{
			Name = "HoverText",
			InitCommand = function(self)
				self:zoom(0.48):diffuse(COLOR.TextMainLight)
			end
		}
	},

	-- QuadButton for Mouse Hover & Seek Clicking
	UIElements.QuadButton(1, 1)..{
		Name = "GraphButton",
		InitCommand = function(self)
			self:zoomto(rightW, cdGraphH):diffusealpha(0)
		end,

		MouseOverCommand = function(self)
			hoverActive = true
			updateGraphHover(self, self)
		end,
		MouseOutCommand = function(self)
			hoverActive = false
			local parent = self:GetParent()
			updateSeekLine(parent)
			parent:GetChild("HoverTooltip"):visible(false)
		end,

		MouseMoveCommand = function(self, params) updateGraphHover(self, params) end,
		MouseDragCommand = function(self, params) updateGraphHover(self, params) end,
		MouseDownCommand = function(self, params)
			if params.event == "DeviceButton_left mouse button" and song then
				local ratio = math.max(0, math.min(1,
					(INPUTFILTER:GetMouseY() - (cdGraphY - cdGraphH/2)) / cdGraphH))
				seekToSecond(ratio * (song:GetLastSecond() or 1))
			end
		end,

		MouseClickCommand = function(self, params)
			if not song then return end
			local localY = INPUTFILTER:GetMouseY() - cdGraphY
			localY = math.max(-cdGraphH/2, math.min(cdGraphH/2, localY))
			local ratio = (localY + cdGraphH/2) / cdGraphH
			local duration = song:GetLastSecond() or 1
			local targetSec = ratio * duration
			seekToSecond(targetSec)
		end
	}
}

rightArea[#rightArea+1] = cdGraphCard

t[#t+1] = rightArea

return t
