local wheel
local screen
local loginController
local loginEmail

local function saveOnlineLogin()
	if not DLMAN or not DLMAN.IsLoggedIn or not DLMAN:IsLoggedIn() then return end
	local username = DLMAN:GetUsername()
	local token = DLMAN:GetToken()
	if username and token and username ~= "" and token ~= "" then
		ThemePrefs.Set("Willow_OnlineUsername", username)
		ThemePrefs.Set("Willow_OnlinePasswordToken", token)
		ThemePrefs.Save()
	end
end

local function clearOnlineLogin()
	ThemePrefs.Set("Willow_OnlineUsername", "")
	ThemePrefs.Set("Willow_OnlinePasswordToken", "")
	ThemePrefs.Save()
end

local function beginLogin()
	easyInputStringOKCancel(THEME:GetString("ScreenSelectMusic", "Email") .. ":", 255, false,
		function(answer)
			loginEmail = answer:gsub("^%s*(.-)%s*$", "%1")
			if loginEmail == "" then return end
			-- Let the built-in prompt finish before opening the password prompt.
			if loginController then
				loginController:sleep(0.04):queuecommand("LoginStep2")
			end
		end,
		function() end)
end

local function profileClick()
	if DLMAN and DLMAN:IsLoggedIn() then
		DLMAN:Logout()
	else
		beginLogin()
	end
end

local function avatarClick()
	SCREENMAN:SetNewScreen("ScreenAssetSettings")
end

local function ChangeMusicRate(delta)
	local current = GAMESTATE:GetSongOptionsObject("ModsLevel_Current")
	if not current or not current.MusicRate then return end

	local rate = current:MusicRate()
	local newRate = math.max(0.05, math.min(3.0, rate + delta))
	for _, level in ipairs({"ModsLevel_Preferred", "ModsLevel_Song", "ModsLevel_Current"}) do
		local options = GAMESTATE:GetSongOptionsObject(level)
		if options and options.MusicRate then
			options:MusicRate(newRate)
		end
	end
	MESSAGEMAN:Broadcast("CurrentRateChanged", {oldRate = rate, rate = newRate})
end

local t = Def.ActorFrame{
	InitCommand = function(self)
		self:rotationz(0)
	end;
	OnCommand = function(self)
		screen = SCREENMAN:GetTopScreen()
		wheel = screen:GetMusicWheel()
		screen:AddInputCallback(function(event)
			local deviceButton = event.DeviceInput and event.DeviceInput.button
			if event.type == "InputEventType_FirstPress" and wheel and
				(deviceButton == "DeviceButton_mousewheel up" or deviceButton == "DeviceButton_mousewheel down") then
				local delta = deviceButton == "DeviceButton_mousewheel up" and -1 or 1
				wheel:MoveAndCheckType(delta)
				wheel:Move(0)
				return true
			end
			if event.type == "InputEventType_FirstPress" and deviceButton == "DeviceButton_space" and getTabIndex() ~= 3 then
				local song = GAMESTATE:GetCurrentSong()
				if song and GAMESTATE:GetCurrentSteps(PLAYER_1) then
					SCREENMAN:AddNewScreenToTop("ScreenChartPreview")
				end
				return false
			end
		if event.type == "InputEventType_FirstPress" or event.type == "InputEventType_Repeat" then
			if event.button == "EffectUp" then
				ChangeMusicRate(0.05)
			elseif event.button == "EffectDown" then
				ChangeMusicRate(-0.05)
			end
		end
	end)
	end;
}

t[#t+1] = Def.Actor{
	OnCommand = function(self)
		loginController = self
		self:sleep(0.5):queuecommand("RefreshWheel")
	end,
	LoginStep2Command = function(self)
		easyInputStringOKCancel("Password:", 255, true,
			function(password)
				if password ~= "" and loginEmail then
					DLMAN:Login(loginEmail, password)
				end
			end,
			function() end)
	end,
	LoginMessageCommand = function(self) saveOnlineLogin() end,
	LogOutMessageCommand = function(self) clearOnlineLogin() end,
	RefreshWheelCommand = function(self)
		if wheel then wheel:Move(0) end
	end,
}

