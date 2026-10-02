local function updateSongInfo(self)
	local song = GAMESTATE:GetCurrentSong()
	local title = self:GetChild("Title")
	local artist = self:GetChild("Artist")
	if not song then
		title:settext("")
		artist:settext("")
		return
	end
	title:settext(song:GetDisplayMainTitle() or "")
	artist:settext(song:GetDisplayArtist() or "")
end

return Def.ActorFrame {
	Name = "SongInfo",
	InitCommand = function(self)
		self:xy(24, 24)
	end,
	BeginCommand = function(self)
		self:playcommand("Update")
	end,
	UpdateCommand = updateSongInfo,
	CurrentSongChangedMessageCommand = function(self)
		self:playcommand("Update")
	end,
	LoadFont("DFPGothic 64px") .. {
		Name = "Title",
		InitCommand = function(self)
			self:halign(0):valign(0):zoom(0.55):maxwidth((SCREEN_WIDTH * 0.42) / 0.55)
				:diffuse(color("#FFFFFF"))
		end,
	},
	LoadFont("DFPGothic 64px") .. {
		Name = "Artist",
		InitCommand = function(self)
			self:y(32):halign(0):valign(0):zoom(0.38):maxwidth((SCREEN_WIDTH * 0.42) / 0.38)
				:diffuse(color("#BBBBBB"))
		end,
	},
}
