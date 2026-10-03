local numbershers = {"1", "2", "3", "4", "5", "6", "7", "8", "9", "0"}
local frameWidth = capWideScale(360, 400)
local frameX = SCREEN_WIDTH - frameWidth - 10
local frameY = 95
local active = false
local whee
local spacingY = 20
local textzoom = 0.35
local ActiveSS = 0
local SSQuery = {}
SSQuery[0] = {}
SSQuery[1] = {}
local frameHeight = SCREEN_HEIGHT - 135
local offsetX = 10
local offsetY = 24
local activebound = 0
for i = 1, #ms.SkillSets + 2 do
	SSQuery[0][i] = "0"
	SSQuery[1][i] = "0"
end
local numbersafterthedecimal = 0

local hoverAlpha = 0.6
local instantSearch = themeConfig:get_data().global.InstantSearch

local function FilterInput(event)
	if event.type ~= "InputEventType_Release" and ActiveSS > 0 and active then
		local shouldUpdate = false
		if event.button == "Start" or event.button == "Back" then
			ActiveSS = 0
			MESSAGEMAN:Broadcast("NumericInputEnded")
			SCREENMAN:set_input_redirected(PLAYER_1, false)
			return true
		elseif event.DeviceInput.button == "DeviceButton_backspace" then
			SSQuery[activebound][ActiveSS] = SSQuery[activebound][ActiveSS]:sub(1, -2)
			shouldUpdate = true
		elseif event.DeviceInput.button == "DeviceButton_delete" then
			SSQuery[activebound][ActiveSS] = ""
			shouldUpdate = true
		else
			for i = 1, #numbershers do
				if event.DeviceInput.button == "DeviceButton_" .. numbershers[i] then
					shouldUpdate = true
					if SSQuery[activebound][ActiveSS] == "0" then
						SSQuery[activebound][ActiveSS] = ""
					end
					SSQuery[activebound][ActiveSS] = SSQuery[activebound][ActiveSS] .. numbershers[i]
					if (ActiveSS < #ms.SkillSets + 1 and #SSQuery[activebound][ActiveSS] > 2) or (ActiveSS < #ms.SkillSets + 2 and #SSQuery[activebound][ActiveSS] > 3) or #SSQuery[activebound][ActiveSS] > 5 then
						SSQuery[activebound][ActiveSS] = numbershers[i]
					end
				end
			end
		end
		if SSQuery[activebound][ActiveSS] == "" then
			shouldUpdate = true
			SSQuery[activebound][ActiveSS] = "0"
		end
		if shouldUpdate then
			local num = 0
			if ActiveSS == #ms.SkillSets+2 then
				local q = SSQuery[activebound][ActiveSS]
				numbersafterthedecimal = 0
				if #q > 2 then
					numbersafterthedecimal = #q-2
					local n = tonumber(q) / (10 ^ (#q-2))
					n = notShit.round(n, numbersafterthedecimal)
					num = n
				else
					num = tonumber(q)
				end
			else
				num = tonumber(SSQuery[activebound][ActiveSS])
			end
			FILTERMAN:SetSSFilter(num, ActiveSS, activebound)
			whee:SongSearch("") -- stupid workaround?
			MESSAGEMAN:Broadcast("UpdateFilter")
		end
	end
end

local translated_info = {
	Mode = THEME:GetString("TabFilter", "Mode"),
	HighestOnly = THEME:GetString("TabFilter", "HighestOnly"),
	HighestDifficultyOnly = THEME:GetString("TabFilter", "HighestDifficultyOnly"),
	On = THEME:GetString("OptionNames", "On"),
	Off = THEME:GetString("OptionNames", "Off"),
	Matches = THEME:GetString("TabFilter", "Matches"),
	CommonPackFilter = THEME:GetString("TabFilter", "CommonPackFilter"),
	Length = THEME:GetString("TabFilter", "Length"),
	BestPercent = "Best %",
	AND = THEME:GetString("TabFilter", "AND"),
	OR = THEME:GetString("TabFilter", "OR"),
	ExplainStartInput = THEME:GetString("TabFilter", "ExplainStartInput"),
	ExplainCancelInput = THEME:GetString("TabFilter", "ExplainCancelInput"),
	ExplainGrey = THEME:GetString("TabFilter", "ExplainGrey"),
	ExplainBounds = THEME:GetString("TabFilter", "ExplainBounds"),
	ExplainHighest = THEME:GetString("TabFilter", "ExplainHighest"),
	ExplainHighestDifficulty = THEME:GetString("TabFilter", "ExplainHighestDifficulty"),
	MaxRate = THEME:GetString("TabFilter", "MaxRate"),
	Title = THEME:GetString("TabFilter", "Title"),
	MinRate = THEME:GetString("TabFilter", "MinRate"),
}

local f = Def.ActorFrame {
	BeginCommand = function(self)
		self:halign(0):visible(false)
		whee = SCREENMAN:GetTopScreen():GetMusicWheel()
		SCREENMAN:GetTopScreen():AddInputCallback(FilterInput)
		self:queuecommand("Set")
	end,
	OffCommand = function(self)
		self:decelerate(0.6):xy(SCREEN_WIDTH + 500, frameY):diffusealpha(0)
		self:sleep(0.04):queuecommand("Invis")
	end,
	InvisCommand= function(self)
		self:visible(false)
	end,
	OnCommand = function(self)
		self:xy(SCREEN_WIDTH + 500, frameY):decelerate(0.6):xy(frameX, frameY):diffusealpha(1)
	end,
	SetCommand = function(self)
		self:finishtweening()
		if getTabIndex() == 5 then
			self:visible(true)
			self:queuecommand("On")
			active = true
		else
			MESSAGEMAN:Broadcast("NumericInputEnded")
			self:queuecommand("Off")
			active = false
		end
	end,
	TabChangedMessageCommand = function(self)
		self:queuecommand("Set")
	end,
	MouseRightClickMessageCommand = function(self)
		ActiveSS = 0
		MESSAGEMAN:Broadcast("NumericInputEnded")
		MESSAGEMAN:Broadcast("UpdateFilter")
		SCREENMAN:set_input_redirected(PLAYER_1, false)
	end,
	-- Salmon offset backdrop
	Def.Quad {
		InitCommand = function(self)
			self:xy(5, 5):zoomto(frameWidth, frameHeight):halign(0):valign(0):diffuse(COLOR.MainHighlight)
		end
	},
	-- Main white backdrop card
	Def.Quad {
		InitCommand = function(self)
			self:zoomto(frameWidth, frameHeight):halign(0):valign(0):diffuse(COLOR.MainBackground)
		end
	},
	-- Border outline
	UIElements.Border(frameWidth, frameHeight, 1) .. {
		InitCommand = function(self)
			self:xy(frameWidth / 2, frameHeight / 2):diffuse(COLOR.MainBorder)
		end
	},
	-- Header bar
	Def.Quad {
		InitCommand = function(self)
			self:zoomto(frameWidth, offsetY):halign(0):valign(0):diffuse(COLOR.MainHighlight)
		end
	},
	LoadFont("Common Normal") .. {
		InitCommand = function(self)
			self:xy(10, offsetY / 2):zoom(0.55):halign(0):valign(0.5):settext(translated_info["Title"])
			self:diffuse(COLOR.TextMain)
		end
	},
	LoadFont("Common Normal") .. {
		InitCommand = function(self)
			self:xy(10, 28):zoom(0.3):halign(0):diffuse(COLOR.TextSub1)
			self:settext(translated_info["ExplainStartInput"])
		end
	},
	LoadFont("Common Normal") .. {
		InitCommand = function(self)
			self:xy(10, 40):zoom(0.3):halign(0):diffuse(COLOR.TextSub1)
			self:settext(translated_info["ExplainCancelInput"])
		end
	},
	LoadFont("Common Normal") .. {
		InitCommand = function(self)
			self:xy(10, 52):zoom(0.3):halign(0):diffuse(COLOR.TextSub1)
			self:settext(translated_info["ExplainGrey"])
		end
	},
	-- Right column filter options
	UIElements.TextToolTip(1, 1, "Common Normal") ..{
		InitCommand = function(self)
			self:xy(frameWidth / 2 + 10, 70):zoom(textzoom):halign(0)
			self:diffuse(COLOR.TextMain)
		end,
		SetCommand = function(self)
			self:settextf("%s:%5.1fx", translated_info["MaxRate"], FILTERMAN:GetMaxFilterRate())
		end,
		MaxFilterRateChangedMessageCommand = function(self)
			self:queuecommand("Set")
		end,
		ResetFilterMessageCommand = function(self)
			self:queuecommand("Set")
		end,
		MouseOverCommand = function(self)
			self:diffusealpha(hoverAlpha)
		end,
		MouseOutCommand = function(self)
			self:diffusealpha(1)
		end,
	},
	UIElements.QuadButton(1, 1) .. {
		InitCommand = function(self)
			self:xy(frameWidth / 2 + 10, 70):zoomto(130, 18):halign(0):diffusealpha(0)
		end,
		MouseDownCommand = function(self, params)
			if params.event == "DeviceButton_left mouse button" and active then
				FILTERMAN:SetMaxFilterRate(FILTERMAN:GetMaxFilterRate() + 0.1)
				MESSAGEMAN:Broadcast("MaxFilterRateChanged")
				whee:SongSearch("")
			elseif params.event == "DeviceButton_right mouse button" and active then
				FILTERMAN:SetMaxFilterRate(FILTERMAN:GetMaxFilterRate() - 0.1)
				MESSAGEMAN:Broadcast("MaxFilterRateChanged")
				whee:SongSearch("")
			end
		end,
	},
	UIElements.TextToolTip(1, 1, "Common Normal") ..{
		InitCommand = function(self)
			self:xy(frameWidth / 2 + 10, 70 + spacingY):zoom(textzoom):halign(0)
			self:diffuse(COLOR.TextMain)
		end,
		SetCommand = function(self)
			self:settextf("%s:%5.1fx", translated_info["MinRate"], FILTERMAN:GetMinFilterRate())
		end,
		MaxFilterRateChangedMessageCommand = function(self)
			self:queuecommand("Set")
		end,
		ResetFilterMessageCommand = function(self)
			self:queuecommand("Set")
		end,
		MouseOverCommand = function(self)
			self:diffusealpha(hoverAlpha)
		end,
		MouseOutCommand = function(self)
			self:diffusealpha(1)
		end,
	},
	UIElements.QuadButton(1, 1) .. {
		InitCommand = function(self)
			self:xy(frameWidth / 2 + 10, 70 + spacingY):zoomto(130, 18):halign(0):diffusealpha(0)
		end,
		MouseDownCommand = function(self, params)
			if params.event == "DeviceButton_left mouse button" and active then
				FILTERMAN:SetMinFilterRate(FILTERMAN:GetMinFilterRate() + 0.1)
				MESSAGEMAN:Broadcast("MaxFilterRateChanged")
				whee:SongSearch("")
			elseif params.event == "DeviceButton_right mouse button" and active then
				FILTERMAN:SetMinFilterRate(FILTERMAN:GetMinFilterRate() - 0.1)
				MESSAGEMAN:Broadcast("MaxFilterRateChanged")
				whee:SongSearch("")
			end
		end,
	},
	UIElements.TextToolTip(1, 1, "Common Normal") ..{
		InitCommand = function(self)
			self:xy(frameWidth / 2 + 10, 70 + spacingY * 2):zoom(textzoom):halign(0)
			self:diffuse(COLOR.TextMain)
		end,
		SetCommand = function(self)
			if FILTERMAN:GetFilterMode() then
				self:settextf("%s: %s", translated_info["Mode"], translated_info["AND"])
			else
				self:settextf("%s: %s", translated_info["Mode"], translated_info["OR"])
			end
		end,
		FilterModeChangedMessageCommand = function(self)
			self:queuecommand("Set")
		end,
		ResetFilterMessageCommand = function(self)
			self:queuecommand("Set")
		end,
		MouseOverCommand = function(self)
			self:diffusealpha(hoverAlpha)
		end,
		MouseOutCommand = function(self)
			self:diffusealpha(1)
		end,
	},
	UIElements.QuadButton(1, 1) .. {
		InitCommand = function(self)
			self:xy(frameWidth / 2 + 10, 70 + spacingY * 2):zoomto(120, 18):halign(0):diffusealpha(0)
		end,
		MouseDownCommand = function(self, params)
			if params.event == "DeviceButton_left mouse button" and active then
				FILTERMAN:ToggleFilterMode()
				MESSAGEMAN:Broadcast("FilterModeChanged")
				whee:SongSearch("")
			end
		end
	},
	UIElements.TextToolTip(1, 1, "Common Normal") ..{
		InitCommand = function(self)
			self:xy(frameWidth / 2 + 10, 70 + spacingY * 3):zoom(textzoom):halign(0)
		end,
		SetCommand = function(self)
			local translated = translated_info["HighestOnly"]
			if FILTERMAN:GetHighestSkillsetsOnly() then
				self:settextf("%s: %s", translated, translated_info["On"]):maxwidth(frameWidth / 2 / textzoom - 30)
			else
				self:settextf("%s: %s", translated, translated_info["Off"]):maxwidth(frameWidth / 2 / textzoom - 30)
			end
			if FILTERMAN:GetFilterMode() then
				self:diffuse(COLOR.TextSub2)
			else
				self:diffuse(COLOR.TextMain)
			end
		end,
		FilterModeChangedMessageCommand = function(self)
			self:queuecommand("Set")
		end,
		ResetFilterMessageCommand = function(self)
			self:queuecommand("Set")
		end,
		MouseOverCommand = function(self)
			if not FILTERMAN:GetFilterMode() then
				self:diffusealpha(hoverAlpha)
			end
		end,
		MouseOutCommand = function(self)
			if FILTERMAN:GetFilterMode() then
				self:diffusealpha(0.2)
			else
				self:diffusealpha(1)
			end
		end,
	},
	UIElements.QuadButton(1, 1) .. {
		InitCommand = function(self)
			self:xy(frameWidth / 2 + 10, 70 + spacingY * 3):zoomto(160, 18):halign(0):diffusealpha(0)
		end,
		MouseDownCommand = function(self, params)
			if params.event == "DeviceButton_left mouse button" and active and not FILTERMAN:GetFilterMode() then
				FILTERMAN:ToggleHighestSkillsetsOnly()
				MESSAGEMAN:Broadcast("FilterModeChanged")
				whee:SongSearch("")
			end
		end
	},
	UIElements.TextToolTip(1, 1, "Common Normal") ..{
		InitCommand = function(self)
			self:xy(frameWidth / 2 + 10, 70 + spacingY * 4):zoom(textzoom):halign(0)
		end,
		SetCommand = function(self)
			local translated = translated_info["HighestDifficultyOnly"]
			if FILTERMAN:GetHighestDifficultyOnly() then
				self:settextf("%s: %s", translated, translated_info["On"]):maxwidth(frameWidth / 2 / textzoom - 30)
			else
				self:settextf("%s: %s", translated, translated_info["Off"]):maxwidth(frameWidth / 2 / textzoom - 30)
			end
			if FILTERMAN:GetFilterMode() then
				self:diffuse(COLOR.TextSub2)
			else
				self:diffuse(COLOR.TextMain)
			end
		end,
		FilterModeChangedMessageCommand = function(self)
			self:queuecommand("Set")
		end,
		ResetFilterMessageCommand = function(self)
			self:queuecommand("Set")
		end,
		MouseOverCommand = function(self)
			if not FILTERMAN:GetFilterMode() then
				self:diffusealpha(hoverAlpha)
			end
		end,
		MouseOutCommand = function(self)
			if FILTERMAN:GetFilterMode() then
				self:diffusealpha(0.2)
			else
				self:diffusealpha(1)
			end
		end,
	},
	UIElements.QuadButton(1, 1) .. {
		InitCommand = function(self)
			self:xy(frameWidth / 2 + 10, 70 + spacingY * 4):zoomto(160, 18):halign(0):diffusealpha(0)
		end,
		MouseDownCommand = function(self, params)
			if params.event == "DeviceButton_left mouse button" and active and not FILTERMAN:GetFilterMode() then
				FILTERMAN:ToggleHighestDifficultyOnly()
				MESSAGEMAN:Broadcast("FilterModeChanged")
				whee:SongSearch("")
			end
		end
	},
	LoadFont("Common Normal") .. {
		InitCommand = function(self)
			self:xy(frameWidth / 2 + 10, 70 + spacingY * 6):zoom(textzoom):halign(0):settext(""):diffuse(COLOR.TextMain)
		end,
		FilterResultsMessageCommand = function(self, msg)
			self:settextf("%s: %i/%i", translated_info["Matches"], msg.Matches, msg.Total)
		end
	},
	UIElements.TextToolTip(1, 1, "Common Normal") .. {
		BeginCommand = function(self)
			self:xy(frameWidth / 2 + 10, 70 + spacingY * 7):zoom(textzoom):halign(0):maxwidth(160):diffuse(COLOR.TextMain)
			self.packlistFiltering = FILTERMAN:GetFilteringCommonPacks()
			self.enabled = SCREENMAN:GetTopScreen():GetName() == "ScreenNetSelectMusic"
			if not self.enabled then
				self:visible(false)
			end
			self:queuecommand("Set")
		end,
		MouseDownCommand = function(self, params)
			if self.enabled and params.event == "DeviceButton_left mouse button" and active then
				self.packlistFiltering = whee:SetPackListFiltering(not self.packlistFiltering)
				self:queuecommand("Set")
			end
		end,
		SetCommand = function(self)
			self:settextf("%s: %s", translated_info["CommonPackFilter"], (self.packlistFiltering and translated_info["On"] or translated_info["Off"]))
		end,
		FilterModeChangedMessageCommand = function(self)
			self:queuecommand("Set")
		end,
		ResetFilterMessageCommand = function(self)
			self:queuecommand("Set")
		end
	}
}

local function CreateFilterInputBox(i)
	local t = Def.ActorFrame {
		InitCommand = function(self)
			self:y(0)
		end,
		LoadFont("Common Normal") .. {
			InitCommand = function(self)
				self:addx(10):addy(70 + (i - 1) * spacingY):halign(0):zoom(textzoom):diffuse(COLOR.TextMain)
			end,
			SetCommand = function(self)
				self:settext(i == (#ms.SkillSets + 1) and translated_info["Length"] or (i == (#ms.SkillSets + 2) and translated_info["BestPercent"] or ms.SkillSetsTranslated[i]))
			end
		},
		UIElements.QuadButton(1, 1) .. {
			InitCommand = function(self)
				self:addx(i == (#ms.SkillSets + 1) and 145 or (i == (#ms.SkillSets + 2) and 145 or 135)):addy(70 + (i - 1) * spacingY):zoomto(
					i == (#ms.SkillSets + 1) and 27 or (i == (#ms.SkillSets + 2) and 27 or 22),
					16
				):halign(1)
			end,
			MouseDownCommand = function(self, params)
				if params.event == "DeviceButton_left mouse button" and active then
					ActiveSS = i
					activebound = 0
					MESSAGEMAN:Broadcast("NumericInputActive")
					self:diffusealpha(0.1)
					SCREENMAN:set_input_redirected(PLAYER_1, true)
				end
			end,
			SetCommand = function(self)
				if ActiveSS == i and activebound == 0 then
					self:diffuse(color("#666666"))
				else
					self:diffuse(color("#000000"))
				end
			end,
			UpdateFilterMessageCommand = function(self)
				self:queuecommand("Set")
			end,
			NumericInputEndedMessageCommand = function(self)
				self:queuecommand("Set")
			end,
			NumericInputActiveMessageCommand = function(self)
				self:queuecommand("Set")
			end
		},
		LoadFont("Common Normal") .. {
			InitCommand = function(self)
				self:addx(i == (#ms.SkillSets + 1) and 145 or (i == (#ms.SkillSets + 2) and 145 or 135)):addy(70 + (i - 1) * spacingY):halign(1):maxwidth(60):zoom(
					textzoom
				)
			end,
			SetCommand = function(self)
				local fval = notShit.round(FILTERMAN:GetSSFilter(i, 0), numbersafterthedecimal) -- lower bounds
				local fmtstr = ""
				if i == #ms.SkillSets+2 then
					if numbersafterthedecimal > 0 then
						fmtstr = "%5."..numbersafterthedecimal.."f"
					else
						fmtstr = "%02d."
					end
				else
					fmtstr = "%d"
				end
				self:settextf(fmtstr, fval)
				if fval <= 0 and ActiveSS ~= i then
					self:diffuse(color("#666666"))
				elseif activebound == 0 then
					self:diffuse(color("#FFFFFF"))
				end
			end,
			UpdateFilterMessageCommand = function(self)
				self:queuecommand("Set")
			end,
			NumericInputActiveMessageCommand = function(self)
				self:queuecommand("Set")
			end
		},
		UIElements.QuadButton(1, 1) .. {
			InitCommand = function(self)
				self:addx(i == (#ms.SkillSets + 1) and 175 or (i == (#ms.SkillSets + 2) and 175 or 160)):addy(70 + (i - 1) * spacingY):zoomto(
					i == (#ms.SkillSets + 1) and 27 or (i == (#ms.SkillSets + 2) and 27 or 22),
					16
				):halign(1)
			end,
			MouseDownCommand = function(self, params)
				if params.event == "DeviceButton_left mouse button" and active then
					ActiveSS = i
					activebound = 1
					MESSAGEMAN:Broadcast("NumericInputActive")
					self:diffusealpha(0.1)
					SCREENMAN:set_input_redirected(PLAYER_1, true)
				end
			end,
			SetCommand = function(self)
				if ActiveSS == i and activebound == 1 then
					self:diffuse(color("#666666"))
				else
					self:diffuse(color("#000000"))
				end
			end,
			UpdateFilterMessageCommand = function(self)
				self:queuecommand("Set")
			end,
			NumericInputEndedMessageCommand = function(self)
				self:queuecommand("Set")
			end,
			NumericInputActiveMessageCommand = function(self)
				self:queuecommand("Set")
			end
		},
		LoadFont("Common Normal") .. {
			InitCommand = function(self)
				self:addx(i == (#ms.SkillSets + 1) and 175 or (i == (#ms.SkillSets + 2) and 175 or 160)):addy(70 + (i - 1) * spacingY):halign(1):maxwidth(60):zoom(
					textzoom
				)
			end,
			SetCommand = function(self)
				local fval = notShit.round(FILTERMAN:GetSSFilter(i, 1), numbersafterthedecimal) -- upper bounds
				local fmtstr = "%5."
				if i == #ms.SkillSets+2 then
					if numbersafterthedecimal > 0 then
						fmtstr = "%5."..numbersafterthedecimal.."f"
					else
						fmtstr = "%02d."
					end
				else
					fmtstr = "%d"
				end
				self:settextf(fmtstr, fval)
				if fval <= 0 and ActiveSS ~= i then
					self:diffuse(color("#666666"))
				elseif activebound == 1 then
					self:diffuse(color("#FFFFFF"))
				end
			end,
			UpdateFilterMessageCommand = function(self)
				self:queuecommand("Set")
			end,
			NumericInputActiveMessageCommand = function(self)
				self:queuecommand("Set")
			end
		}
	}
	return t
end

-- reset button
f[#f + 1] = UIElements.TextButton(1, 1, "Common Normal") .. {
	InitCommand = function(self)
		self:xy(frameWidth / 2 + 50, 70 + spacingY * 9)
		local txt = self:GetChild("Text")
		local bg = self:GetChild("BG")
		txt:zoom(0.35)
		txt:settext(THEME:GetString("TabFilter", "Reset"))
		txt:diffuse(COLOR.TextMain)
		bg:zoomto(60, 20)
	end,
	RolloverUpdateCommand = function(self, params)
		if params.update == "in" then
			self:diffusealpha(hoverAlpha)
		else
			self:diffusealpha(1)
		end
	end,
	ClickCommand = function(self, params)
		if params.update ~= "OnMouseDown" then return end
		if params.event == "DeviceButton_left mouse button" and active then
			FILTERMAN:ResetAllFilters()
			for i = 1, #ms.SkillSets + 2 do
				SSQuery[0][i] = "0"
				SSQuery[1][i] = "0"
			end
			numbersafterthedecimal = 0
			activebound = 0
			ActiveSS = 0
			MESSAGEMAN:Broadcast("UpdateFilter")
			MESSAGEMAN:Broadcast("ResetFilter")
			MESSAGEMAN:Broadcast("NumericInputEnded")
			SCREENMAN:set_input_redirected(PLAYER_1, false)
			whee:SongSearch("")
		end
	end,
}

for i = 1, (#ms.SkillSets + 2) do
	f[#f + 1] = CreateFilterInputBox(i)
end
return f