local generalContent = Def.ActorFrame{
	Name = "GeneralContent",
	InitCommand = function(self) self:x(0) end,
	TabChangedMessageCommand = function(self, params)
		self:stoptweening()
		if params and params.to == 0 then
			self:visible(true):x(SCREEN_WIDTH + 500):decelerate(0.6):x(0):diffusealpha(1)
		else
			self:decelerate(0.6):x(SCREEN_WIDTH + 500):diffusealpha(0)
			self:sleep(0.04):queuecommand("Hide")
		end
	end,
	HideCommand = function(self) self:visible(false) end,
}

t[#t+1] = LoadActor("../_mouse.lua", "ScreenSelectMusic")

-- Player profile bar
local profile = PROFILEMAN:GetProfile(PLAYER_1)
local function ProfileValue(method, fallback)
	if profile and profile[method] then
		local ok, value = pcall(function() return profile[method](profile) end)
		if ok and value ~= nil then return value end
	end
	return fallback
end

t[#t+1] = Def.Quad{
	OnCommand = function(self)
		self:xy(SCREEN_WIDTH - 145, 60):zoomto(250, 50):diffuse(COLOR.MainHighlight)
	end,
}

t[#t+1] = LoadActor(THEME:GetPathG("", "Profilebar"), {
	AvatarPath = getAvatarPath(PLAYER_1),
	ProfileName = ProfileValue("GetDisplayName", ProfileValue("GetName", "PLAYER 1")),
	Rating = ProfileValue("GetPlayerRating", 0),
	Rank = ProfileValue("GetRank", 0),
	OnProfileClick = profileClick,
	OnAvatarClick = avatarClick,
})..{
	OnCommand = function(self)
		self:xy(SCREEN_WIDTH - 150, 55)
	end,
}


generalContent[#generalContent+1] = LoadActor(THEME:GetPathG("","Banner"))..{
	OnCommand = function(self)
		self:xy(SCREEN_WIDTH-260,200)
	end,
	CurrentSongChangedMessageCommand = function(self) 
		local song = GAMESTATE:GetCurrentSong()
		if song then
			self:playcommand("SongUpdate",{Song = song, Steps = GAMESTATE:GetCurrentSteps(PLAYER)})
		else
			self:playcommand("SongUpdate",{Song = nil, Group = wheel:GetSelectedSection()})
		end
	end,
	CurrentRateChangedMessageCommand = function(self, params)
		self:playcommand("RateUpdate",{Steps = GAMESTATE:GetCurrentSteps(PLAYER), rate = params and params.rate})
	end,
	CurrentStepsP1ChangedMessageCommand = function(self)
		self:playcommand("StepsUpdate",{Steps = GAMESTATE:GetCurrentSteps(PLAYER)})
	end,
}

generalContent[#generalContent+1] = LoadActor(THEME:GetPathG("","MSDDisplay"))..{
	OnCommand = function(self)
		self:xy(SCREEN_WIDTH-260,385)
	end,
	CurrentSongChangedMessageCommand = function(self) 
		local song = GAMESTATE:GetCurrentSong()
		if song then
			self:playcommand("SongUpdate",{Song = song, Steps = GAMESTATE:GetCurrentSteps(PLAYER)})
		else
			self:playcommand("SongUpdate",{Song = nil, Group = wheel:GetSelectedSection()})
		end
	end,
	CurrentRateChangedMessageCommand = function(self, params)
		self:playcommand("RateUpdate",{Steps = GAMESTATE:GetCurrentSteps(PLAYER), rate = params and params.rate})
	end,
	CurrentStepsP1ChangedMessageCommand = function(self)
		self:playcommand("StepsUpdate",{Steps = GAMESTATE:GetCurrentSteps(PLAYER)})
	end,
}

