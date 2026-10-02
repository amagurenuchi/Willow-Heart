local args = ... or {}

local Values = {
	AvatarPath = "",
	ProfileName = "",
	Rating = 0,
	Rank = 0,
	FrameWidth = 250,
	FrameHeight = 50,
	BorderSize = 1,
	ButtonZ = 0,
	BackgroundColor = COLOR.MainBackground,
	TextColor = COLOR.TextMain,
	BorderColor = COLOR.MainBorder,
	ProfileTextScale = 0.8,
	RatingTextScale = 0.4
}

local function UpdateOnlineProfile()
	if DLMAN and DLMAN.IsLoggedIn and DLMAN:IsLoggedIn() then
		Values.ProfileName = DLMAN:GetUsername()
		Values.Rating = DLMAN:GetSkillsetRating("Overall") or 0
		Values.Rank = DLMAN:GetSkillsetRank("Overall") or 0
	else
		Values.ProfileName = Values.LocalProfileName or Values.ProfileName
		Values.Rating = Values.LocalRating or Values.Rating
		Values.Rank = Values.LocalRank or Values.Rank
	end
end

local function SetValues(args)
	for k,v in pairs(args) do
		Values[k] = v
	end
	if Values.LocalProfileName == nil then Values.LocalProfileName = Values.ProfileName end
	if Values.LocalRating == nil then Values.LocalRating = Values.Rating end
	if Values.LocalRank == nil then Values.LocalRank = Values.Rank end
end

local t = Def.ActorFrame{
	InitCommand = function(self)
		SetValues(args)
		UpdateOnlineProfile()
		self:playcommand("Update",args)
	end,
	UpdateCommand = function(self, params)
		SetValues(params or {})
		UpdateOnlineProfile()
		self:PlayCommandsOnChildren("Update")
	end,
	LoginMessageCommand = function(self) self:playcommand("Update") end,
	LogOutMessageCommand = function(self) self:playcommand("Update") end,
	OnlineUpdateMessageCommand = function(self) self:playcommand("Update") end
}


-- Border
t[#t+1] = UIElements.Border(Values.FrameWidth,Values.FrameHeight,Values.BorderSize)..{
	UpdateCommand = function(self)
		self:diffuse(COLOR.MainBorder)
		self:GetChild("MaskSource"):zoomto(Values.FrameWidth, Values.FrameHeight)
		self:GetChild("MaskDest"):zoomto(Values.FrameWidth+Values.BorderSize*2, Values.FrameHeight+Values.BorderSize*2)
	end
}

-- Background Button
t[#t+1] = UIElements.QuadButton(Values.ButtonZ)..{
	UpdateCommand = function(self)
		self:zoomto(Values.FrameWidth,Values.FrameHeight)
		self:diffuse(COLOR.MainBackground):diffusealpha(1)
		self:z(Values.ButtonZ)
	end,
	MouseClickCommand = function(self)
		if Values.OnProfileClick then Values.OnProfileClick() end
	end
}


-- Player Avatar
t[#t+1] = Def.Sprite {
	UpdateCommand = function(self)
		self:x(-Values.FrameWidth/2)
		self:halign(0)
		self:Load(Values.AvatarPath ~= "" and Values.AvatarPath or getAvatarPath(PLAYER_1))
		self:zoomto(Values.FrameHeight,Values.FrameHeight)
	end
}

-- Keep the avatar hit area above the card hit area so it can open asset settings.
t[#t+1] = UIElements.QuadButton(Values.ButtonZ + 1)..{
	UpdateCommand = function(self)
		self:x(-Values.FrameWidth/2 + Values.FrameHeight/2):y(0)
		self:zoomto(Values.FrameHeight, Values.FrameHeight)
		self:diffusealpha(0)
		self:z(Values.ButtonZ + 1)
	end,
	MouseClickCommand = function(self)
		if Values.OnAvatarClick then Values.OnAvatarClick() end
	end
}

-- Rating text
t[#t+1] = LoadFont("Common Normal")..{
	UpdateCommand = function(self)
		self:xy(-Values.FrameWidth/2+Values.FrameHeight+5,10)
		self:halign(0)
		self:zoom(Values.RatingTextScale)
		self:diffuse(GetRatingColor(Values.Rating))
		if DLMAN and DLMAN.IsLoggedIn and DLMAN:IsLoggedIn() then
			self:settextf("%0.2f | #%d", Values.Rating, Values.Rank)
		else
			self:settextf("%0.2f", Values.Rating)
		end
	end
}

-- Player Name
t[#t+1] = LoadFont("Common Normal")..{
	UpdateCommand = function(self)
		self:xy(-Values.FrameWidth/2+Values.FrameHeight+5,-5)
		self:halign(0)
		self:zoom(Values.ProfileTextScale)
		self:maxwidth((Values.FrameWidth-Values.FrameHeight-10)/Values.ProfileTextScale)
		self:diffuse(COLOR.TextMain)
		self:settext(Values.ProfileName)
	end
}



return t
