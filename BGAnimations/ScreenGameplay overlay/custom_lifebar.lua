local player = PLAYER_1
local width = 360
local height = 12
local x = SCREEN_CENTER_X
local y = SCREEN_BOTTOM - 24

local function getLife()
	local screen = SCREENMAN:GetTopScreen()
	if screen and screen.GetLifeMeter then
		local meter = screen:GetLifeMeter(player)
		if meter and meter.GetLife then return math.max(0, math.min(1, meter:GetLife() or 0)) end
	end
	local stage = STATSMAN:GetCurStageStats()
	local stats = stage and stage:GetPlayerStageStats(player)
	if stats and stats.GetCurrentLife then return math.max(0, math.min(1, stats:GetCurrentLife() or 0)) end
	return 0
end

local function lifeColor(life)
	if life <= 0.3 then return color("#FF4444") end
	if life <= 0.5 then return color("#FFAA44") end
	return color("#77CCFF")
end

local function hideFallback(self)
	local screen = SCREENMAN:GetTopScreen()
	local meter = screen and screen.GetLifeMeter and screen:GetLifeMeter(player)
	if meter then meter:visible(false):diffusealpha(0) end
end

return Def.ActorFrame {
	Name = "CustomLifeBar",
	BeginCommand = function(self)
		hideFallback(self)
		self:SetUpdateFunction(function(actor)
			hideFallback(actor)
			actor:GetChild("Fill"):playcommand("Update")
		end)
	end,
	OnCommand = hideFallback,
	CurrentSongChangedMessageCommand = hideFallback,
	Def.Quad {
		InitCommand = function(self)
			self:xy(x, y):halign(0.5):valign(0.5):zoomto(width, height):diffuse(color("#222222")):diffusealpha(0.9)
		end,
	},
	Def.Quad {
		Name = "Fill",
		InitCommand = function(self)
			self:xy(x - width / 2, y):halign(0):valign(0.5):zoomto(0, height):diffusealpha(1)
		end,
		UpdateCommand = function(self)
			local life = getLife()
			self:stoptweening():smooth(0.08):zoomx(width * life):diffuse(lifeColor(life))
		end,
	},
}
