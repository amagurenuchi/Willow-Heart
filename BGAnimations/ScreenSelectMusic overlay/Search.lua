local searchstring = ""
local frameWidth = capWideScale(360, 400)
local frameX = SCREEN_WIDTH - frameWidth - 10
local frameY = 95
local frameHeight = SCREEN_HEIGHT - 135
local active = false
local whee
local lastsearchstring = ""
local config = themeConfig and themeConfig:get_data() or {global={}}
local instantSearch = config.global.InstantSearch or false
local IgnoreTabInput = config.global.IgnoreTabInput or 1

local function searchInput(event)
	if event.type ~= "InputEventType_Release" and active == true then
		if event.button == "Back" then
			local tind = getTabIndex()
			searchstring = ""
			whee:SongSearch(searchstring)
			resetTabIndex(0)
			MESSAGEMAN:Broadcast("TabChanged", {from = tind, to = 0})
			MESSAGEMAN:Broadcast("EndingSearch")
		elseif event.button == "Start" then
			local tind = getTabIndex()
			resetTabIndex(0)
			if not instantSearch then
				whee:SongSearch(searchstring)
			end
			MESSAGEMAN:Broadcast("EndingSearch")
			MESSAGEMAN:Broadcast("TabChanged", {from = tind, to = 0})
		elseif event.DeviceInput.button == "DeviceButton_space" then
			searchstring = searchstring .. " "
		elseif event.DeviceInput.button == "DeviceButton_backspace" then
			searchstring = searchstring:sub(1, -2)
		elseif event.DeviceInput.button == "DeviceButton_delete" then
			searchstring = ""
		else
			local CtrlPressed = INPUTFILTER:IsControlPressed()
			if event.DeviceInput.button == "DeviceButton_v" and CtrlPressed then
				searchstring = searchstring .. Arch.getClipboard()
			elseif
				event.char and event.char:match('[%%%+%-%!%@%#%$%^%&%*%(%)%=%_%.%,%:%;%\'%"%>%<%?%/%~%|%w%[%]%{%}%`%\\]') and
					(not tonumber(event.char) or CtrlPressed or IgnoreTabInput > 1)
			 then
				searchstring = searchstring .. event.char
			end
		end
		if lastsearchstring ~= searchstring then
			MESSAGEMAN:Broadcast("UpdateString")
			if instantSearch then
				whee:SongSearch(searchstring)
			end
			lastsearchstring = searchstring
		end
	end
end

local translated_info = {
	Active = THEME:GetString("TabSearch", "Active"),
	Complete = THEME:GetString("TabSearch", "Complete"),
	ExplainStart = THEME:GetString("TabSearch", "ExplainStart"),
	ExplainBack = THEME:GetString("TabSearch", "ExplainBack"),
	ExplainDel = THEME:GetString("TabSearch", "ExplainDelete"),
	ExplainLimit = THEME:GetString("TabSearch", "ExplainLimitation"),
	ExplainNumInput = THEME:GetString("TabSearch", "ExplainNumInput"),
	ExplainSuperSearch = THEME:GetString("TabSearch","ExplainSuperSearch"),
}

