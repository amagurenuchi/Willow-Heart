local Values = { Song = nil, Steps = nil, Rate = 1 }
local rowY = -70

local function StepsForSong(song)
	if not song then return {} end
	if song.GetChartsMatchingFilter then return song:GetChartsMatchingFilter() or {} end
	return song.GetAllSteps and song:GetAllSteps() or {}
end

local function OverallMSD(chart)
	if not chart or not chart.GetMSD then return 0 end
	local value = chart:GetMSD(Values.Rate or 1, 1)
	return value and value == value and value >= 0 and value or 0
end

local t = Def.ActorFrame{
	InitCommand = function(self)
		self:playcommand("Update")
	end,
	UpdateCommand = function(self, params)
		Values.Song = (params and params.Song) or GAMESTATE:GetCurrentSong()
		Values.Steps = (params and params.Steps) or GAMESTATE:GetCurrentSteps(PLAYER)
		local options = GAMESTATE:GetSongOptionsObject('ModsLevel_Current')
		Values.Rate = options and options:MusicRate() or 1
		self:PlayCommandsOnChildren("Update")
	end,
	SongUpdateCommand = function(self, params) self:playcommand("Update", params) end,
	StepsUpdateCommand = function(self, params) self:playcommand("Update", params) end,
	RateUpdateCommand = function(self, params) self:playcommand("Update", params) end,
	CurrentStepsChangedMessageCommand = function(self, params)
		Values.Steps = params and (params.ptr or params.Steps) or GAMESTATE:GetCurrentSteps(PLAYER)
		self:playcommand("Update")
	end,
}

for i = 1, 7 do
	t[#t+1] = Def.Quad{
		InitCommand = function(self)
			self:xy(46, rowY + (i - 1) * 34):zoomto(92, 31)
		end,
		UpdateCommand = function(self)
			local chart = StepsForSong(Values.Song)[i]
			self:diffuse(chart and GetDifficultyColor(chart:GetDifficulty()) or COLOR.MainBorder)
			self:diffusealpha(chart and (chart == Values.Steps and 0.34 or 0.12) or 0)
		end,
		SongUpdateCommand = function(self) self:playcommand("Update") end,
		StepsUpdateCommand = function(self) self:playcommand("Update") end,
		RateUpdateCommand = function(self) self:playcommand("Update") end,
	}
	t[#t+1] = LoadFont("Common Normal") .. {
		InitCommand = function(self)
			self:xy(4, rowY + (i - 1) * 34 - 5):halign(0):zoom(0.44):maxwidth(84 / 0.44)
		end,
		UpdateCommand = function(self)
			local chart = StepsForSong(Values.Song)[i]
			if chart then
				self:settext(GetDifficultyLabel(chart:GetDifficulty())):diffuse(chart == Values.Steps and COLOR.MainHighlight or COLOR.TextMain)
			else
				self:settext("")
			end
		end,
		SongUpdateCommand = function(self) self:playcommand("Update") end,
		StepsUpdateCommand = function(self) self:playcommand("Update") end,
	}
	t[#t+1] = LoadFont("Common Normal") .. {
		InitCommand = function(self)
			self:xy(4, rowY + (i - 1) * 34 + 7):halign(0):zoom(0.38):maxwidth(84 / 0.38)
		end,
		UpdateCommand = function(self)
			local chart = StepsForSong(Values.Song)[i]
			self:settext(chart and string.format("MSD  %.2f", OverallMSD(chart)) or "")
			self:diffuse(chart and GetDifficultyColor(chart:GetDifficulty()) or COLOR.TextSub1)
		end,
		SongUpdateCommand = function(self) self:playcommand("Update") end,
		StepsUpdateCommand = function(self) self:playcommand("Update") end,
		RateUpdateCommand = function(self) self:playcommand("Update") end,
	}
end

return t
