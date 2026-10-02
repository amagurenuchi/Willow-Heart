-- Stage information shown between song selection and gameplay.

local song = GAMESTATE:GetCurrentSong()
local steps = GAMESTATE:GetCurrentSteps(PLAYER_1)

local function DifficultyName()
	if not steps then return "" end
	return GetDifficultyName(steps:GetDifficulty())
end

local function StepsMSD()
	if not steps or not steps.GetMSD then return "" end
	local options = GAMESTATE:GetSongOptionsObject('ModsLevel_Current')
	local rate = options and options.MusicRate and options:MusicRate() or 1
	local msd = steps:GetMSD(rate, 1)
	return msd and string.format("%.2f", msd) or ""
end

local function CurrentRate()
	local options = GAMESTATE:GetSongOptionsObject('ModsLevel_Current')
	return options and options.MusicRate and options:MusicRate() or 1
end

local title = song and song:GetDisplayMainTitle() or "READY"
local subtitle = song and song:GetDisplaySubTitle() or ""
local artist = song and song:GetDisplayArtist() or ""

local t = Def.ActorFrame{
	OnCommand = function(self)
		_G.willowHeartStageInformationShown = true
		-- ScreenStageInformation is a theme-defined screen, so advance it
		-- explicitly instead of depending on menu-screen timer behavior.
		self:sleep(5):queuecommand("GoToGameplay")
	end,
	GoToGameplayCommand = function(self)
		local screen = SCREENMAN:GetTopScreen()
		if screen then
			screen:SetNextScreenName("ScreenGameplay")
			screen:StartTransitioningScreen("SM_GoToNextScreen")
		end
	end,
}

-- Keep the transition readable over any song background.
t[#t+1] = Def.Quad{
	InitCommand = function(self)
		self:xy(SCREEN_CENTER_X, SCREEN_CENTER_Y)
			:zoomto(SCREEN_WIDTH, SCREEN_HEIGHT)
			:diffuse(color("0,0,0,0.46"))
	end,
}

t[#t+1] = Def.ActorFrame{
	InitCommand = function(self)
		self:xy(SCREEN_CENTER_X, SCREEN_CENTER_Y)
	end,
	OnCommand = function(self)
		self:diffusealpha(0):zoom(0.96):decelerate(0.24):diffusealpha(1):zoom(1)
	end,
	Def.Quad{
		InitCommand = function(self)
			self:zoomto(940, 270):diffuse(COLOR.MainBackground)
		end,
	},
	Def.Quad{
		InitCommand = function(self)
			self:y(-128):zoomto(940, 4):diffuse(COLOR.MainHighlight)
		end,
	},
	Def.Quad{
		InitCommand = function(self)
			self:y(128):zoomto(940, 2):diffuse(COLOR.MainBorder)
		end,
	},
	LoadFont("DFPGothic 64px")..{
		InitCommand = function(self)
			self:xy(-420, -72):halign(0):maxwidth(820):zoom(0.72):diffuse(COLOR.TextMain)
			self:settext(title)
		end,
	},
	LoadFont("DFPGothic 64px")..{
		InitCommand = function(self)
			self:xy(-420, -22):halign(0):zoom(0.34):diffuse(COLOR.TextMain)
			self:settext(subtitle ~= "" and subtitle or artist)
		end,
	},
	LoadFont("DFPGothic 64px")..{
		InitCommand = function(self)
			self:xy(-420, 48):halign(0):zoom(0.38):diffuse(COLOR.TextMain)
			self:settext(artist)
		end,
	},
	LoadFont("DFPGothic 64px")..{
		InitCommand = function(self)
			self:xy(420, 14):halign(1):zoom(0.48):diffuse(COLOR.MainHighlight)
			self:settext(DifficultyName())
		end,
	},
	LoadFont("DFPGothic 64px")..{
		InitCommand = function(self)
			self:xy(416, 42):halign(1):zoom(0.34):diffuse(COLOR.TextSub1)
			self:settextf("%.2fx", CurrentRate())
		end,
	},
	LoadFont("DFPGothic 64px")..{
		InitCommand = function(self)
			self:xy(420, 72):halign(1):zoom(0.86):diffuse(COLOR.TextMain)
			self:settext(StepsMSD())
			ApplyRawMSDColor(self, song)
		end,
	},
}

-- Fade over the entire stage-information screen just before gameplay.
t[#t+1] = Def.Quad{
	InitCommand = function(self)
		self:xy(SCREEN_CENTER_X, SCREEN_CENTER_Y)
			:zoomto(SCREEN_WIDTH, SCREEN_HEIGHT)
			:diffuse(color("0,0,0,0"))
	end,
	OnCommand = function(self)
		self:sleep(4.4):decelerate(0.6):diffusealpha(1)
	end,
}

return t