generalContent[#generalContent+1] = LoadActor(THEME:GetPathG("","BestScoreDisplay"))..{
	OnCommand = function(self) self:xy(SCREEN_WIDTH-260, 535) end,
	CurrentSongChangedMessageCommand = function(self)
		self:playcommand("SongUpdate", {Song=GAMESTATE:GetCurrentSong(), Steps=GAMESTATE:GetCurrentSteps(PLAYER)})
	end,
	CurrentStepsP1ChangedMessageCommand = function(self)
		self:playcommand("StepsUpdate", {Steps=GAMESTATE:GetCurrentSteps(PLAYER)})
	end,
	CurrentRateChangedMessageCommand = function(self, params)
		self:playcommand("RateUpdate", {Steps=GAMESTATE:GetCurrentSteps(PLAYER), rate=params and params.rate})
	end,
}

generalContent[#generalContent+1] = LoadActor(THEME:GetPathG("","StepsList"))..{
	OnCommand = function(self)
		self:xy(SCREEN_WIDTH-625, 285)
	end,
	CurrentSongChangedMessageCommand = function(self)
		self:playcommand("SongUpdate")
	end,
	CurrentStepsP1ChangedMessageCommand = function(self)
		self:playcommand("StepsUpdate", {Steps = GAMESTATE:GetCurrentSteps(PLAYER)})
	end,
	CurrentRateChangedMessageCommand = function(self)
		self:playcommand("RateUpdate")
	end,
}

