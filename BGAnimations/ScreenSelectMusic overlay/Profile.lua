local frameWidth = capWideScale(360, 400)
local frameX = SCREEN_WIDTH - frameWidth - 10
local frameY = 95
local frameHeight = SCREEN_HEIGHT - 135
local fontScale = 0.38
local scoresperpage = 25
local scoreYspacing = (frameHeight - 75) / 25
local distY = 15
local offsetX = -10
local offsetY = 20
local txtDist = 33
local rankingSkillset = 1
local rankingPage = 1
local numrankingpages = 10
local rankingWidth = frameWidth - capWideScale(10, 25)
local rankingX = 10
local rankingY = 32
local rankingTitleSpacing = (rankingWidth / (#ms.SkillSets))
local buttondiffuse = 0
local whee
local profile

local update = false
local showOnline = false
local recentactive = false
local percentactive = false
local topactive = false

local function BroadcastIfActive(msg)
	if update then
		MESSAGEMAN:Broadcast(msg)
	end
end

local translated_info = {
	Validated = THEME:GetString("TabProfile", "ScoreValidated"),
	Invalidated = THEME:GetString("TabProfile", "ScoreInvalidated"),
	Online = THEME:GetString("TabProfile", "Online"),
	Local = THEME:GetString("TabProfile", "Local"),
	Recent = THEME:GetString("TabProfile", "Recent"),
	Percent = THEME:GetString("TabProfile", "Percent"),
	NextPage = THEME:GetString("TabProfile", "NextPage"),
	PrevPage = THEME:GetString("TabProfile", "PreviousPage"),
	Save = THEME:GetString("TabProfile", "SaveProfile"),
	AssetSettings = THEME:GetString("TabProfile", "AssetSettingEntry"),
	Success = THEME:GetString("TabProfile", "SaveSuccess"),
	Failure = THEME:GetString("TabProfile", "SaveFail"),
	ValidateAll = THEME:GetString("TabProfile", "ValidateAllScores"),
	ForceRecalc = THEME:GetString("TabProfile", "ForceRecalcScores"),
	UploadAllScore = THEME:GetString("TabProfile", "UploadAllScore"),
}

local t = Def.ActorFrame {
	BeginCommand = function(self)
		self:queuecommand("Set"):visible(false)
	end,
	OffCommand = function(self)
		self:decelerate(0.6):xy(SCREEN_WIDTH + 500, 0):diffusealpha(0)
		self:sleep(0.04):queuecommand("Invis")
	end,
	InvisCommand= function(self)
		self:visible(false)
	end,
	OnCommand = function(self)
		self:xy(SCREEN_WIDTH + 500, 0):decelerate(0.6):xy(0, 0):diffusealpha(1)
	end,
	SetCommand = function(self)
		self:finishtweening()
		if getTabIndex() == 4 or SCREENMAN:GetTopScreen():GetName() == "ScreenNetRoom" and getTabIndex() == 1 then
			self:queuecommand("On")
			self:visible(true)
			update = true
		else
			self:queuecommand("Off")
			update = false
		end
	end,
	LogOutMessageCommand = function(self)
		showOnline = false
		BroadcastIfActive("UpdateRanking")
	end,
	LoginMessageCommand = function(self)
		BroadcastIfActive("UpdateRanking")
	end,
	LoginFailedMessageCommand = function(self)
		BroadcastIfActive("UpdateRanking")
	end,
	OnlineUpdateMessageCommand = function(self)
		BroadcastIfActive("UpdateRanking")
	end,
	TabChangedMessageCommand = function(self)
		self:queuecommand("Set")
	end
}

if GAMESTATE:IsPlayerEnabled() then
	profile = GetPlayerOrMachineProfile(PLAYER_1)
end

t[#t + 1] = Def.Quad {
	InitCommand = function(self)
		self:xy(frameX + 5, frameY + 5):zoomto(frameWidth, frameHeight):halign(0):valign(0):diffuse(COLOR.MainHighlight)
	end
}

t[#t + 1] = Def.Quad {
	InitCommand = function(self)
		self:xy(frameX, frameY):zoomto(frameWidth, frameHeight):halign(0):valign(0):diffuse(COLOR.MainBackground)
	end
}

t[#t + 1] = UIElements.Border(frameWidth, frameHeight, 1) .. {
	InitCommand = function(self)
		self:xy(frameX + frameWidth / 2, frameY + frameHeight / 2):diffuse(COLOR.MainBorder)
	end
}

local hoverAlpha = 0.6

local function byValidity(valid)
	if valid then
		return COLOR.TextMain
	end
	return color("#FF4444")
end

local function ButtonActive(self)
	return isOver(self) and update
end

local r = Def.ActorFrame {
	InitCommand = function(self)
		self:xy(frameX, frameY)
	end,
	OnCommand = function(self)
		whee = SCREENMAN:GetTopScreen():GetMusicWheel()
	end
}

local function rankingLabel(i)
	local ths
	local ck
	local thssteps
	local thssong
	local onlineScore

	local t = Def.ActorFrame {
		InitCommand = function(self)
			self:xy(10, 56 + (i - 1) * scoreYspacing)
			self:visible(false)
		end,
		UpdateRankingMessageCommand = function(self)
			if (rankingSkillset > 1 or topactive or percentactive) and update and not recentactive then
				if not showOnline then
					ths = SCOREMAN:GetTopSSRHighScoreForGame(i + (scoresperpage * (rankingPage - 1)), ms.SkillSets[rankingSkillset])
					if ths then
						self:visible(true)
						ck = ths:GetChartKey()
						thssong = SONGMAN:GetSongByChartKey(ck)
						thssteps = SONGMAN:GetStepsByChartKey(ck)
						MESSAGEMAN:Broadcast("DisplayProfileRankingLabels")
					else
						self:visible(false)
					end
				else
					onlineScore = DLMAN:GetTopSkillsetScore(i, ms.SkillSets[rankingSkillset])
					MESSAGEMAN:Broadcast("DisplayProfileRankingLabels")
					if not onlineScore then
						self:visible(false)
					else
						self:visible(true)
					end
				end
			else
				onlineScore = nil
				self:visible(false)
			end
		end,
		LoadFont("Common Normal") .. {
			Name = "text1",
			InitCommand = function(self)
				self:xy(0, 0):halign(0):zoom(fontScale):maxwidth(40)
			end,
			DisplayProfileRankingLabelsMessageCommand = function(self)
				if not showOnline then
					if ths then
						self:settext(((rankingPage - 1) * scoresperpage) + i .. ".")
						self:diffuse(byValidity(ths:GetEtternaValid()))
					end
				else
					self:settext(i .. ".")
					self:diffuse(COLOR.TextMain)
				end
			end
		},
		LoadFont("Common Normal") .. {
			Name = "text2",
			InitCommand = function(self)
				self:xy(18, 0):halign(0):zoom(fontScale):maxwidth(60)
			end,
			DisplayProfileRankingLabelsMessageCommand = function(self)
				if not showOnline then
					if ths then
						local rating = ths:GetSkillsetSSR(ms.SkillSets[rankingSkillset])
						self:settextf("%5.2f", rating)
						if not ths:GetEtternaValid() then
							self:diffuse(color("#FF4444"))
						else
							self:diffuse(byMSD(rating))
						end
					else
						self:settext("")
					end
				else
					if onlineScore then
						self:settextf("%5.2f", onlineScore.ssr)
						self:diffuse(byMSD(onlineScore.ssr))
					else
						self:settext("")
					end
				end
			end
		},
		LoadFont("Common Normal") .. {
			Name = "text3",
			InitCommand = function(self)
				self:xy(62, 0):halign(0):zoom(fontScale):maxwidth((frameWidth - 220) / fontScale)
			end,
			DisplayProfileRankingLabelsMessageCommand = function(self)
				if not showOnline then
					if thssong and ths then
						self:settext(thssong:GetDisplayMainTitle())
						self:diffuse(byValidity(ths:GetEtternaValid()))
					else
						self:settext("")
					end
				else
					if onlineScore then
						self:settext(onlineScore.songName)
						self:diffuse(COLOR.TextMain)
					else
						self:settext("")
					end
				end
			end
		},
		LoadFont("Common Normal") .. {
			Name = "text4",
			InitCommand = function(self)
				self:xy(frameWidth - 130, 0):halign(0.5):zoom(fontScale)
			end,
			DisplayProfileRankingLabelsMessageCommand = function(self)
				if not showOnline then
					if ths then
						local ratestring = string.format("%.2f", ths:GetMusicRate()):gsub("%.?0+$", "") .. "x"
						self:settext(ratestring)
						self:diffuse(byValidity(ths:GetEtternaValid()))
					else
						self:settext("")
					end
				else
					if onlineScore then
						local ratestring = string.format("%.2f", onlineScore.rate):gsub("%.?0+$", "") .. "x"
						self:settext(ratestring)
						self:diffuse(COLOR.TextMain)
					else
						self:settext("")
					end
				end
			end
		},
		LoadFont("Common Normal") .. {
			Name = "text5",
			InitCommand = function(self)
				self:xy(frameWidth - 110, 0):halign(0):zoom(fontScale):maxwidth(55 / fontScale)
			end,
			DisplayProfileRankingLabelsMessageCommand = function(self)
				if not showOnline then
					if ths then
						local wifeval = ths:GetWifeScore() * 100
						if wifeval > 99.9 then
							self:settextf("%5.4f%%", wifeval)
						else
							self:settextf("%5.2f%%", wifeval)
						end
						if not ths:GetEtternaValid() then
							self:diffuse(color("#FF4444"))
						else
							self:diffuse(getGradeColor(ths:GetWifeGrade()))
						end
					else
						self:settext("")
					end
				else
					if onlineScore then
						self:settextf("%5.2f%%", onlineScore.wife * 100)
						self:diffuse(getGradeColor(onlineScore.grade))
					else
						self:settext("")
					end
				end
			end
		},
		LoadFont("Common Normal") .. {
			Name = "text6",
			InitCommand = function(self)
				self:xy(frameWidth - 20, 0):halign(1):zoom(fontScale)
			end,
			DisplayProfileRankingLabelsMessageCommand = function(self)
				if not showOnline then
					if thssteps then
						local diff = thssteps:GetDifficulty()
						if not ths:GetEtternaValid() then
							self:diffuse(color("#FF4444"))
						else
							self:diffuse(byDifficulty(diff))
						end
						self:settext(GetDifficultyLabel(diff))
					else
						self:settext("")
					end
				else
					if onlineScore then
						local diff = onlineScore.difficulty
						self:diffuse(byDifficulty(diff))
						self:settext(GetDifficultyLabel(diff))
					else
						self:settext("")
					end
				end
			end
		},
		UIElements.QuadButton(1, 1) .. {
			InitCommand = function(self)
				self:xy(0, -1):halign(0):valign(0):diffusealpha(0)
			end,
			DisplayProfileRankingLabelsMessageCommand = function(self)
				self:visible(true)
				self:zoomto(frameWidth - 20, scoreYspacing)
			end,
			MouseDownCommand = function(self, params)
				if (rankingSkillset > 1 or topactive) and params.event == "DeviceButton_left mouse button" and update then
					if not showOnline then
						if ths then
							whee:SelectSong(thssong)
						end
					elseif onlineScore and onlineScore.chartkey then
						local song = SONGMAN:GetSongByChartKey(onlineScore.chartkey)
						if song then
							whee:SelectSong(song)
						end
					end
				elseif params.event == "DeviceButton_right mouse button" and update and not showOnline and ths then
					ths:ToggleEtternaValidation()
					BroadcastIfActive("UpdateRanking")
					if ths:GetEtternaValid() then
						ms.ok(translated_info["Validated"])
					else
						ms.ok(translated_info["Invalidated"])
					end
				end
			end,
			MouseOverCommand = function(self)
				local alpha = 0.7
				for j = 1,6 do
					self:GetParent():GetChild("text" .. j):diffusealpha(alpha)
				end
			end,
			MouseOutCommand = function(self)
				local alpha = 1
				for j = 1,6 do
					self:GetParent():GetChild("text" .. j):diffusealpha(alpha)
				end
			end,
		}
	}
	return t
end

local function rankingButton(i)
	local t = Def.ActorFrame {
		InitCommand = function(self)
			self:xy(rankingX + (i - 1) * rankingTitleSpacing, rankingY)
		end,
		UIElements.QuadButton(1, 1) .. {
			InitCommand = function(self)
				self:zoomto(rankingTitleSpacing - 2, 20):halign(0):valign(0):diffuse(color("#E5E5E5"))
			end,
			SetCommand = function(self)
				if i == rankingSkillset and not recentactive and not topactive then
					self:diffuse(COLOR.MainHighlight)
				else
					self:diffuse(color("#E5E5E5"))
				end
			end,
			MouseDownCommand = function(self, params)
				if params.event == "DeviceButton_left mouse button" and update then
					recentactive = false
					topactive = false
					rankingSkillset = i
					rankingPage = 1
					if not percentactive then
						SCOREMAN:SortSSRsForGame(ms.SkillSets[rankingSkillset])
					else
						SCOREMAN:SortSSRsByPercentForGame()
					end
					BroadcastIfActive("UpdateRanking")
				end
			end,
			UpdateRankingMessageCommand = function(self)
				self:queuecommand("Set")
			end,
			MouseOverCommand = function(self)
				self:diffusealpha(0.7)
			end,
			MouseOutCommand = function(self)
				self:diffusealpha(1)
			end,
		},
		LoadFont("Common Normal") .. {
			Name = "RankButtonTxt",
			InitCommand = function(self)
				self:xy(rankingTitleSpacing / 2, 10):halign(0.5):valign(0.5):diffuse(COLOR.TextMain):maxwidth(150):zoom(0.35)
			end,
			BeginCommand = function(self)
				self:settext(ms.SkillSetsTranslated[i])
			end
		}
	}
	return t
end

local function recentLabel(i)
	local ths
	local ck
	local thssteps
	local thssong
	local onlineScore

	local t = Def.ActorFrame {
		InitCommand = function(self)
			self:xy(10, 56 + (i - 1) * scoreYspacing)
			self:visible(false)
		end,
		UpdateRankingMessageCommand = function(self)
			if recentactive and update then
				ths = SCOREMAN:GetRecentScoreForGame(i + (scoresperpage * (rankingPage - 1)))
				if ths then
					self:visible(true)
					ck = ths:GetChartKey()
					thssong = SONGMAN:GetSongByChartKey(ck)
					thssteps = SONGMAN:GetStepsByChartKey(ck)
					MESSAGEMAN:Broadcast("DisplayProfileRankingLabels")
				else
					self:visible(false)
				end
			else
				onlineScore = nil
				self:visible(false)
			end
		end,
		LoadFont("Common Normal") .. {
			Name = "rectext1",
			InitCommand = function(self)
				self:xy(0, 0):halign(0):zoom(fontScale):maxwidth(40)
			end,
			DisplayProfileRankingLabelsMessageCommand = function(self)
				if ths then
					self:settext(((rankingPage - 1) * scoresperpage) + i .. ".")
					self:diffuse(byValidity(ths:GetEtternaValid()))
				end
			end
		},
		LoadFont("Common Normal") .. {
			Name = "rectext2",
			InitCommand = function(self)
				self:xy(18, 0):halign(0):zoom(fontScale):maxwidth(60)
			end,
			DisplayProfileRankingLabelsMessageCommand = function(self)
				if ths then
					local rating = ths:GetSkillsetSSR(ms.SkillSets[1])
					self:settextf("%5.2f", rating)
					if not ths:GetEtternaValid() then
						self:diffuse(color("#FF4444"))
					else
						self:diffuse(byMSD(rating))
					end
				else
					self:settext("")
				end
			end
		},
		LoadFont("Common Normal") .. {
			Name = "rectext3",
			InitCommand = function(self)
				self:xy(62, 0):halign(0):zoom(fontScale):maxwidth((frameWidth - 220) / fontScale)
			end,
			DisplayProfileRankingLabelsMessageCommand = function(self)
				if thssong and ths then
					self:settext(thssong:GetDisplayMainTitle())
					self:diffuse(byValidity(ths:GetEtternaValid()))
				else
					self:settext("")
				end
			end
		},
		LoadFont("Common Normal") .. {
			Name = "rectext4",
			InitCommand = function(self)
				self:xy(frameWidth - 130, 0):halign(0.5):zoom(fontScale)
			end,
			DisplayProfileRankingLabelsMessageCommand = function(self)
				if ths then
					local ratestring = string.format("%.2f", ths:GetMusicRate()):gsub("%.?0+$", "") .. "x"
					self:settext(ratestring)
					self:diffuse(byValidity(ths:GetEtternaValid()))
				else
					self:settext("")
				end
			end
		},
		LoadFont("Common Normal") .. {
			Name = "rectext5",
			InitCommand = function(self)
				self:xy(frameWidth - 110, 0):halign(0):zoom(fontScale):maxwidth(55 / fontScale)
			end,
			DisplayProfileRankingLabelsMessageCommand = function(self)
				if ths then
					local wifeval = ths:GetWifeScore() * 100
					if wifeval > 99.9 then
						self:settextf("%5.4f%%", wifeval)
					else
						self:settextf("%5.2f%%", wifeval)
					end
					if not ths:GetEtternaValid() then
						self:diffuse(color("#FF4444"))
					else
						self:diffuse(getGradeColor(ths:GetWifeGrade()))
					end
				else
					self:settext("")
				end
			end
		},
		LoadFont("Common Normal") .. {
			Name = "rectext6",
			InitCommand = function(self)
				self:xy(frameWidth - 20, 0):halign(1):zoom(fontScale)
			end,
			DisplayProfileRankingLabelsMessageCommand = function(self)
				if thssteps then
					local diff = thssteps:GetDifficulty()
					if not ths:GetEtternaValid() then
						self:diffuse(color("#FF4444"))
					else
						self:diffuse(byDifficulty(diff))
					end
					self:settext(GetDifficultyLabel(diff))
				else
					self:settext("")
				end
			end
		}
	}
	return t
end

-- Top Score button (ONLY visible when selected skillset tab is Overall - rankingSkillset == 1)
r[#r + 1] = Def.ActorFrame {
	InitCommand = function(self)
		self:xy(10, 5)
	end,
	UpdateRankingMessageCommand = function(self)
		if rankingSkillset == 1 and update then
			self:visible(true)
		else
			self:visible(false)
		end
	end,
	UIElements.QuadButton(1, 1) .. {
		InitCommand = function(self)
			self:zoomto(70, 20):halign(0):valign(0)
		end,
		UpdateRankingMessageCommand = function(self)
			if topactive then
				self:diffuse(COLOR.MainHighlight)
			else
				self:diffuse(color("#E5E5E5"))
			end
		end,
		MouseDownCommand = function(self, params)
			if params.event == "DeviceButton_left mouse button" and update then
				topactive = not topactive
				recentactive = false
				percentactive = false
				rankingPage = 1
				if topactive then
					SCOREMAN:SortSSRsForGame(ms.SkillSets[1])
				end
				BroadcastIfActive("UpdateRanking")
			end
		end,
	},
	LoadFont("Common Normal") .. {
		InitCommand = function(self)
			self:xy(35, 10):halign(0.5):valign(0.5):zoom(0.35):diffuse(COLOR.TextMain)
			self:settext("Top Scores")
		end,
	}
}

-- Percent button
r[#r + 1] = Def.ActorFrame {
	InitCommand = function(self)
		self:xy(85, 5)
	end,
	UpdateRankingMessageCommand = function(self)
		if update then
			self:visible(true)
		else
			self:visible(false)
		end
	end,
	UIElements.QuadButton(1, 1) .. {
		InitCommand = function(self)
			self:zoomto(55, 20):halign(0):valign(0)
		end,
		UpdateRankingMessageCommand = function(self)
			if percentactive then
				self:diffuse(COLOR.MainHighlight)
			else
				self:diffuse(color("#E5E5E5"))
			end
		end,
		MouseDownCommand = function(self, params)
			if params.event == "DeviceButton_left mouse button" and update then
				percentactive = not percentactive
				showOnline = false
				recentactive = false
				topactive = false
				rankingPage = 1
				if not percentactive then
					SCOREMAN:SortSSRsForGame(ms.SkillSets[rankingSkillset])
				else
					SCOREMAN:SortSSRsByPercentForGame()
				end
				BroadcastIfActive("UpdateRanking")
			end
		end,
	},
	LoadFont("Common Normal") .. {
		InitCommand = function(self)
			self:xy(27.5, 10):halign(0.5):valign(0.5):zoom(0.35):diffuse(COLOR.TextMain)
			self:settext(translated_info["Percent"])
		end,
	}
}

-- Recent button
r[#r + 1] = Def.ActorFrame {
	InitCommand = function(self)
		self:xy(145, 5)
	end,
	UpdateRankingMessageCommand = function(self)
		if update then
			self:visible(true)
		else
			self:visible(false)
		end
	end,
	UIElements.QuadButton(1, 1) .. {
		InitCommand = function(self)
			self:zoomto(55, 20):halign(0):valign(0)
		end,
		UpdateRankingMessageCommand = function(self)
			if recentactive then
				self:diffuse(COLOR.MainHighlight)
			else
				self:diffuse(color("#E5E5E5"))
			end
		end,
		MouseDownCommand = function(self, params)
			if params.event == "DeviceButton_left mouse button" and update then
				recentactive = not recentactive
				percentactive = false
				topactive = false
				rankingPage = 1
				if recentactive then
					SCOREMAN:SortRecentScoresForGame()
				end
				BroadcastIfActive("UpdateRanking")
			end
		end,
	},
	LoadFont("Common Normal") .. {
		InitCommand = function(self)
			self:xy(27.5, 10):halign(0.5):valign(0.5):zoom(0.35):diffuse(COLOR.TextMain)
			self:settext(translated_info["Recent"])
		end,
	}
}

-- Local & Online Subtab Buttons on the right of header
r[#r + 1] = Def.ActorFrame {
	InitCommand = function(self)
		self:xy(frameWidth - 115, 5)
	end,
	UpdateRankingMessageCommand = function(self)
		if DLMAN:IsLoggedIn() then
			self:visible(true)
		else
			self:visible(false)
		end
	end,
	Def.ActorFrame {
		InitCommand = function(self)
			self:xy(0, 0)
		end,
		UIElements.QuadButton(1, 1) .. {
			InitCommand = function(self)
				self:zoomto(50, 20):halign(0):valign(0)
			end,
			UpdateRankingMessageCommand = function(self)
				if not showOnline then
					self:diffuse(COLOR.MainHighlight)
				else
					self:diffuse(color("#E5E5E5"))
				end
			end,
			MouseDownCommand = function(self, params)
				if params.event == "DeviceButton_left mouse button" and update then
					showOnline = false
					BroadcastIfActive("UpdateRanking")
				end
			end,
		},
		LoadFont("Common Normal") .. {
			Name = "LocalTxt",
			InitCommand = function(self)
				self:xy(25, 10):halign(0.5):valign(0.5):zoom(0.35):diffuse(COLOR.TextMain)
				self:settext(translated_info["Local"])
			end
		}
	},
	Def.ActorFrame {
		InitCommand = function(self)
			self:xy(55, 0)
		end,
		UIElements.QuadButton(1, 1) .. {
			InitCommand = function(self)
				self:zoomto(50, 20):halign(0):valign(0)
			end,
			UpdateRankingMessageCommand = function(self)
				if showOnline then
					self:diffuse(COLOR.MainHighlight)
				else
					self:diffuse(color("#E5E5E5"))
				end
			end,
			MouseDownCommand = function(self, params)
				if params.event == "DeviceButton_left mouse button" and update and DLMAN:IsLoggedIn() then
					showOnline = true
					BroadcastIfActive("UpdateRanking")
				end
			end,
		},
		LoadFont("Common Normal") .. {
			Name = "OnlineTxt",
			InitCommand = function(self)
				self:xy(25, 10):halign(0.5):valign(0.5):zoom(0.35):diffuse(COLOR.TextMain)
				self:settext(translated_info["Online"])
			end
		}
	}
}

-- Next / Prev Page Navigation for Scores List
r[#r + 1] = Def.ActorFrame {
	InitCommand = function(self)
		self:xy(10, frameHeight - 30):visible(false)
	end,
	UpdateRankingMessageCommand = function(self)
		if (rankingSkillset > 1 or topactive or recentactive or percentactive) and not showOnline then
			self:visible(true)
		else
			self:visible(false)
		end
	end,
	UIElements.QuadButton(1, 1) .. {
		InitCommand = function(self)
			self:xy(frameWidth - 60, 0):zoomto(50, 20):halign(0):valign(0):diffuse(color("#E5E5E5"))
		end,
		MouseDownCommand = function(self, params)
			if params.event == "DeviceButton_left mouse button" then
				if rankingPage < numrankingpages then
					rankingPage = rankingPage + 1
				else
					rankingPage = 1
				end
				BroadcastIfActive("UpdateRanking")
			end
		end,
	},
	LoadFont("Common Normal") .. {
		Name = "NextP",
		InitCommand = function(self)
			self:xy(frameWidth - 35, 10):halign(0.5):valign(0.5):zoom(0.35):diffuse(COLOR.TextMain):settext(translated_info["NextPage"])
		end,
	},
	UIElements.QuadButton(1, 1) .. {
		InitCommand = function(self)
			self:xy(0, 0):zoomto(50, 20):halign(0):valign(0):diffuse(color("#E5E5E5"))
		end,
		MouseDownCommand = function(self, params)
			if params.event == "DeviceButton_left mouse button" then
				if rankingPage > 1 then
					rankingPage = rankingPage - 1
				else
					rankingPage = numrankingpages
				end
				BroadcastIfActive("UpdateRanking")
			end
		end,
	},
	LoadFont("Common Normal") .. {
		Name = "PrevP",
		InitCommand = function(self)
			self:xy(25, 10):halign(0.5):valign(0.5):zoom(0.35):diffuse(COLOR.TextMain):settext(translated_info["PrevPage"])
		end,
	},
}

for i = 1, scoresperpage do
	r[#r + 1] = rankingLabel(i)
end

for i = 1, scoresperpage do
	r[#r + 1] = recentLabel(i)
end

for i = 1, #ms.SkillSets do
	r[#r + 1] = rankingButton(i)
end

local function littlebits(i)
	local t = Def.ActorFrame {
		InitCommand = function(self)
			self:xy(30, 30)
		end,
		UpdateRankingMessageCommand = function(self)
			if rankingSkillset == 1 and update and not recentactive and not topactive and not percentactive then
				self:visible(true)
			else
				self:visible(false)
			end
		end,
		LoadFont("Common Normal") .. {
			InitCommand = function(self)
				self:xy(0, txtDist * (i - 1)):halign(0):zoom(0.55):diffuse(COLOR.TextMain)
			end,
			SetCommand = function(self)
				self:settext(ms.SkillSetsTranslated[i] .. ":")
			end,
		},
		LoadFont("Common Normal") .. {
			InitCommand = function(self)
				self:xy(180, txtDist * (i - 1)):halign(0):zoom(0.55)
			end,
			SetCommand = function(self)
				local rating = 0
				if not showOnline then
					rating = profile:GetPlayerSkillsetRating(ms.SkillSets[i])
					self:settextf("%05.2f", rating)
				else
					rating = DLMAN:GetSkillsetRating(ms.SkillSets[i])
					self:settextf("%05.2f (#%i)", rating, DLMAN:GetSkillsetRank(ms.SkillSets[i]))
				end
				self:diffuse(byMSD(rating))
			end,
			UpdateRankingMessageCommand = function(self)
				self:queuecommand("Set")
			end,
			PlayerRatingUpdatedMessageCommand = function(self)
				self:queuecommand("Set")
			end
		}
	}
	return t
end

for i = 2, #ms.SkillSets do
	r[#r + 1] = littlebits(i)
end

local user
local pass
local profilebuttons = Def.ActorFrame {
	InitCommand = function(self)
		self:xy(frameX, frameY)
	end,
	BeginCommand = function(self)
		user = playerConfig:get_data(pn_to_profile_slot(PLAYER_1)).UserName
		local passToken = playerConfig:get_data(pn_to_profile_slot(PLAYER_1)).PasswordToken
		if passToken ~= "" and answer ~= "" then
			if not DLMAN:IsLoggedIn() then
				DLMAN:LoginWithToken(user, passToken)
			end
		else
			passToken = ""
			user = ""
		end
	end,
	UpdateRankingMessageCommand = function(self)
		if rankingSkillset == 1 and update and not recentactive and not topactive and not percentactive then
			self:visible(true)
		else
			self:visible(false)
		end
	end,
	UIElements.TextToolTip(1, 1, "Common Normal") .. {
		InitCommand = function(self)
			self:xy(frameWidth * 1/7, frameHeight - 30):halign(0.5):diffuse(COLOR.TextMain):zoom(0.35)
			self:settext(translated_info["Save"])
		end,
		MouseOverCommand = function(self)
			self:diffusealpha(hoverAlpha)
		end,
		MouseOutCommand = function(self)
			self:diffusealpha(1)
		end,
		MouseDownCommand = function(self, params)
			if params.event == "DeviceButton_left mouse button" and update and rankingSkillset == 1 and not recentactive then
				if PROFILEMAN:SaveProfile(PLAYER_1) then
					ms.ok(translated_info["Success"])
					STATSMAN:UpdatePlayerRating()
				else
					ms.ok(translated_info["Failure"])
				end
			end
		end
	},
	UIElements.TextToolTip(1, 1, "Common Normal") .. {
		InitCommand = function(self)
			self:xy(frameWidth * 3/7, frameHeight - 30):halign(0.5):diffuse(COLOR.TextMain):zoom(0.35)
			self:settext(translated_info["AssetSettings"])
		end,
		MouseOverCommand = function(self)
			self:diffusealpha(hoverAlpha)
		end,
		MouseOutCommand = function(self)
			self:diffusealpha(1)
		end,
		MouseDownCommand = function(self, params)
			if params.event == "DeviceButton_left mouse button" and update and rankingSkillset == 1 and not recentactive then
				SCREENMAN:SetNewScreen("ScreenAssetSettings")
			end
		end,
	},
	UIElements.TextToolTip(1, 1, "Common Normal") .. {
		InitCommand = function(self)
			self:xy(frameWidth * 1/7, frameHeight - 12):halign(0.5):diffuse(COLOR.TextMain):zoom(0.35)
			self:settext(translated_info["ValidateAll"])
		end,
		MouseOverCommand = function(self)
			self:diffusealpha(hoverAlpha)
		end,
		MouseOutCommand = function(self)
			self:diffusealpha(1)
		end,
		MouseDownCommand = function(self, params)
			if params.event == "DeviceButton_left mouse button" and update and rankingSkillset == 1 and not recentactive then
				profile:UnInvalidateAllScores()
				STATSMAN:UpdatePlayerRating()
			end
		end,
	},
	UIElements.TextToolTip(1, 1, "Common Normal") .. {
		InitCommand = function(self)
			self:xy(frameWidth * 3/7, frameHeight - 12):diffuse(COLOR.TextMain):zoom(0.35)
			self:settext(translated_info["ForceRecalc"])
		end,
		MouseOverCommand = function(self)
			self:diffusealpha(hoverAlpha)
		end,
		MouseOutCommand = function(self)
			self:diffusealpha(1)
		end,
		MouseDownCommand = function(self, params)
			if params.event == "DeviceButton_left mouse button" and update and rankingSkillset == 1 and not recentactive  then
				ms.ok("Recalculating Scores... this might be slow and may or may not crash")
				profile:ForceRecalcScores()
				STATSMAN:UpdatePlayerRating()
			end
		end,
	},
	UIElements.TextToolTip(1, 1, "Common Normal") .. {
		InitCommand = function(self)
			self:xy(frameWidth * 5.3/7, frameHeight - 12):diffuse(COLOR.TextMain):zoom(0.35)
			self:settext(translated_info["UploadAllScore"])
		end,
		MouseOverCommand = function(self)
			self:diffusealpha(hoverAlpha)
		end,
		MouseOutCommand = function(self)
			self:diffusealpha(1)
		end,
		MouseDownCommand = function(self, params)
			if params.event == "DeviceButton_left mouse button" and update and rankingSkillset == 1 and not recentactive  then
				if DLMAN:IsLoggedIn() then
					DLMAN:UploadAllScores()
				else
					ms.ok("You must be logged in...")
				end
			end
		end,
	},
}

t[#t + 1] = profilebuttons
t[#t + 1] = r
return t
