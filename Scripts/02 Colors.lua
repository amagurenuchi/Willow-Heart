COLOR = {
	MainBackground = color("#FFFFFF"),		-- White
	MainHighlight = color("#FFB4B4"),		-- Pink
	MainBorder = color("#4C4C4C"),			-- Black 70%
	UICaution = "", 						-- Yellow
	UIWarning = "", 						-- Red
	UINew = "", 							-- Blue
	UIAction = "", 							-- Green
	TextMain = color("#4C4C4C"),			-- Black 70%
	TextSub1 = color("#666666"),			-- Black 60%
	TextSub2 = color("#808080"),			-- Black 50%/Grey
	TextMainLight = color("#FFFFFF"),		-- White
	TextSub1Light = color("#b2b2b2"),		-- Black 30%
	TextSub2Light = color("#999999"),		-- Black 40%

	SongLong = HSV(36,0.5,0.75),			-- Orange
	SongMarathon = HSV(342,0.5,0.75),		-- Red
	SongUltraMarathon = HSV(288,0.5,0.75),	-- Purple

	ClearTypeColors = {
		ClearType_MFC = "#66CCFF", ClearType_WF = "#DDDDDD", ClearType_SDP = "#CC8800",
		ClearType_PFC = "#EEAA00", ClearType_BF = "#999999", ClearType_SDG = "#448844",
		ClearType_FC = "#66CC66", ClearType_MF = "#CC6666", ClearType_SDCB = "#33CCFF",
		ClearType_Clear = "#33AAFF",
		ClearType_Failed = "#E61E25",
		ClearType_Invalid = "#E61E25", ClearType_Noplay = "#666666", ClearType_None = "#666666",
	},

	JudgementColors = {
		TapNoteScore_W1 = "#d0ecff",
		TapNoteScore_W2 = "#DDBB22",
		TapNoteScore_W3 = "#66CC66",
		TapNoteScore_W4 = "#445dcc",
		TapNoteScore_W5 = "#c438a5",
		TapNoteScore_Miss = "#ff0000",
		HoldNoteScore_Held = "#fffb1d",
		HoldNoteScore_LetGo = "#ff0000",
		Ridiculous = "#FFAAFF", -- unused for now, unless...
	},

	DifficultyColors = {
		Beginner = "#66CCFF", Easy = "#66DD88", Medium = "#FFDD66",
		Hard = "#FF9966", Challenge = "#FF6699", Edit = "#CC99FF",
	},
}

function GetClearTypeColor(clearType)
	return color(COLOR.ClearTypeColors[tostring(clearType)] or "#666666")
end

function GetJudgementColor(judgement)
	return color(COLOR.JudgementColors[tostring(judgement)] or "#4C4C4C")
end

function GetDifficultyColor(diff)
	local key = diff and ToEnumShortString(diff) or ""
	return color(COLOR.DifficultyColors[key] or "#AAB3C4")
end


function GetRatingColor(rating)
	return HSV(((198 - math.min(rating,40)*(324/40))%360), 0.5, 0.75)
end

function GetSongMSDColor(song)
	if not song or not song.GetAllSteps then return color("#4C4C4C") end
	local rate = 1
	local options = GAMESTATE:GetSongOptionsObject('ModsLevel_Current')
	if options and options.MusicRate then rate = options:MusicRate() end
	local total, count = 0, 0
	for _, steps in ipairs(song:GetAllSteps() or {}) do
		if steps and steps.GetMSD then
			local msd = steps:GetMSD(rate, 1)
			if msd and msd == msd and msd >= 0 then
				total = total + msd
				count = count + 1
			end
		end
	end
	return count > 0 and GetRatingColor(total / count) or color("#4C4C4C")
end

function ApplyRawMSDColor(actor, song)
	if not actor then return end
	local c = GetSongMSDColor(song)
	actor:diffuse(c):diffusetopedge(c):diffusebottomedge(c)
		:diffuseleftedge(c):diffuserightedge(c)
		:diffusealpha(1):strokecolor(c):glow(color("#00000000"))
		:shadowlength(0):blend("BlendMode_Normal")
end

function GetSongLengthColor(t)
	if t < PREFSMAN:GetPreference("LongVerSongSeconds") then
		return COLOR.TextMain
	elseif t < PREFSMAN:GetPreference("MarathonVerSongSeconds") then
		return COLOR.SongLong
	elseif t < PREFSMAN:GetPreference("MarathonVerSongSeconds")*2 then
		return COLOR.SongMarathon
	else
		return COLOR.SongUltraMarathon
	end
end
