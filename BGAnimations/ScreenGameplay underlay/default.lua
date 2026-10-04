local pn = PLAYER_1
local t = Def.ActorFrame{
	OnCommand = function()
		local profile = playerConfig:get_data(pn_to_profile_slot(pn))
		local size = tonumber(profile.ReceptorSize) or 100
		GAMESTATE:GetPlayerState(pn):GetPlayerOptions("ModsLevel_Current"):Mini(2 - size / 50)
	end,
}

-- Dark background for gameplay
t[#t+1] = Def.Quad{
	InitCommand = function(self)
		self:FullScreen()
		self:diffuse(color("#000000"))
	end
}

t[#t+1] = LoadActor("../_songbg.lua") .. {
	InitCommand = function(self)
		self:SetUpdateFunction(nil)
	end,
}

return t
