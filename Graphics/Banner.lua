local args = ... or {}

local Values = {
    Song = nil,
    Steps = nil,
    Group = nil,
    BannerWidth = 448,
    BannerHeight = 140,
    FrameWidth = 448+20,
	FrameHeight = 140+40,
	CDTitleSize = 100,
    BorderSize = 1,
    BorderShadowOffSet = 5,
    ButtonZ = 0,
	Rate = 1,
	UseDisplayBPM = false,
}

local function SetValues(args)
	for k,v in pairs(args) do
		Values[k] = v
	end
end


local t = Def.ActorFrame{
	InitCommand = function(self)
		SetValues(args)
		self:playcommand("Update",args)
	end,
	UpdateCommand = function(self, params)
		SetValues(params)
		-- Event payloads are authoritative.  In particular, Song = nil means
		-- the wheel is on a group/empty entry and must clear the old song;
		-- falling back to GAMESTATE here leaks the previous song's BPM.
		if params and params.Song ~= nil then
			Values.Song = params.Song
		elseif params and params.Group ~= nil then
			Values.Song = nil
		else
			Values.Song = GAMESTATE:GetCurrentSong()
		end
		if params and params.Steps ~= nil then
			Values.Steps = params.Steps
		elseif params and params.Group ~= nil then
			Values.Steps = nil
		else
			Values.Steps = GAMESTATE:GetCurrentSteps(PLAYER)
		end
		if GAMESTATE:GetSongOptionsObject('ModsLevel_Current') then
			Values.Rate = GAMESTATE:GetSongOptionsObject('ModsLevel_Current'):MusicRate()
		else
			Values.Rate = 1
		end
		self:PlayCommandsOnChildren("Update")
    end,
	SongUpdateCommand = function(self, params)
		self:playcommand("Update", params)
    end,
	StepsUpdateCommand = function(self, params)
		self:playcommand("Update", params)
    end,
	RateUpdateCommand = function(self, params)
		self:playcommand("Update", params)
    end,
}

t[#t+1] = Def.Quad{
    InitCommand = function(self)
        self:zoomto(Values.FrameWidth, Values.FrameHeight)
        self:xy(Values.BorderShadowOffSet, Values.BorderShadowOffSet)
        self:diffuse(COLOR.MainHighlight)
    end,
}
-- Border
t[#t+1] = UIElements.Border(Values.FrameWidth,Values.FrameHeight,Values.BorderSize)..{
	UpdateCommand = function(self)
		self:diffuse(COLOR.MainBorder)
		self:GetChild("MaskSource"):zoomto(Values.FrameWidth, Values.FrameHeight)
		self:GetChild("MaskDest"):zoomto(Values.FrameWidth+Values.BorderSize*2, Values.FrameHeight+Values.BorderSize*2)
	end
}

t[#t+1] = Def.Quad{
    InitCommand = function(self)
        self:zoomto(Values.FrameWidth, Values.FrameHeight)
        self:diffuse(COLOR.MainBackground)
    end,
}


t[#t+1] = Def.Quad{
    InitCommand = function(self)
        self:zoomto(Values.BannerWidth, Values.BannerHeight)
        self:diffuse(COLOR.MainBorder)
    end,
}


-- Song banner
t[#t+1] = Def.Sprite {
	Name = "Banner",
    UpdateCommand = function(self)
        local bannerPath = nil
		if Values.Song then
            bannerPath = Values.Song:GetBannerPath()
        elseif Values.Group then
            bannerPath = SONGMAN:GetSongGroupBannerPath(Values.Group)
        end
		if bannerPath then
			self:diffusealpha(1)
		    self:LoadBackground(bannerPath)
            self:scaletoclipped(Values.BannerWidth, Values.BannerHeight)
		else
			self:diffusealpha(0)
		end
	end,
	SongUpdateCommand = function(self) self:playcommand("Update") end,
}

-- The CD title
t[#t+1] = Def.Sprite {
	Name = "CDTitle",
	InitCommand = function(self)
		self:xy(Values.BannerWidth/2, -Values.BannerHeight/2)
		self:wag():effectmagnitude(0,0,5)
		self:diffusealpha(0.8)
	end,
	UpdateCommand = function(self)
		if Values.Song and Values.Song:HasCDTitle() then
			self:visible(true)
			self:Load(Values.Song:GetCDTitlePath())
		else
			self:visible(false)
		end
		self:playcommand("AdjustSize")
	end,
	AdjustSizeCommand = function(self)
		local maxDimension = math.max(self:GetHeight(),self:GetWidth())
		if maxDimension > Values.CDTitleSize then
			self:zoom(Values.CDTitleSize/maxDimension)
		else
			self:zoom(1)
		end
	end,
	SongUpdateCommand = function(self) self:playcommand("Update") end,
}

