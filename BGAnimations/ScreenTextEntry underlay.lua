-- Text-entry screen presentation ported from Til Death, kept independent of
-- that theme's options-screen and mouse-tooltip helpers.
local t = Def.ActorFrame {}

t[#t + 1] = Def.Quad {
	Name = "BG",
	InitCommand = function(self)
		self:zoomto(SCREEN_WIDTH - 250, 110):Center():addy(-18)
		self:diffuse(COLOR.MainBackground):diffusealpha(0.9)
	end
}

t[#t + 1] = Def.ActorFrame {
	Name = "TextEntryControls",
	InitCommand = function(self)
		self:Center()
	end,
	Def.Quad {
		Name = "UnhideButton",
		InitCommand = function(self)
			self:zoomto(100, 40):x(-SCREEN_WIDTH / 2 + 65):y(55)
			self:diffuse(COLOR.MainHighlight):diffusealpha(0.5)
			self:visible(false)
		end,
		OnCommand = function(self)
			self:visible(SCREENMAN:GetTopScreen():IsInputHidden())
		end,
		MouseClickCommand = function(self)
			SCREENMAN:GetTopScreen():ToggleInputHidden()
		end
	},
	LoadFont("Common Normal") .. {
		Name = "Unhide",
		InitCommand = function(self)
			self:xy(-SCREEN_WIDTH / 2 + 65, 55):zoom(0.6):settext(THEME:GetString("ScreenTextEntry", "Unhide"))
			self:visible(false)
		end,
		OnCommand = function(self)
			self:visible(SCREENMAN:GetTopScreen():IsInputHidden())
		end
	}
}

return t
