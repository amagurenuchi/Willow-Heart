local function RouteToStageInformation()
	local screen = SCREENMAN:GetTopScreen()
	if screen then
		screen:SetNextScreenName(themeConfig:get_data().global.SkipStageInformation and "ScreenGameplay" or "ScreenStageInformation")
	end
end

return Def.ActorFrame{
	LoadActor(THEME:GetPathB("ScreenWithMenuElements", "overlay")),
	OffCommand = RouteToStageInformation,
	MenuStartCommand = RouteToStageInformation,
	MenuBackCommand = RouteToStageInformation,
	StartCommand = RouteToStageInformation,
	BackCommand = RouteToStageInformation,
}
