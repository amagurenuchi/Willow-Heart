function PlayBGMOption()
    local t = {
        Name = "PlayBGM",
        LayoutType = "ShowAllInRow",
        SelectType = "SelectOne",
        OneChoiceForAllPlayers = true,
        ExportOnChange = false,
        ExportOnCancel = true,
        Choices = {THEME:GetString("OptionNames", "Off"), THEME:GetString("OptionNames", "On")},
        LoadSelections = function(self, list, pn)
            if themeConfig:get_data().global.PlayBGM then
                list[2] = true
            else
                list[1] = true
            end
        end,
        SaveSelections = function(self, list, pn)
            themeConfig:get_data().global.PlayBGM = not list[1]
            themeConfig:set_dirty()
            themeConfig:save()
        end,
    }
    setmetatable(t, t)
    return t
end

function JudgementsOption()
    local choices = {"Off", "Classic", "Minimal"}
    local t = {
        Name = "Judgements",
        LayoutType = "ShowAllInRow",
        SelectType = "SelectOne",
        OneChoiceForAllPlayers = true,
        ExportOnChange = false,
        ExportOnCancel = true,
        Choices = choices,
        LoadSelections = function(self, list, pn)
            local selected = judgementDisplayMode()
            for i, choice in ipairs(choices) do list[i] = choice == selected end
        end,
        SaveSelections = function(self, list, pn)
            for i, choice in ipairs(choices) do
                if list[i] then
                    themeConfig:get_data().global.Judgements = choice
                    themeConfig:set_dirty()
                    themeConfig:save()
                    return
                end
            end
        end,
    }
    setmetatable(t, t)
    return t
end

-- Register persistent online-session values with the fallback ThemePrefs
-- implementation before any screen attempts to read or write them.
function SkipStageInformationOption()
    local t = {Name="SkipStageInformation", LayoutType="ShowAllInRow", SelectType="SelectOne", OneChoiceForAllPlayers=true,
        ExportOnChange=false, ExportOnCancel=true, Choices={"Off", "On"}}
    t.LoadSelections = function(self, list, pn)
        local enabled = themeConfig:get_data().global.SkipStageInformation == true
        list[1], list[2] = not enabled, enabled
    end
    t.SaveSelections = function(self, list, pn)
        themeConfig:get_data().global.SkipStageInformation = list[2] == true
        themeConfig:set_dirty(); themeConfig:save()
    end
    setmetatable(t, t)
    return t
end

function DirectNumberInputOption()
    local t = {Name="DirectNumberInput", LayoutType="ShowAllInRow", SelectType="SelectOne", OneChoiceForAllPlayers=true,
        ExportOnChange=false, ExportOnCancel=true, Choices={"Off", "On"}}
    t.LoadSelections = function(self, list, pn)
        local enabled = themeConfig:get_data().global.DirectNumberInput == true
        list[1], list[2] = not enabled, enabled
    end
    t.SaveSelections = function(self, list, pn)
        themeConfig:get_data().global.DirectNumberInput = list[2] == true
        themeConfig:set_dirty(); themeConfig:save()
    end
    setmetatable(t, t)
    return t
end

ThemePrefs.Init({
    Willow_OnlineUsername = {Default = ""},
    Willow_OnlinePasswordToken = {Default = ""},
}, true)

-- Player Options Theme page helpers are kept here because this file is loaded
-- by the theme's startup script list before option metrics are evaluated.
function PlayerThemeOptions()
    return {Name="PlayerThemeOptions", LayoutType="ShowAllInRow", SelectType="SelectOne", OneChoiceForAllPlayers=true, ExportOnChange=false, Choices={"Theme Options"}, LoadSelections=function(self,list,pn) list[1]=true end, SaveSelections=function(self,list,pn) local s=SCREENMAN:GetTopScreen(); s:SetNextScreenName("ScreenPlayerOptionsTheme"); s:StartTransitioningScreen("SM_GoToNextScreen") end}
end
function boolRow(name,title,field)
    return {Name=name,Title=title,LayoutType="ShowAllInRow",SelectType="SelectOne",OneChoiceForAllPlayers=true,ExportOnChange=true,Choices={"Off","On"},LoadSelections=function(self,list,pn) local ok,d=pcall(function() return playerConfig:get_data() end); d=ok and d or {}; list[d[field] and 2 or 1]=true end,SaveSelections=function(self,list,pn) local ok,d=pcall(function() return playerConfig:get_data() end); if ok and d then d[field]=list[2]==true; pcall(function() playerConfig:set_dirty(); playerConfig:save() end) end end}