t[#t+1] = generalContent

-- Song-select navigation.  These panels intentionally stay on this screen so
-- changing tabs does not interrupt preview music or reset the wheel position.
local tabs = {"General", "Scores", "Search", "Tags", "Filter", "Playlists", "Goals", "Profile"}
local activeTab = "General"
local panel
local tabIndex = 0
local pendingPanelTab = "General"
local scoreIndex = 1
local sessionTags = {}
local sessionGoals = {}

local function safeCall(object, method, fallback, ...)
	if not object or not object[method] then return fallback end
	local args = {...}
	local ok, value = pcall(function() return object[method](object, unpack(args)) end)
	return ok and value ~= nil and value or fallback
end

local function tabNumber(name)
	for i, tabName in ipairs(tabs) do
		if tabName == name then return i - 1 end
	end
	return 0
end

local function safeProfileValue(method, fallback)
	local p = PROFILEMAN:GetProfile(PLAYER_1)
	if p and p[method] then
		local ok, value = pcall(function() return p[method](p) end)
		if ok and value ~= nil then return value end
	end
	return fallback
end

local function currentSongText()
	local song = GAMESTATE:GetCurrentSong()
	if not song then return "No song selected", "Move the wheel to choose a song." end
	local title = song:GetDisplayMainTitle()
	local artist = song:GetDisplayArtist()
	return title or "Untitled", artist or "Unknown artist"
end

local function currentScores()
	local steps = GAMESTATE:GetCurrentSteps(PLAYER_1)
	local profile = PROFILEMAN:GetProfile(PLAYER_1)
	if not steps or not profile then return {} end
	local scores = safeCall(profile, "GetHighScoresByKey", {}, steps:GetChartKey())
	if #scores == 0 then
		local list = safeCall(profile, "GetHighScoreList", nil, steps)
		scores = list and safeCall(list, "GetHighScores", {}) or scores
	end
	return scores or {}
end

local function scoreLine(score)
	if not score then return "No scores saved for this chart" end
	local wife = safeCall(score, "GetWifeScore", 0) * 100
	local combo = safeCall(score, "GetMaxCombo", 0)
	local rate = safeCall(score, "GetMusicRate", 1)
	return string.format("%5.2f%%   Combo %s   Rate %.2fx", wife, tostring(combo), rate)
end

local function currentTagKey()
	local song = GAMESTATE:GetCurrentSong()
	local steps = GAMESTATE:GetCurrentSteps(PLAYER_1)
	return steps and safeCall(steps, "GetChartKey", "") or (song and safeCall(song, "GetSongDir", "") or "")
end

local function filterValue(method, fallback)
	return FILTERMAN and safeCall(FILTERMAN, method, fallback) or fallback
end

local function countKeys(values)
	local count = 0
	for _ in pairs(values or {}) do count = count + 1 end
	return count
end

local function tabCopy(name)
	local title, subtitle = currentSongText()
	local scores = currentScores()
	local score = scores[scoreIndex]
	local key = currentTagKey()
	local tags = sessionTags[key] or {}
	local playlist = SONGMAN and safeCall(SONGMAN, "GetActivePlaylist", nil)
	local playlistName = playlist and safeCall(playlist, "GetName", "Favorites") or "Favorites"
	local copy = {
		Scores = {"SCORES", "Local / Online", scoreLine(score), "Showing         " .. tostring(math.min(scoreIndex, #scores)) .. " / " .. tostring(#scores), "Max Combo       " .. tostring(score and safeCall(score, "GetMaxCombo", "--") or "--"), "Rate            " .. string.format("%.2fx", score and safeCall(score, "GetMusicRate", 1) or 1), "Date Achieved   " .. tostring(score and safeCall(score, "GetDateString", "--") or "--"), "Replay / Eval / Upload"},
		Search = {"SEARCH", "Search Active / Search Complete", "Start to lock search results", "Escape to cancel search", "Delete resets the search query", "artist= title= group= author=", "Separate multiple fields with ;", "Numbers require Ctrl"},
		Tags = {"TAGS", "Chart Tags", "Pack          " .. (wheel and wheel:GetSelectedSection() or "--"), "Current chart  " .. title, "Tags           " .. (#tags > 0 and table.concat(tags, ", ") or "None"), "Filter By       ANY", "Remove Tag      Click a tag", "Previous                         Next"},
		Filter = {"FILTERS", "Set values to narrow the wheel", string.format("Max Rate       %.1fx", filterValue("GetMaxFilterRate", 1)), string.format("Min Rate       %.1fx", filterValue("GetMinFilterRate", 0)), "Mode           " .. (filterValue("GetFilterMode", false) and "ALL" or "ANY"), "Highest Skill Only   " .. (filterValue("GetHighestSkillsetsOnly", false) and "On" or "Off"), "Highest Diff Only   " .. (filterValue("GetHighestDifficultyOnly", false) and "On" or "Off"), "Matches        Filtered wheel"},
		Playlists = {"PLAYLISTS", "Ctrl+A add chart   |   Ctrl+P new playlist", "Active          " .. playlistName, "Charts          " .. tostring(playlist and safeCall(playlist, "GetNumCharts", "--") or "--"), "Average Rating  --", "Delete          Del", "Play As Course", "SyncUp / SyncDown"},
		Goals = {"GOALS", "Priority  Rate  Song  Date  Diff  Best", "Assigned goals  " .. tostring(countKeys(sessionGoals)), "Completed goals", "Incomplete goals", "Assigned       " .. (sessionGoals[title] and title or "--"), "Achieved       --", "Filter: All Goals"},
		Profile = {"PROFILE INFO", tostring(safeProfileValue("GetDisplayName", "PLAYER 1")), "Online / Local / Recent / Percent", "Rating        " .. string.format("%.2f", safeProfileValue("GetPlayerRating", 0)), "Songs played  " .. tostring(safeProfileValue("GetTotalNumSongsPlayed", 0)), "Previous                         Next", "Save Profile    |   Asset Settings", "Validate All    |   Recalc Scores"},
	}
	return copy[name] or {"GENERAL", title, subtitle, "Select a tab to explore this song", "", ""}
end

local function panelAction(index)
	local song = GAMESTATE:GetCurrentSong()
	local steps = GAMESTATE:GetCurrentSteps(PLAYER_1)
	if activeTab == "Scores" then
		local scores = currentScores()
		if index == 1 then scoreIndex = scoreIndex % math.max(1, #scores) + 1; MESSAGEMAN:Broadcast("TabRefresh")
		elseif index == 2 and song and steps and DLMAN and DLMAN.IsLoggedIn and DLMAN:IsLoggedIn() then DLMAN:UploadScoresForChart(steps:GetChartKey())
		elseif index == 3 and scores[scoreIndex] and scores[scoreIndex].HasReplayData and scores[scoreIndex]:HasReplayData() then SCREENMAN:GetTopScreen():PlayReplay(scores[scoreIndex]) end
	elseif activeTab == "Search" then
		if index == 1 then easyInputStringOKCancel("Search:", 255, false, function(query) if wheel then wheel:SongSearch(query or "") end end, function() end)
		elseif index == 2 and wheel then wheel:SongSearch("") end
	elseif activeTab == "Tags" then
		local key = currentTagKey()
		if index == 1 then easyInputStringOKCancel("Add tag:", 64, false, function(tag) if tag and tag ~= "" then sessionTags[key] = sessionTags[key] or {}; table.insert(sessionTags[key], tag); MESSAGEMAN:Broadcast("TabRefresh") end end, function() end)
		elseif index == 2 then sessionTags[key] = nil; MESSAGEMAN:Broadcast("TabRefresh") end
	elseif activeTab == "Filter" and FILTERMAN then
		if index == 1 then FILTERMAN:ResetAllFilters()
		elseif index == 2 then FILTERMAN:ToggleFilterMode()
		elseif index == 3 and wheel then wheel:SongSearch("") end
		MESSAGEMAN:Broadcast("TabRefresh")
	elseif activeTab == "Playlists" then
		if index == 1 and SONGMAN and SONGMAN.GetActivePlaylist and SONGMAN:GetActivePlaylist() then SCREENMAN:GetTopScreen():StartPlaylistAsCourse(SONGMAN:GetActivePlaylist():GetName()) end
	elseif activeTab == "Goals" then
		if song and index == 1 then sessionGoals[song:GetDisplayMainTitle()] = true; MESSAGEMAN:Broadcast("TabRefresh") elseif index == 2 then sessionGoals = {}; MESSAGEMAN:Broadcast("TabRefresh") end
	elseif activeTab == "Profile" then
		if index == 1 then profileClick() elseif index == 2 then avatarClick() elseif index == 3 and DLMAN and DLMAN.IsLoggedIn and DLMAN:IsLoggedIn() then DLMAN:UploadAllScores() end
	end
end

local function updatePanel(self, name)
	local data = tabCopy(name)
	local actionNames = {
		Scores = {"Next score", "Upload chart", "Replay"},
		Search = {"Search", "Clear search", ""},
		Tags = {"Add tag", "Clear tags", ""},
		Filter = {"Reset filters", "Toggle mode", "Apply"},
		Playlists = {"Play course", "", ""},
		Goals = {"Assign chart", "Clear goals", ""},
		Profile = {"Login / logout", "Asset settings", "Upload all"},
	}
	self:GetChild("PanelTitle"):settext(data[1])
	self:GetChild("PanelSubtitle"):settext(data[2])
	for i = 1, 8 do self:GetChild("PanelLine" .. i):settext(data[i + 2] or "") end
	for i = 1, 3 do
		local action = self:GetChild("Action" .. i)
		local label = actionNames[name] and actionNames[name][i] or ""
		action:visible(label ~= "")
		action:GetChild("Text"):settext(label)
	end
end

local function selectTab(name)
	local nextIndex = tabNumber(name)
	local previousIndex = tabIndex
	tabIndex = nextIndex
	activeTab = name
	pendingPanelTab = name
	MESSAGEMAN:Broadcast("TabChanged", {from = previousIndex, to = nextIndex})
	if name == "Search" and wheel then
		easyInputStringOKCancel("Search:", 255, false, function(query)
			wheel:SongSearch(query or "")
		end, function() end)
	end
end


t[#t+1] = LoadActor("common")
t[#t+1] = Def.ActorFrame{Name="StepsDisplay", InitCommand=function(self) self.nested=false end}
t[#t+1] = LoadActor("manager")
t[#t+1] = LoadActor("Scores")
t[#t+1] = LoadActor("Search")
t[#t+1] = LoadActor("Tags")
t[#t+1] = LoadActor("Filter")
t[#t+1] = LoadActor("Playlists")
t[#t+1] = LoadActor("Goals")
t[#t+1] = LoadActor("Profile")

t[#t+1] = StandardDecorationFromFileOptional("Header","Header")

-- Keep the transition hint independent from the sliding select-screen content.
return t
