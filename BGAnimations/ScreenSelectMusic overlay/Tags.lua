local hoverAlpha = 0.6

local onTab = false
local song
local steps
local curInput = ""
local frameWidth = capWideScale(360, 400)
local frameX = SCREEN_WIDTH - frameWidth - 10
local frameY = 95
local frameHeight = SCREEN_HEIGHT - 135
local fontScale = 0.4
local tagsperpage = 14
local offsetX = 10
local offsetY = 24
local tagFunction = 1
local buttondiffuse = 0
local buttonheight = 10
local currenttagpage = 1
local numtagpages = 1
local tagYSpacing = 24
local whee
local filterChanged = false
local ptags = tags:get_data().playerTags
local playertags = {}
local displayindex = {}
local charts = {}
local oCharts = {}

local translated_info = {
	AddTag = THEME:GetString("TabTags", "AddTag"),
	ExcludeMode = THEME:GetString("TabTags", "ExcludeMode"),
	Mode = THEME:GetString("TabTags", "Mode"),
	AND = THEME:GetString("TabTags", "AND"),
	OR = THEME:GetString("TabTags", "OR"),
	Next = THEME:GetString("TabTags", "Next"),
	Previous = THEME:GetString("TabTags", "Previous"),
	Showing = THEME:GetString("TabTags", "Showing"),
	Title = THEME:GetString("TabTags", "Title"),
	HowToDelete = THEME:GetString("TabTags", "HowToDelete"),
}

local function newTagInput(event)
	changed = false
	if event.type ~= "InputEventType_Release" and onTab and hasFocus then
		if event.button == "Start" then
			hasFocus = false
			if curInput ~= "" and ptags[curInput] == nil then
				tags:get_data().playerTags[curInput] = {}
				tags:set_dirty()
				tags:save()
			end
			curInput = ""
			SCREENMAN:set_input_redirected(PLAYER_1, false)
			MESSAGEMAN:Broadcast("RefreshTags")
			MESSAGEMAN:Broadcast("NumericInputEnded")
			return true
		elseif event.button == "Back" then
			curInput = ""
			hasFocus = false
			SCREENMAN:set_input_redirected(PLAYER_1, false)
			MESSAGEMAN:Broadcast("RefreshTags")
			MESSAGEMAN:Broadcast("NumericInputEnded")
			return true
		elseif event.DeviceInput.button == "DeviceButton_backspace" then
			changed = true
			curInput = curInput:sub(1, -2)
		elseif event.DeviceInput.button == "DeviceButton_delete" then
			changed = true
			curInput = ""
		elseif
			event.char and curInput:len() < 20 and
				event.char:match('[% %%%+%-%!%@%#%$%^%&%*%(%)%=%_%.%,%:%;%\'%"%>%<%?%/%~%|%w]') and
				event.char ~= ""
		 then
			changed = true
			curInput = curInput .. event.char
		end
		if changed then
			MESSAGEMAN:Broadcast("RefreshTags")
		end
	end
end

local t = Def.ActorFrame {
	Name = "Tongo",
	BeginCommand = function(self)
		SCREENMAN:GetTopScreen():AddInputCallback(newTagInput)
		self:queuecommand("BORPBORPNORFNORFc"):visible(false)
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
	MouseRightClickMessageCommand = function(self)
		if onTab then
			hasFocus = false
			curInput = ""
			SCREENMAN:set_input_redirected(PLAYER_1, false)
			MESSAGEMAN:Broadcast("NumericInputEnded")
			MESSAGEMAN:Broadcast("RefreshTags")
		end
	end,
	BORPBORPNORFNORFcCommand = function(self)
		self:finishtweening()
		if getTabIndex() == 9 then
			self:queuecommand("On")
			self:visible(true)
			song = GAMESTATE:GetCurrentSong()
			steps = GAMESTATE:GetCurrentSteps()
			onTab = true
			MESSAGEMAN:Broadcast("RefreshTags")
		else
			self:queuecommand("Off")
			onTab = false
		end
	end,
	TabChangedMessageCommand = function(self)
		self:playcommand("BORPBORPNORFNORFc")
	end,
	CurrentStepsChangedMessageCommand = function(self)
		if getTabIndex() == 9 then
			self:playcommand("BORPBORPNORFNORFc"):finishtweening()
		end
	end,
}

