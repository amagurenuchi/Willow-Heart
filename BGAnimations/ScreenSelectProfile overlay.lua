local info = {
	Title = THEME:GetString("ScreenSelectProfile", "Title"),
	SongPlayed = THEME:GetString("ScreenSelectProfile", "SongPlayed"),
	SongsPlayed = THEME:GetString("ScreenSelectProfile", "SongsPlayed"),
	NoProfile = THEME:GetString("GeneralInfo", "NoProfile"),
	PressStart = THEME:GetString("ScreenSelectProfile", "PressStartToJoin"),
}

local function Profiles()
	local result = {}
	for i = 0, PROFILEMAN:GetNumLocalProfiles() - 1 do
		local id = PROFILEMAN:GetLocalProfileIDFromIndex(i)
		local profile = PROFILEMAN:GetLocalProfileFromIndex(i)
		result[#result + 1] = Def.ActorFrame {
			Name = i,
			Def.Quad {
				InitCommand = function(self) self:y(-3):zoomto(260, 42):diffusealpha(0) end,
			},
			UIElements.TextButton(1, 1, "Common Large") .. {
				Name = "PlayerName",
				InitCommand = function(self)
					local text, bg = self:GetChild("Text"), self:GetChild("BG")
					self:x(19):y(-12)
					text:settextf("%s: %.2f", profile:GetDisplayName(), profile:GetPlayerRating())
					text:zoom(0.4):maxwidth(540)
					bg:y(-3):zoomto(260, 42)
					self:z(PROFILEMAN:GetNumLocalProfiles() - i)
				end,
				ClickCommand = function(self, params)
					if params.update == "OnMouseDown" and params.event == "DeviceButton_left mouse button" then
						SCREENMAN:GetTopScreen():SetProfileIndex(PLAYER_1, self:GetParent():GetName() + 1)
						SCREENMAN:GetTopScreen():Finish()
					end
				end,
				RolloverUpdateCommand = function(self, params)
					local alpha = params.update == "in" and 0.8 or 1
					self:diffusealpha(alpha)
					self:GetParent():GetChild("SongsPlayed"):diffusealpha(alpha)
				end,
			},
			LoadFont("Common Normal") .. {
				Name = "SongsPlayed",
				InitCommand = function(self) self:xy(19, 8):zoom(0.5):maxwidth(390) end,
				BeginCommand = function(self) self:settextf("%i %s", profile:GetNumTotalSongsPlayed(), info.SongsPlayed) end,
			},
			Def.Sprite {
				InitCommand = function(self) self:halign(0):xy(-127, -3):zoomto(36, 36) end,
				BeginCommand = function(self) self:Load(getAssetPathFromProfileID("avatar", id)) end,
			},
		}
	end
	return result
end

local function Card(colorValue)
	return Def.ActorFrame {
		Def.Quad { InitCommand = function(self) self:zoomto(264, 234):diffuse(Color.White) end },
		Def.Quad { InitCommand = function(self) self:zoomto(260, 230):diffusealpha(0.5):diffuse(colorValue) end },
	}
end

local function PlayerContents()
	return {
		Def.ActorFrame {
			Name = "JoinFrame", Card(Color("Purple")),
			LoadFont("Common Normal") .. { Text = info.PressStart, InitCommand = function(self) self:shadowlength(1) end },
		},
		Def.ActorFrame { Name = "BigFrame", Card(Brightness(getMainColor("positive"), 0.3)) },
		Def.ActorFrame {
			Name = "SmallFrame",
			Def.Quad { InitCommand = function(self) self:zoomto(260, 42):diffusealpha(0.3) end },
		},
		Def.ActorScroller {
			Name = "Scroller", NumItemsToDraw = 6,
			OnCommand = function(self) self:y(1):SetFastCatchup(true):SetMask(270, 58):SetSecondsPerItem(0.15) end,
			TransformFunction = function(self, offset) self:visible(false):y(math.floor(offset * 42)):z(offset) end,
			children = Profiles(),
		},
		LoadFont("Common Normal") .. { Name = "SelectedProfileText", InitCommand = function(self) self:y(160):maxwidth(SCREEN_WIDTH * 0.9):visible(false) end },
	}
end

local function Update(self)
	local frame = self:GetChild("P1Frame")
	local scroller, selected = frame:GetChild("Scroller"), frame:GetChild("SelectedProfileText")
	local join, small, big = frame:GetChild("JoinFrame"), frame:GetChild("SmallFrame"), frame:GetChild("BigFrame")
	if GAMESTATE:IsHumanPlayer() then
		frame:visible(true):visible(true); join:visible(false); small:visible(true); big:visible(true); selected:visible(false); scroller:visible(true)
		local index = SCREENMAN:GetTopScreen():GetProfileIndex(PLAYER_1)
		if index > 0 then
			scroller:SetDestinationItem(index - 1)
		else
			if SCREENMAN:GetTopScreen():SetProfileIndex(PLAYER_1, 1) then scroller:SetDestinationItem(0); self:queuecommand("UpdateInternal2")
			else join:visible(true); small:visible(false); big:visible(false); scroller:visible(false); selected:visible(true):settext(info.NoProfile) end
		end
	else join:visible(true); scroller:visible(false); selected:visible(false); small:visible(false); big:visible(false) end
end

local t = Def.ActorFrame {
	BeginCommand = function(self)
		SCREENMAN:GetTopScreen():AddInputCallback(function(event)
			if event.type ~= "InputEventType_FirstPress" then return end
			local screen = SCREENMAN:GetTopScreen()
			if event.button == "Start" then
				if not GAMESTATE:IsHumanPlayer() then screen:SetProfileIndex(PLAYER_1, -1) end
				screen:Finish()
			elseif event.button == "Back" then screen:Cancel()
			elseif (event.button == "MenuUp" or event.button == "Up") and GAMESTATE:IsHumanPlayer() then
				local i = screen:GetProfileIndex(PLAYER_1)
				if i > 1 and screen:SetProfileIndex(PLAYER_1, i - 1) then self:queuecommand("UpdateInternal2") end
			elseif (event.button == "MenuDown" or event.button == "Down") and GAMESTATE:IsHumanPlayer() then
				local i = screen:GetProfileIndex(PLAYER_1)
				if i > 0 and screen:SetProfileIndex(PLAYER_1, i + 1) then self:queuecommand("UpdateInternal2") end
			end
		end)
	end,
	OnCommand = function(self) self:queuecommand("UpdateInternal2") end,
	StorageDevicesChangedMessageCommand = function(self) self:queuecommand("UpdateInternal2") end,
	PlayerJoinedMessageCommand = function(self) self:queuecommand("UpdateInternal2") end,
	PlayerUnjoinedMessageCommand = function(self) self:queuecommand("UpdateInternal2") end,
	UpdateInternal2Command = Update,
	children = { Def.ActorFrame { Name = "P1Frame", InitCommand = function(self) self:Center() end, children = PlayerContents() } },
}

return t