end
function PlayerOptionArtistTitle() return boolRow("ArtistTitle", "Artist and Title Name", "ArtistTitle") end
function PlayerOptionPlayerInfo() return boolRow("PlayerInfo", "Player Info", "PlayerInfo") end
function PlayerOptionJudgeCounter() return boolRow("JudgeCounter", "Judge Counter", "JudgeCounter") end
function PlayerOptionScoreDisplay() return boolRow("ScoreDisplay", "Score display", "DisplayPercent") end
function PlayerOptionProgressCircle() return boolRow("ProgressCircle", "Progress circle", "FullProgressBar") end
function CustomizeGameplay() return boolRow("CustomizeGameplay", "Customize Gameplay", "CustomizeGameplay") end
function CBHighlight() return boolRow("CBHighlight", "Combo Break Highlight", "CBHighlight") end
function JudgmentText() return boolRow("JudgmentText", "Judgment Text", "JudgmentText") end
function ComboText() return boolRow("ComboText", "Combo Text", "ComboText") end
function DisplayPercent() return boolRow("DisplayPercent", "Score display", "DisplayPercent") end
function DisplayMean() return boolRow("DisplayMean", "Mean display", "DisplayMean") end
function TargetTracker() return boolRow("TargetTracker", "Target Tracker", "TargetTracker") end
function TargetGoal() return boolRow("TargetGoal", "Target Goal", "TargetGoal") end
function TargetTrackerMode() return boolRow("TargetTrackerMode", "Target Tracker Mode", "TargetTrackerMode") end
function JudgeCounter() return boolRow("JudgeCounter", "Judge Counter", "JudgeCounter") end
function PlayerInfo() return boolRow("PlayerInfo", "Player Info", "PlayerInfo") end
function ProgressBar() return boolRow("ProgressBar", "Progress circle", "FullProgressBar") end
function FullProgressBar() return boolRow("FullProgressBar", "Full Progress Bar", "FullProgressBar") end
function MiniProgressBar() return boolRow("MiniProgressBar", "Mini Progress Bar", "MiniProgressBar") end
function ErrorBar() return ErrorBarOption() end
function ReceptorSize()
    local choices={}; for i=1,250 do choices[i]=tostring(i).."%" end
    local t={Name="ReceptorSize",LayoutType="ShowAllInRow",SelectType="SelectOne",OneChoiceForAllPlayers=false,ExportOnChange=false,ExportOnCancel=true,Choices=choices}
    t.LoadSelections=function(self,list,pn) local d=playerConfig:get_data(pn_to_profile_slot(pn)); list[math.max(1,math.min(250,tonumber(d.ReceptorSize) or 100))]=true end
    t.SaveSelections=function(self,list,pn) for i=1,#list do if list[i] then local s=pn_to_profile_slot(pn); playerConfig:get_data(s).ReceptorSize=i; playerConfig:set_dirty(s); playerConfig:save(s); break end end end
    return t
end
function LeaderBoard() return boolRow("LeaderBoard", "Leaderboard", "leaderboardEnabled") end
function NPSDisplay() return boolRow("NPSDisplay", "NPS Display", "NPSDisplay") end
function EmulateRidiculous() return boolRow("EmulateRidiculous", "Emulate Ridiculous", "EmulateRidiculous") end
function EmulateScore() return boolRow("EmulateScore", "Emulate Score", "EmulateScore") end
function EmulateScoreJudge() return boolRow("EmulateScoreJudge", "Emulated Judge", "EmulateScore") end
function ErrorBarOption()
    local t={Name="ErrorBar",LayoutType="ShowAllInRow",SelectType="SelectOne",OneChoiceForAllPlayers=true,ExportOnChange=true,Choices={"Off","On","EWMA","Both"}}
    t.LoadSelections=function(self,list,pn) local ok,d=pcall(function() return playerConfig:get_data() end); d=ok and d or {}; list[(tonumber(d.ErrorBar) or 1)+1]=true end
    t.SaveSelections=function(self,list,pn) local ok,d=pcall(function() return playerConfig:get_data() end); if ok and d then for i=1,4 do if list[i] then d.ErrorBar=i-1; pcall(function() playerConfig:set_dirty(); playerConfig:save() end); break end end end end
    return t
end
