-- Text-entry helpers ported from Til Death.
function easyInputStringWithParams(question, maxLength, isPassword, funcOK, params)
	SCREENMAN:AddNewScreenToTop("ScreenTextEntry")
	local settings = {
		Question = question,
		MaxInputLength = maxLength,
		Password = isPassword,
		OnOK = function(answer)
			funcOK(answer, params)
		end
	}
	SCREENMAN:GetTopScreen():Load(settings)
end

function easyInputStringWithFunction(question, maxLength, isPassword, func)
	easyInputStringWithParams(
		question,
		maxLength,
		isPassword,
		function(answer)
			func(answer)
		end,
		{}
	)
end

function easyInputString(question, maxLength, isPassword, tablewithvalue)
	easyInputStringWithParams(
		question,
		maxLength,
		isPassword,
		function(answer)
			tablewithvalue.inputString = answer
		end,
		{}
	)
end

function easyInputStringOKCancel(question, maxLength, isPassword, funcOK, funcCancel)
	SCREENMAN:AddNewScreenToTop("ScreenTextEntry")
	local settings = {
		Question = question,
		MaxInputLength = maxLength,
		Password = isPassword,
		OnOK = function(answer)
			funcOK(answer)
		end,
		OnCancel = function()
			funcCancel()
		end,
	}
	SCREENMAN:GetTopScreen():Load(settings)
end

-- Replay data can be present on a score while its per-note vectors are still
-- lazy. Load those vectors before starting replay playback so the engine can
-- apply the saved hit offsets.
function WillowPlayReplay(score, screen)
	if not score then return false end

	local replay = score.GetReplay and score:GetReplay() or nil
	if replay and replay.LoadAllData then
		local loaded = pcall(function() replay:LoadAllData() end)
		if not loaded then return false end
	end

	screen = screen or SCREENMAN:GetTopScreen()
	if not screen or not screen.PlayReplay then return false end
	return pcall(function() screen:PlayReplay(score) end)
end