local t = Def.ActorFrame {
	BeginCommand = function(self)
		self:visible(false)
		self:queuecommand("Set")
		whee = SCREENMAN:GetTopScreen():GetMusicWheel()
		SCREENMAN:GetTopScreen():AddInputCallback(searchInput)
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
		if getTabIndex() == 3 then
			MESSAGEMAN:Broadcast("BeginningSearch")
			self:visible(true)
			self:queuecommand("On")
			active = true
			whee:Move(0)
			SCREENMAN:set_input_redirected(PLAYER_1, true)
			MESSAGEMAN:Broadcast("RefreshSearchResults")
		else
			self:queuecommand("Off")
			active = false
			SCREENMAN:set_input_redirected(PLAYER_1, false)
		end
	end,
	TabChangedMessageCommand = function(self)
		self:queuecommand("Set")
	end,
	-- Salmon-colored backdrop offset quad
	Def.Quad {
		InitCommand = function(self)
			self:xy(frameX + 5, frameY + 5):zoomto(frameWidth, frameHeight):halign(0):valign(0):diffuse(COLOR.MainHighlight)
		end
	},
	-- Main card background quad
	Def.Quad {
		InitCommand = function(self)
			self:xy(frameX, frameY):zoomto(frameWidth, frameHeight):halign(0):valign(0):diffuse(COLOR.MainBackground)
		end
	},
	-- Card border outline
	UIElements.Border(frameWidth, frameHeight, 1) .. {
		InitCommand = function(self)
			self:xy(frameX + frameWidth / 2, frameY + frameHeight / 2):diffuse(COLOR.MainBorder)
		end
	},
	-- Header bar
	Def.Quad {
		InitCommand = function(self)
			self:xy(frameX, frameY):zoomto(frameWidth, 24):halign(0):valign(0):diffuse(COLOR.MainHighlight)
		end
	},
	-- Header title label
	LoadFont("Common Normal") .. {
		InitCommand = function(self)
			self:xy(frameX + 10, frameY + 12):halign(0):valign(0.5):zoom(0.55):diffuse(COLOR.TextMain):settext("SEARCH")
		end
	},
	-- Search status label
	LoadFont("Common Normal") .. {
		InitCommand = function(self)
			self:xy(frameX + frameWidth - 10, frameY + 12):zoom(0.45):halign(1):valign(0.5)
		end,
		SetCommand = function(self)
			if active then
				self:settextf("%s:", translated_info["Active"]):diffuse(color("#000000"))
			elseif not active and searchstring ~= "" then
				self:settext(translated_info["Complete"]):diffuse(COLOR.TextSub1)
			else
				self:settext("")
			end
		end,
		UpdateStringMessageCommand = function(self)
			self:queuecommand("Set")
		end,
		SetSearchStringMessageCommand = function(self, params)
			if params.searchstring then
				searchstring = params.searchstring
				lastsearchstring = searchstring
				MESSAGEMAN:Broadcast("UpdateString")
			end
		end
	},
	-- Search input box background
	Def.Quad {
		InitCommand = function(self)
			self:xy(frameX + 15, frameY + 35):zoomto(frameWidth - 30, 36):halign(0):valign(0):diffuse(COLOR.MainBorder):diffusealpha(0.15)
		end,
	},
	-- Search input query text
	LoadFont("Common Normal") .. {
		InitCommand = function(self)
			self:xy(frameX + 25, frameY + 53):zoom(0.5):halign(0):valign(0.5):diffuse(COLOR.TextMain):maxwidth((frameWidth - 50) / 0.5)
		end,
		SetCommand = function(self)
			self:settext(searchstring)
		end,
		UpdateStringMessageCommand = function(self)
			self:queuecommand("Set")
		end
	},
	-- Instruction lines inside container
	LoadFont("Common Normal") .. {
		InitCommand = function(self)
			self:xy(frameX + 15, frameY + 90):zoom(0.42):halign(0):diffuse(COLOR.TextMain)
			self:settext(translated_info["ExplainStart"])
		end
	},
	LoadFont("Common Normal") .. {
		InitCommand = function(self)
			self:xy(frameX + 15, frameY + 115):zoom(0.42):halign(0):diffuse(COLOR.TextMain)
			self:settext(translated_info["ExplainBack"])
		end
	},
	LoadFont("Common Normal") .. {
		InitCommand = function(self)
			self:xy(frameX + 15, frameY + 140):zoom(0.42):halign(0):diffuse(COLOR.TextMain)
			self:settext(translated_info["ExplainDel"])
		end
	},
	LoadFont("Common Normal") .. {
		InitCommand = function(self)
			self:xy(frameX + 15, frameY + 175):zoom(0.42):halign(0):diffuse(COLOR.TextSub1)
			self:maxwidth((frameWidth - 30) / 0.42)
			self:settext(translated_info["ExplainLimit"])
		end
	},
	LoadFont("Common Normal") .. {
		InitCommand = function(self)
			self:xy(frameX + 15, frameY + 200):zoom(0.42):halign(0):diffuse(COLOR.TextSub1)
			self:maxwidth((frameWidth - 30) / 0.42)
			self:settext(translated_info["ExplainNumInput"])
		end
	},
	LoadFont("Common Normal") .. {
		InitCommand = function(self)
			self:xy(frameX + 15, frameY + 225):zoom(0.42):halign(0):diffuse(COLOR.TextSub1)
			self:maxwidth((frameWidth - 30) / 0.42)
			self:settext(translated_info["ExplainSuperSearch"])
		end
	}
}

return t
