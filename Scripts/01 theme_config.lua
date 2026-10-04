local defaultConfig = {
    global = {
        PlayBGM = true,
        Judgements = "Minimal",
        SkipStageInformation = false,
        DirectNumberInput = false,
    },
}

themeConfig = create_setting("themeConfig", "themeConfig.lua", defaultConfig, -1)
themeConfig:load()

function playBGM()
    return themeConfig:get_data().global.PlayBGM
end

function judgementDisplayMode()
    return themeConfig:get_data().global.Judgements or "Minimal"
end
