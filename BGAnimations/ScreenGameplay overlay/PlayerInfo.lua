-- Player and stage information, following Til Death's gameplay profile layout.
local profile = GetPlayerOrMachineProfile(PLAYER_1)
local playerFrameX = 0
local playerFrameY = SCREEN_HEIGHT - 80
local bgalpha = PREFSMAN:GetPreference("BGBrightness")

local function updateProfile(self)
	profile = GetPlayerOrMachineProfile(PLAYER_1)
	self:GetChild("Avatar"):Load(getAvatarPath(PLAYER_1))
	self:GetChild("Name"):settext(profile and profile:GetDisplayName() or "PLAYER 1")
	self:GetChild("MSD"):playcommand("Set")
	self:GetChild("Difficulty"):playcommand("Set")
	self:GetChild("Mods"):settext(getModifierTranslations(GAMESTATE:GetPlayerState():GetPlayerOptionsString("ModsLevel_Current")))
	self:GetChild("Wife"):playcommand("Set")
end

local function currentWife()
	local stage = STATSMAN:GetCurStageStats()
	local stats = stage and stage:GetPlayerStageStats(PLAYER_1)
	return stats and stats.GetWifeScore and (tonumber(stats:GetWifeScore()) or 0) * 100 or nil
end

return Def.ActorFrame{
	Def.Quad{
		InitCommand=function(self)
			self:xy(0, SCREEN_HEIGHT):halign(0):valign(1):zoomto(150, 80)
			self:diffuse(0, 0, 0, bgalpha * 0.4)
		end,
	},
	Def.Quad{
		InitCommand=function(self)
			self:xy(150, SCREEN_HEIGHT):halign(0):valign(1):zoomto((SCREEN_WIDTH * 0.44) - 150, 18)
			self:diffuse(0, 0, 0, bgalpha * 0.4):faderight(0.7)
		end,
	},
	Def.Sprite{
		Name="Avatar",
		InitCommand=function(self) self:halign(0):valign(0):xy(playerFrameX, playerFrameY):zoomto(80, 80) end,
		BeginCommand=function(self) self:Load(getAvatarPath(PLAYER_1)):zoomto(80, 80) end,
	},
	LoadFont("Common Large")..{
		Name="Name",
		InitCommand=function(self) self:xy(playerFrameX + 90, playerFrameY + 8):halign(0):zoom(0.55):maxwidth(360):diffuse(getMainColor("positive")) end,
	},
	LoadFont("DFPGothic 64px")..{
		Name="MSD",
		InitCommand=function(self) self:xy(playerFrameX + 90, playerFrameY + 34):halign(0):zoom(0.7):maxwidth(100) end,
		SetCommand=function(self)
			local steps = GAMESTATE:GetCurrentSteps(PLAYER_1)
			if not steps then self:settext("") return end
			local msd = steps:GetMSD(getCurRateValue(), 1)
			self:settextf("%05.2f", msd):diffuse(byMSD(msd))
		end,
	},
	LoadFont("Common Large")..{
		Name="Difficulty",
		InitCommand=function(self) self:xy(playerFrameX + 195, playerFrameY + 35):halign(0):zoom(0.4):maxwidth(250) end,
		SetCommand=function(self)
			local steps = GAMESTATE:GetCurrentSteps(PLAYER_1)
			if not steps then self:settext("") return end
			self:settext(GetDifficultyName(steps:GetDifficulty())):diffuse(GetDifficultyColor(steps:GetDifficulty()))
		end,
	},
	LoadFont("Common Normal")..{
		Name="Mods",
		InitCommand=function(self) self:xy(playerFrameX + 90, playerFrameY + 65):halign(0):zoom(0.4):maxwidth(SCREEN_WIDTH * 0.35):diffuse(COLOR.TextSub1) end,
	},
	LoadFont("Common Normal")..{
		Name="Wife",
		InitCommand=function(self) self:xy(playerFrameX, playerFrameY - 14):halign(0):zoom(0.9):diffuse(COLOR.TextMain) end,
		SetCommand=function(self)
			local wife = currentWife()
			if wife then self:settextf("%.2f%%", wife) else self:settext("") end
		end,
	},
	InitCommand=function(self) self:queuecommand("Set") end,
	SetCommand=function(self) updateProfile(self) end,
	BeginCommand=function(self) self:queuecommand("Set") end,
	JudgmentMessageCommand=function(self, params)
		if params and params.Player == PLAYER_1 then self:queuecommand("Set") end
	end,
	CurrentRateChangedMessageCommand=function(self) self:queuecommand("Set") end,
	CurrentStepsChangedMessageCommand=function(self) self:queuecommand("Set") end,
}
