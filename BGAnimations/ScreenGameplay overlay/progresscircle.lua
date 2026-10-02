local centerX = SCREEN_WIDTH - 50
local centerY = 50
local diameter = 54
local radius = diameter / 2

local function setPieProgress(self, progress)
	local vertices = {}
	local segments = math.max(0, math.ceil(progress * 72))
	if segments > 0 then
		local startAngle = -math.pi / 2
		local step = (math.pi * 2 * progress) / segments
		for i = 0, segments - 1 do
			local a1 = startAngle + step * i
			local a2 = startAngle + step * (i + 1)
			vertices[#vertices + 1] = {{0, 0, 0}, Color.White}
			vertices[#vertices + 1] = {{math.cos(a1) * radius, math.sin(a1) * radius, 0}, Color.White}
			vertices[#vertices + 1] = {{math.cos(a2) * radius, math.sin(a2) * radius, 0}, Color.White}
		end
	end
	self:SetVertices(vertices)
	self:SetDrawState {Mode = "DrawMode_Triangles", First = 1, Num = #vertices}
end

local function songProgress()
	local song = GAMESTATE:GetCurrentSong()
	local steps = GAMESTATE:GetCurrentSteps()
	local length = 0
	if steps and steps.GetLastSecond then length = steps:GetLastSecond() or 0 end
	if length <= 0 and song and song.MusicLengthSeconds then length = song:MusicLengthSeconds() or 0 end
	local position = GAMESTATE:GetSongPosition()
	local current = position and position.GetMusicSeconds and position:GetMusicSeconds() or 0
	if length <= 0 then return 0 end
	return math.max(0, math.min(1, current / length))
end

return Def.ActorFrame {
	Name = "ProgressCircle",
	InitCommand = function(self)
		self:xy(centerX, centerY)
	end,
	BeginCommand = function(self)
		self:SetUpdateFunction(function(actor)
			actor:playcommand("Update")
		end)
	end,
	UpdateCommand = function(self)
		local progress = songProgress()
		setPieProgress(self:GetChild("Circle"), progress)
		self:GetChild("Percent"):settextf("%d%%", math.floor(progress * 100 + 0.5))
	end,
	LoadActor(THEME:GetPathG("", "_thick circle (doubleres)")) .. {
		Name = "CircleBackground",
		InitCommand = function(self)
			self:zoomto(diameter, diameter):diffuse(color("#FFFFFF")):diffusealpha(0.18)
		end,
	},
	Def.ActorMultiVertex {
		Name = "Circle",
		InitCommand = function(self)
			self:diffuse(color("#FFFFFF"))
			setPieProgress(self, 0)
		end,
	},
	LoadFont("hatsukoifriendsmini 24px") .. {
		Name = "Percent",
		InitCommand = function(self)
			self:halign(0.5):valign(0.5):zoom(0.30):diffuse(color("#FFFFFF")):settext("0%")
		end,
	},
}