-- Song length
t[#t+1] = LoadFont("Common Normal") .. {
	Name="songLength",
	InitCommand = function(self)
		self:xy(Values.BannerWidth/2-2,Values.BannerHeight/2+12)
		self:halign(1)
		self:zoom(0.5)
		self:diffuse(COLOR.MainBorder)
	end,	
	UpdateCommand = function(self)
		local length = 0
		if Values.Song then
			length = Values.Song:GetStepsSeconds()/Values.Rate
		end
		self:settextf("%s",SecondsToMSS(length))
	end,
	SongUpdateCommand = function(self) self:playcommand("Update") end,
	RateUpdateCommand = function(self) self:playcommand("Update") end
}

-- BPM | Rate Info
t[#t+1] = LoadFont("Common Normal") .. {
	Name="songBPM",
	InitCommand = function(self)
		self:xy(-Values.BannerWidth/2,-Values.BannerHeight/2-10)
		self:halign(0)
		self:zoom(0.5)
		self:diffuse(COLOR.MainBorder)
	end,	
	UpdateCommand = function(self)
		local song = Values.Song
		local steps = Values.Steps
		local rate = Values.Rate or (GAMESTATE:GetSongOptionsObject('ModsLevel_Current') and GAMESTATE:GetSongOptionsObject('ModsLevel_Current'):MusicRate() or 1)

		if song then
			if Values.UseDisplayBPM then
				local bpms = song:GetDisplayBpms()
				if bpms[1] ~= nil and math.floor(bpms[1]) == math.floor(bpms[2]) then
					self:settext(string.format("BPM: %d", math.round(bpms[1]*rate)))
				else
					self:settext(string.format("BPM: %d-%d", math.round(bpms[1]*rate), math.round(bpms[2]*rate)))
				end
			elseif steps then
				local bpms = steps:GetTimingData():GetActualBPM()
				if bpms[1] ~= nil and math.floor(bpms[1]) == math.floor(bpms[2]) then
					self:settext(string.format("BPM: %d", math.round(bpms[1]*rate)))
				else
					self:settext(string.format("BPM: %d (%d-%d)", math.round(GetCommonBPM(song:GetTimingData():GetBPMsAndTimes(true), song:GetLastBeat())), math.round(bpms[1]*rate), math.round(bpms[2]*rate)))
				end
			else
				local bpms = song:GetTimingData():GetActualBPM()
				if bpms[1] ~= nil and math.floor(bpms[1]) == math.floor(bpms[2]) then
					self:settext(string.format("BPM: %d", math.round(bpms[1]*rate)))
				else
					self:settext(string.format("BPM: %d (%d-%d)", math.round(GetCommonBPM(song:GetTimingData():GetBPMsAndTimes(true), song:GetLastBeat())), math.round(bpms[1]*rate), math.round(bpms[2]*rate)))
				end
			end
		else
			self:settext("BPM: 0")
		end
	end,
	SongUpdateCommand = function(self) self:playcommand("Update") end,
	StepsUpdateCommand = function(self) self:playcommand("Update") end,
	RateUpdateCommand = function(self) self:playcommand("Update") end
}

-- Gradient over banner when rate is not 1.0
t[#t+1] = Def.Quad{
	InitCommand = function(self)
		self:xy(Values.BannerWidth/2,Values.BannerHeight/2)
		self:zoomto(Values.BannerWidth, 40)
		self:diffuse(COLOR.MainBorder):diffusealpha(0.6)
		self:halign(1):valign(1)
		self:fadetop(1)
	end,
	UpdateCommand = function(self)
		if Values.Rate == 1 then
			self:stoptweening()
			self:smooth(0.2)
			self:diffusealpha(0)
		else
			self:stoptweening()
			self:smooth(0.2)
			self:diffusealpha(0.6)
		end
	end,
	RateUpdateCommand = function(self) self:playcommand("Update") end
}

return t