-- Salmon offset backdrop shadow
t[#t + 1] = Def.Quad {
	InitCommand = function(self)
		self:xy(5, 5):zoomto(frameWidth, frameHeight):halign(0):valign(0):diffuse(COLOR.MainHighlight)
	end
}
-- White card background
t[#t + 1] = Def.Quad {
	InitCommand = function(self)
		self:xy(0, 0):zoomto(frameWidth, frameHeight):halign(0):valign(0):diffuse(COLOR.MainBackground)
	end
}
-- Border outline
t[#t + 1] = UIElements.Border(frameWidth, frameHeight, 1) .. {
	InitCommand = function(self)
		self:xy(frameWidth / 2, frameHeight / 2):diffuse(COLOR.MainBorder)
	end
}
-- Header quad
t[#t + 1] = Def.Quad {
	InitCommand = function(self)
		self:xy(0, 0):zoomto(frameWidth, offsetY):halign(0):valign(0):diffuse(COLOR.MainHighlight)
	end
}
-- Header title
t[#t + 1] = LoadFont("Common Normal") .. {
	InitCommand = function(self)
		self:xy(10, offsetY / 2):zoom(0.55):halign(0):valign(0.5):diffuse(COLOR.TextMain)
		self:settext(translated_info["Title"])
	end
}

