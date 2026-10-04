local pn = PLAYER_1
return Def.ActorFrame{
    OnCommand=function()
        local profile = playerConfig:get_data(pn_to_profile_slot(pn))
        local size = tonumber(profile.ReceptorSize) or 100
        GAMESTATE:GetPlayerState(pn):GetPlayerOptions("ModsLevel_Current"):Mini(2 - size / 50)
    end
}
