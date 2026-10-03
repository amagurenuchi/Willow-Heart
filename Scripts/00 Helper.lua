
PLAYER = PLAYER_1

DIFFICULTY_LABELS = {
	Beginner = "BEGINNER",
	Easy = "EASY",
	Medium = "NORMAL",
	Hard = "HARD",
	Challenge = "INSANE",
	Edit = "EDIT",
}

function GetDifficultyName(diff)
	if not diff then return "" end
	local str = ToEnumShortString(diff)
	return DIFFICULTY_LABELS[str] or string.upper(str)
end

function GetDifficultyLabel(diff)
	return GetDifficultyName(diff)
end

-- Keep the shared color API available on screens that load before Colors.lua.
function GetJudgementColor(judgement)
	local colors = COLOR and COLOR.JudgementColors
	return color(colors and colors[tostring(judgement)] or "#4C4C4C")
end

function Actor.PlayCommandsOnChildren(self, cmd, params)
    return self:RunCommandsOnChildren(function(self) self:playcommand(cmd, params) end)
end

function Actor.QueueCommandsOnChildren(self, cmd)
    return self:RunCommandsOnChildren(function(self) self:queuecommand(cmd) end)
end

function GetCommonBPM(bpms, lastBeat)
	local BPMtable = {}
	local curBPM = math.round(bpms[1][2])
	local curBeat = bpms[1][1]
	for _,v in ipairs(bpms) do
		if BPMtable[tostring(curBPM)] == nil then
			BPMtable[tostring(curBPM)] = (v[1] - curBeat)/curBPM
		else
			BPMtable[tostring(curBPM)] = BPMtable[tostring(curBPM)] + (v[1] - curBeat)/curBPM
		end
		curBPM = math.round(v[2])
		curBeat = v[1]
	end

	if BPMtable[tostring(curBPM)] == nil then
		BPMtable[tostring(curBPM)] = (lastBeat - curBeat)/curBPM
	else
		BPMtable[tostring(curBPM)] = BPMtable[tostring(curBPM)] + (lastBeat - curBeat)/curBPM
	end

	local maxBPM = 0
	local maxDur = 0
	for k,v in pairs(BPMtable) do
		if v > maxDur then
			maxDur = v
			maxBPM = tonumber(k)
		end
	end
	return maxBPM * GAMESTATE:GetSongOptionsObject('ModsLevel_Current'):MusicRate()
end
