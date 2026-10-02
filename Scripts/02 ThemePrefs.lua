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
ThemePrefs.Init({
    Willow_OnlineUsername = {Default = ""},
    Willow_OnlinePasswordToken = {Default = ""},
}, true)