local function filterDisplay(playertags)
	local index = {}
	for i = 1, #playertags do
		index[#index + 1] = i
	end
	return index
end

local r = Def.ActorFrame {
	BeginCommand = function(self)
		whee = SCREENMAN:GetTopScreen():GetMusicWheel()
		if filterTags == nil then
			filterTags = {}
		end

		if filterAgainstTags == nil then
			filterAgainstTags = {}
		end
		self:queuecommand("RefreshTags")
	end,
	RefreshTagsMessageCommand = function(self)
		playertags = {}
		ptags = tags:get_data().playerTags

		for k, v in pairs(ptags) do
			playertags[#playertags + 1] = k
		end
		table.sort(playertags)
		displayindex = filterDisplay(playertags)
		numtagpages = notShit.ceil(#displayindex / tagsperpage)
		MESSAGEMAN:Broadcast("UpdateTags")
	end
}

local function makeTag(i)
	local t = Def.ActorFrame {
		InitCommand = function(self)
			local colPos = i > 7 and (frameWidth / 2 + 10) or 10
			local row = i > 7 and (i - 8) or (i - 1)
			self:xy(colPos, offsetY + 35 + row * tagYSpacing)
			self:visible(true)
		end,
		UpdateTagsMessageCommand = function(self)
			if playertags[i + ((currenttagpage - 1) * tagsperpage)] then
				self:visible(true)
			else
				self:visible(false)
			end
		end,
		Def.ActorFrame {
			InitCommand = function(self)
				self:x(0)
			end,
			UIElements.QuadButton(1, 1) .. {
				InitCommand = function(self)
					self:xy(0, 0):zoomto(frameWidth / 2 - 20, tagYSpacing - 4):halign(0):valign(0)
				end,
				UpdateTagsMessageCommand = function(self)
					curTag = playertags[i + ((currenttagpage - 1) * tagsperpage)]
					if tagFunction == 1 then
						if song and curTag and ptags[curTag] and steps and ptags[curTag][steps:GetChartKey()] then
							self:diffuse(COLOR.MainHighlight)
						else
							self:diffuse(color("#E5E5E5"))
						end
					elseif tagFunction == 2 then
						if filterTags[curTag] then
							self:diffuse(COLOR.MainHighlight)
						elseif filterAgainstTags[curTag] then
							self:diffuse(color("#FF6666"))
						else
							self:diffuse(color("#E5E5E5"))
						end
					else
						self:diffuse(color("#E5E5E5"))
					end
				end,
				MouseDownCommand = function(self, params)
					if steps == nil or song == nil then return end
					if params.event == "DeviceButton_left mouse button" then
						curTag = playertags[i + ((currenttagpage - 1) * tagsperpage)]
						if tagFunction == 1 then
							ck = steps:GetChartKey()
							if ptags[curTag][ck] then
								tags:get_data().playerTags[curTag][ck] = nil
							else
								tags:get_data().playerTags[curTag][ck] = 1
							end
							tags:set_dirty()
							tags:save()
						elseif tagFunction == 2 then
							if filterAgainstTags[curTag] then
								filterAgainstTags[curTag] = nil
							end

							if filterTags[curTag] then
								filterTags[curTag] = nil
							else
								filterTags[curTag] = 1
							end
						else
							if filterTags[curTag] then
								filterTags[curTag] = nil
							end
							tags:get_data().playerTags[curTag] = nil
							tags:set_dirty()
							tags:save()
						end
						filterChanged = true
						MESSAGEMAN:Broadcast("RefreshTags")
					elseif params.event == "DeviceButton_right mouse button" then
						if steps == nil or song == nil then return end
						curTag = playertags[i + ((currenttagpage - 1) * tagsperpage)]
						if tagFunction == 2 then
							if filterTags[curTag] then
								filterTags[curTag] = nil
							end

							if filterAgainstTags[curTag] then
								filterAgainstTags[curTag] = nil
							else
								filterAgainstTags[curTag] = 1
							end
							filterChanged = true
						end
						MESSAGEMAN:Broadcast("RefreshTags")
					end
				end,
				MouseOverCommand = function(self)
					self:GetParent():diffusealpha(hoverAlpha)
				end,
				MouseOutCommand = function(self)
					self:GetParent():diffusealpha(1)
				end,
			},
			LoadFont("Common Normal") .. {
				Name = "Text",
				InitCommand = function(self)
					self:xy(5, (tagYSpacing - 4) / 2):halign(0):valign(0.5):maxwidth((frameWidth / 2 - 30) / fontScale):diffuse(COLOR.TextMain)
				end,
				UpdateTagsMessageCommand = function(self)
					self:zoom(fontScale)
					if playertags[i + ((currenttagpage - 1) * tagsperpage)] then
						self:settext(playertags[i + ((currenttagpage - 1) * tagsperpage)])
					end
				end
			}
		}
	}
	return t
end

local fawa = {
	THEME:GetString("TabTags", "TagList"),
	THEME:GetString("TabTags", "TagFilter"),
	THEME:GetString("TabTags", "TagDelete")
}
local function funcButton(i)
	local btnWidth = (frameWidth - 30) / 3
	local t = Def.ActorFrame {
		InitCommand = function(self)
			local colPos = 10 + (i - 1) * (btnWidth + 5)
			self:xy(colPos, offsetY + 6)
			self:visible(true)
		end,
		UIElements.QuadButton(1, 1) .. {
			InitCommand = function(self)
				self:zoomto(btnWidth, 22):halign(0):valign(0):diffuse(color("#DDDDDD"))
			end,
			BORPBORPNORFNORFcCommand = function(self)
				if tagFunction == i then
					self:diffuse(COLOR.MainHighlight)
				else
					self:diffuse(color("#DDDDDD"))
				end
			end,
			MouseDownCommand = function(self, params)
				if params.event == "DeviceButton_left mouse button" then
					tagFunction = i
					MESSAGEMAN:Broadcast("RefreshTags")
				end
			end,
			UpdateTagsMessageCommand = function(self)
				self:queuecommand("BORPBORPNORFNORFc")
			end,
			MouseOverCommand = function(self)
				self:diffusealpha(0.6)
			end,
			MouseOutCommand = function(self)
				self:diffusealpha(1)
			end,
		},
		LoadFont("Common Normal") .. {
			InitCommand = function(self)
				self:xy(btnWidth / 2, 11):halign(0.5):valign(0.5):diffuse(COLOR.TextMain):maxwidth(btnWidth - 10):zoom(0.35)
			end,
			BeginCommand = function(self)
				self:settext(fawa[i])
			end,
		}
	}
	return t
end

-- new tag input
r[#r + 1] = Def.ActorFrame {
	InitCommand = function(self)
		self:xy(10, frameHeight - 65)
	end,
	BORPBORPNORFNORFcCommand = function(self)
		self:visible(tagFunction == 1)
	end,
	UpdateTagsMessageCommand = function(self)
		self:queuecommand("BORPBORPNORFNORFc")
	end,
	LoadFont("Common Normal") .. {
		InitCommand = function(self)
			self:halign(0):zoom(fontScale):diffuse(COLOR.TextMain)
		end,
		BORPBORPNORFNORFcCommand = function(self)
			self:settextf("%s:", translated_info["AddTag"])
		end
	},
	UIElements.QuadButton(1, 1) .. {
		InitCommand = function(self)
			self:addx(80):addy(0):zoomto(capWideScale(210,240), 20):halign(0):valign(0):diffuse(color("#E5E5E5"))
		end,
		MouseDownCommand = function(self, params)
			if params.event == "DeviceButton_left mouse button" and onTab then
				hasFocus = true
				curInput = ""
				SCREENMAN:set_input_redirected(PLAYER_1, true)
				self:diffusealpha(0.1)
				MESSAGEMAN:Broadcast("RefreshTags")
				MESSAGEMAN:Broadcast("NumericInputActive")
			end
		end,
		BORPBORPNORFNORFcCommand = function(self)
			if hasFocus then
				self:diffuse(COLOR.MainHighlight)
			else
				self:diffuse(color("#E5E5E5"))
			end
		end,
		UpdateTagsMessageCommand = function(self)
			self:queuecommand("BORPBORPNORFNORFc")
		end
	},
	LoadFont("Common Normal") .. {
		InitCommand = function(self)
			self:addx(85):addy(10):halign(0):valign(0.5):maxwidth(400):zoom(fontScale - 0.05):diffuse(COLOR.TextMain)
		end,
		BORPBORPNORFNORFcCommand = function(self)
			self:settext(curInput)
			if curInput ~= "" or hasFocus then
				self:diffuse(COLOR.TextMain)
			else
				self:diffuse(COLOR.TextSub2)
			end
		end,
		UpdateTagsMessageCommand = function(self)
			self:queuecommand("BORPBORPNORFNORFc")
		end
	}
}

-- filter type
r[#r + 1] = Def.ActorFrame {
	InitCommand = function(self)
		self:xy(10, frameHeight - 65)
	end,
	BORPBORPNORFNORFcCommand = function(self)
		self:visible(tagFunction == 2)
	end,
	UpdateTagsMessageCommand = function(self)
		self:queuecommand("BORPBORPNORFNORFc")
	end,
	UIElements.TextToolTip(1, 1, "Common Normal") .. {
		InitCommand = function(self)
			self:zoom(fontScale):halign(0):diffuse(COLOR.TextMain)
		end,
		BORPBORPNORFNORFcCommand = function(self)
			self:settextf("%s: %s", translated_info["Mode"], (filterMode and translated_info["AND"] or translated_info["OR"])):maxwidth(((frameWidth - 40) / 2) / fontScale)
		end,
		UpdateTagsMessageCommand = function(self)
			self:queuecommand("BORPBORPNORFNORFc")
		end,
	},
	UIElements.QuadButton(1, 1) .. {
		InitCommand = function(self)
			self:zoomto((frameWidth - 40) / 2, 18):halign(0):diffusealpha(0)
		end,
		MouseDownCommand = function(self, params)
			if params.event == "DeviceButton_left mouse button" and onTab then
				filterMode = not filterMode
				filterChanged = true
				MESSAGEMAN:Broadcast("RefreshTags")
			end
		end,
		MouseOverCommand = function(self)
			self:GetParent():diffusealpha(hoverAlpha)
		end,
		MouseOutCommand = function(self)
			self:GetParent():diffusealpha(1)
		end,
	}
}

-- filter against type
r[#r + 1] = Def.ActorFrame {
	InitCommand = function(self)
		self:xy(frameWidth / 2 + 10, frameHeight - 65)
	end,
	BORPBORPNORFNORFcCommand = function(self)
		self:visible(tagFunction == 2)
	end,
	UpdateTagsMessageCommand = function(self)
		self:queuecommand("BORPBORPNORFNORFc")
	end,
	UIElements.TextToolTip(1, 1, "Common Normal") .. {
		InitCommand = function(self)
			self:zoom(fontScale):halign(0):diffuse(COLOR.TextMain)
		end,
		BORPBORPNORFNORFcCommand = function(self)
			self:settextf("%s: %s", translated_info["ExcludeMode"], (filterAgainstMode and translated_info["AND"] or translated_info["OR"])):maxwidth(((frameWidth - 40) / 2) / fontScale)
		end,
		UpdateTagsMessageCommand = function(self)
			self:queuecommand("BORPBORPNORFNORFc")
		end,
	},
	UIElements.QuadButton(1, 1) .. {
		InitCommand = function(self)
			self:zoomto(((frameWidth - 40) / 2), 18):halign(0):diffusealpha(0)
		end,
		MouseDownCommand = function(self, params)
			if params.event == "DeviceButton_left mouse button" and onTab then
				filterAgainstMode = not filterAgainstMode
				filterChanged = true
				MESSAGEMAN:Broadcast("RefreshTags")
			end
		end,
		MouseOverCommand = function(self)
			self:GetParent():diffusealpha(hoverAlpha)
		end,
		MouseOutCommand = function(self)
			self:GetParent():diffusealpha(1)
		end,
	}
}

r[#r+1] = LoadFont("Common Normal") .. {
	InitCommand = function(self)
		self:xy(frameWidth / 2, frameHeight - 65)
		self:zoom(0.35):halign(0.5):diffuse(COLOR.TextSub1)
		self:settextf("%s", translated_info["HowToDelete"])
		self:visible(false)
	end,
	UpdateTagsMessageCommand = function(self)
		self:queuecommand("BORPBORPNORFNORFc")
	end,
	RefreshTagsMessageCommand = function(self)
		self:queuecommand("BORPBORPNORFNORFc")
	end,
	BORPBORPNORFNORFcCommand = function(self)
		self:visible(tagFunction == 3)
	end,
}

-- Paginator & Page info
r[#r + 1] = Def.ActorFrame {
	InitCommand = function(self)
		self:xy(10, frameHeight - 30)
	end,
	UIElements.TextToolTip(1, 1, "Common Normal") .. {
		InitCommand = function(self)
			self:halign(0):zoom(0.35):diffuse(COLOR.TextMain):settext(translated_info["Previous"])
		end,
		MouseDownCommand = function(self, params)
			if params.event == "DeviceButton_left mouse button" and currenttagpage > 1 then
				currenttagpage = currenttagpage - 1
				MESSAGEMAN:Broadcast("RefreshTags")
			end
		end
	},
	UIElements.TextToolTip(1, 1, "Common Normal") .. {
		InitCommand = function(self)
			self:x(frameWidth - 60):halign(0):zoom(0.35):diffuse(COLOR.TextMain):settext(translated_info["Next"])
		end,
		MouseDownCommand = function(self, params)
			if params.event == "DeviceButton_left mouse button" and currenttagpage < numtagpages then
				currenttagpage = currenttagpage + 1
				MESSAGEMAN:Broadcast("RefreshTags")
			end
		end
	},
	LoadFont("Common Normal") .. {
		InitCommand = function(self)
			self:x((frameWidth - 20) / 2):halign(0.5):zoom(0.35):diffuse(COLOR.TextMain)
		end,
		BORPBORPNORFNORFcCommand = function(self)
			self:settextf(
				"%s %i-%i (%i)",
				translated_info["Showing"],
				math.min(((currenttagpage - 1) * tagsperpage) + 1, #displayindex),
				math.min(currenttagpage * tagsperpage, #displayindex),
				#displayindex
			)
		end,
		UpdateTagsMessageCommand = function(self)
			self:queuecommand("BORPBORPNORFNORFc")
		end
	}
}

for i = 1, tagsperpage do
	r[#r + 1] = makeTag(i)
end

for i = 1, 3 do
	r[#r + 1] = funcButton(i)
end

t[#t + 1] = r

return t
