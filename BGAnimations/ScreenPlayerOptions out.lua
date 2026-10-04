
return Def.ActorFrame{
	OnCommand = function(self)
		local screen = SCREENMAN:GetTopScreen()
		if screen then
			screen:SetNextScreenName(themeConfig:get_data().global.SkipStageInformation and "ScreenGameplay" or "ScreenStageInformation")
		end
	end,
}
