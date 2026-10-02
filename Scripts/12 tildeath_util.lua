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
		function(answer, params)
			func(answer)
		end,
		{}
	)
end

--Tables are passed by reference right? So the value is tablewithvalue to pass it by ref
function easyInputString(question, maxLength, isPassword, tablewithvalue)
	easyInputStringWithParams(
		question,
		maxLength,
		isPassword,
		function(answer, params)
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

-- Cosmetic score/judgment emulation ported from Holographic Void.
-- The profile values are intentionally local to Til Death's playerConfig.
function tilDeathEmulationEnabled(name)
	local data = playerConfig and playerConfig:get_data(pn_to_profile_slot(PLAYER_1)) or {}
	local value = data[name]
	return value == true or value == "true" or value == 1 or value == "1"
end

function tilDeathMarvelousWindow(judgeScale)
	-- Etterna's J4 Marvelous window is 22.5 ms. Ridiculous is W1 / 2,
	-- scaled by the active timing-window scale rather than a fixed 11.25 ms.
	return (22.5 * (tonumber(judgeScale) or 1)) / 2
end

function tilDeathRidiculousCountFromOffsets(offsets, judgeScale)
	if type(offsets) ~= "table" then return 0 end
	local count = 0
	for _, offset in ipairs(offsets) do
		if tonumber(offset) and math.abs(tonumber(offset)) <= tilDeathMarvelousWindow(judgeScale) then
			count = count + 1
		end
	end
	return count
end

function tilDeathRidiculous(offset, judgeScale)
	return tilDeathEmulationEnabled("EmulateRidiculous") and offset ~= nil and
		math.abs(tonumber(offset) or math.huge) <= tilDeathMarvelousWindow(judgeScale)
end

function tilDeathScoreJudge()
	local data = playerConfig:get_data(pn_to_profile_slot(PLAYER_1))
	return data.EmulateScoreJudge or "J4"
end

function tilDeathScorePoint(offsetMs, tapScore)
	local judge = tonumber(tilDeathScoreJudge():match("J(%d)")) or 4
	local scale = (ms and ms.JudgeScalers and ms.JudgeScalers[judge]) or 1
	if offsetMs ~= nil then return wife3(math.abs(offsetMs), scale, "Wife3") end
	if tapScore == "TapNoteScore_Miss" then return -5.5 end
	if tapScore == "TapNoteScore_HitMine" then return -7 end
	return 2
end

function tilDeathRidiculousCount(score)
	if not tilDeathEmulationEnabled("EmulateRidiculous") or not score or not score.HasReplayData then return nil end
	local hasReplay = false
	local okHasReplay = pcall(function() hasReplay = score:HasReplayData() end)
	if not okHasReplay or not hasReplay then return nil end
	local replay = score:GetReplay()
	if not replay then return nil end
	local ok = pcall(function() replay:LoadAllData() end)
	if not ok then return nil end
	local okOffsets, offsets = pcall(function() return replay:GetOffsetVector() end)
	if not okOffsets or type(offsets) ~= "table" then return nil end
	local scale = score.GetJudgeScale and score:GetJudgeScale() or 1
	return tilDeathRidiculousCountFromOffsets(offsets, scale)
end
