local function diffuseIfActiveButton(self, cond)
	if cond then
		self:diffuse(COLOR.MainHighlight)
	else
		self:diffuse(color("#F4EAF2"))
	end
end

-- Older Willow Heart installations do not include Til Death's TextButton
-- helper. Keep the imported screen self-contained using the same BG/Text
-- child contract expected below.
if not UIElements.TextButton then
	UIElements.TextButton = function(z, depth, font)
			local button = Def.ActorFrame {
				UIElements.QuadButton(z, depth) .. {
					Name = "MouseButton",
					InitCommand = function(self)
						self:zoomto(320, 64):diffusealpha(0)
					end,
					OnCommand = function(self)
						local bg = self:GetParent():GetChild("BG")
						if bg then
							self:halign(bg:GetHAlign()):valign(bg:GetVAlign())
							self:zoomto(bg:GetZoomedWidth(), bg:GetZoomedHeight())
						end
					end,
					MouseOverCommand = function(self)
						self:GetParent():playcommand("RolloverUpdate", {update = "over"})
					end,
					MouseOutCommand = function(self)
						self:GetParent():playcommand("RolloverUpdate", {update = "out"})
					end,
					MouseDownCommand = function(self, params)
						self:GetParent():playcommand("Click", {
							update = "OnMouseDown",
							event = params and params.event,
						})
					end,
					MouseUpCommand = function(self, params)
						self:GetParent():playcommand("Click", {
							update = "OnMouseUp",
							event = params and params.event,
						})
					end,
					MouseClickCommand = function(self, params)
						self:GetParent():playcommand("Click", {
							update = "OnMouseClicked",
							event = params and params.event,
						})
					end,
				}
			}
			button[#button + 1] = Def.Quad { Name = "BG" }
			button[#button + 1] = LoadFont(font or "Common Normal") .. { Name = "Text" }
			return button
	end
end
if not UIElements.TextToolTip then
	UIElements.TextToolTip = function(z, depth, font)
		return LoadFont(font or "Common Normal") .. {
			InitCommand = function(self) 
				if z then self:z(z) end
			end,
			OnCommand = function(self)
				local screen = SCREENMAN:GetTopScreen()
				if screen ~= nil then
					BUTTON:AddButton(self, screen:GetName(), depth or 0)
				end
			end,
		}
	end
end

local function diffuseIfActiveText(self, cond)
	if cond then
		self:diffuse(COLOR.TextMain)
	else
		self:diffuse(COLOR.TextSub1)
	end
end

local activealpha = 0.9
local inactivealpha = 0.5
local highlightalpha = 1.0

local translated_info = {
	CancelCurrent = THEME:GetString("ScreenPackDownloader", "CancelCurrentDownload"),
	CancelAll = THEME:GetString("ScreenPackDownloader", "CancelAllDownloads"),
	SearchName = THEME:GetString("ScreenPackDownloader", "SearchingName"),
	SizeExplanation = THEME:GetString("ScreenPackDownloader", "ExplainSizeLimit")
}

local width = SCREEN_WIDTH / 3
local fontScale = 0.5
local packh = 28
local packgap = 4
local packspacing = packh + packgap
local offx = 10
local offy = 40

local fx = SCREEN_WIDTH / 4.5
local f0y = 160
local f1y = f0y + 40
local f2y = f1y + 40
local fdot = 24

local tagFrameWidth = SCREEN_WIDTH / 3
local cancelButtonSpace = 4
local leftSpace = 10
local cancelFrameY = 66

local selectedTags = {}
local tagsMatchAny = true
local nameInput = ""

local o = Def.ActorFrame {
	Name = "MainFrame",
	InitCommand = function(self)
		self:xy(0, 0):halign(0.5):valign(0)
		self:GetChild("PacklistDisplay"):xy(SCREEN_WIDTH / 2.5 - offx, offy * 2 + 14)
	end,
	WheelUpSlowMessageCommand = function(self)
		self:queuecommand("PrevPage")
	end,
	WheelDownSlowMessageCommand = function(self)
		self:queuecommand("NextPage")
	end,
	UpdateFilterDisplaysMessageCommand = function(self)
		self:queuecommand("Set")
	end,
	FilterChangedMessageCommand = function(self)
		self:queuecommand("PackTableRefresh")
	end,
	MouseRightClickMessageCommand = function(self)
		SCREENMAN:GetTopScreen():Cancel()
	end,
}

-- Screen Background Quad using COLOR.MainBackground
o[#o+1] = Def.Quad {
	Name = "ScreenBG",
	InitCommand = function(self)
		self:FullScreen()
		self:diffuse(COLOR.MainBackground)
	end
}

o[#o+1] = Def.ActorFrame {
	Name = "LeftButtonFrame",
	InitCommand = function(self)
		self:xy(leftSpace + tagFrameWidth/2, cancelFrameY)
	end,

	UIElements.TextButton(1, 1, "DFPGothic 64px") .. {
		Name = "StopAllDownloadsButton",
		InitCommand = function(self)
			self.txt = self:GetChild("Text")
			self.bg = self:GetChild("BG")

			self:xy(-tagFrameWidth/2, 0)

			self.txt:xy(tagFrameWidth/4 - leftSpace/4, packh/2)
			self.txt:valign(0.5)
			self.txt:settext(translated_info["CancelAll"])
			self.txt:zoom(0.26)
			self.txt:diffuse(COLOR.TextMain)
			self.txt:maxwidth((tagFrameWidth/2 - leftSpace) / 0.26)

			self.bg:zoomto(tagFrameWidth/2 - leftSpace/2, packh)
			self.bg:halign(0):valign(0)
			self.bg:diffuse(color("#F4EAF2"))

			self.alphaDeterminingFunction = function(self)
				if isOver(self.bg) then
					self.bg:diffuse(COLOR.MainHighlight)
					self.bg:diffusealpha(0.85)
				else
					self.bg:diffuse(color("#F4EAF2"))
					self.bg:diffusealpha(0.9)
				end
			end
			self:alphaDeterminingFunction()
		end,
		RolloverUpdateCommand = function(self, params)
			self:alphaDeterminingFunction()
		end,
		ClickCommand = function(self, params)
			if params.update == "OnMouseDown" then
				local count = 0
				for _, p in ipairs(DLMAN:GetQueuedPacks()) do
					local s = p:RemoveFromQueue()
					if s then count = count + 1 end
				end
				for _, p in ipairs(DLMAN:GetDownloadingPacks()) do
					p:GetDownload():Stop()
					count = count + 1
				end
				if count > 0 then
					ms.ok("Stopped All Downloads: "..count.." Downloads")
				end
			end
		end,
	},
	UIElements.TextButton(1, 1, "DFPGothic 64px") .. {
		Name = "StopCurrentDownloadButton",
		InitCommand = function(self)
			self.txt = self:GetChild("Text")
			self.bg = self:GetChild("BG")

			self:xy(leftSpace/2, 0)

			self.txt:xy(tagFrameWidth/4 - leftSpace/4, packh/2)
			self.txt:valign(0.5)
			self.txt:settext(translated_info["CancelCurrent"])
			self.txt:zoom(0.26)
			self.txt:diffuse(COLOR.TextMain)
			self.txt:maxwidth((tagFrameWidth/2 - leftSpace) / 0.26)

			self.bg:zoomto(tagFrameWidth/2 - leftSpace/2, packh)
			self.bg:halign(0):valign(0)
			self.bg:diffuse(color("#F4EAF2"))

			self.alphaDeterminingFunction = function(self)
				if isOver(self.bg) then
					self.bg:diffuse(COLOR.MainHighlight)
					self.bg:diffusealpha(0.85)
				else
					self.bg:diffuse(color("#F4EAF2"))
					self.bg:diffusealpha(0.9)
				end
			end
			self:alphaDeterminingFunction()
		end,
		RolloverUpdateCommand = function(self, params)
			self:alphaDeterminingFunction()
		end,
		ClickCommand = function(self, params)
			if params.update == "OnMouseDown" then
				local dl = DLMAN:GetDownloads()[1]
				if dl then
					dl:Stop()
				end
			end
		end,
	},
}

local function unbundleize(bundlestr)
	local bundleWord = "Bundle: "
	if bundlestr:find(bundleWord) ~= nil then
		bundlestr = bundlestr:sub(#bundleWord+1):lower()
	end
	return bundlestr
end

local function tagframe()
	local maxtags = 12
	local curpage = 1

	local frameBGHeight = SCREEN_HEIGHT - (f0y-30) - leftSpace
	local frameBGWidth = SCREEN_WIDTH / 3
	local tagSpacing = 2
	local tagHeight = ((frameBGHeight * 0.7) / maxtags)
	local tagWidth = frameBGWidth - tagSpacing*2
	local tagTextSize = 0.45
	local tagListStartY = frameBGHeight * 0.22

	local orderedTags = {}
	local function loadTags()
		local alltags = DLMAN:GetPackTags()
		local skillsetTags = table.sorted(alltags["global_skillset"] or {})
		local keycountTags = table.sorted(alltags["global_keyCount"] or {}, function(a,b)
			local ax = a:sub(1, #a-1)
			local bx = b:sub(1, #b-1)
			return tonumber(ax) < tonumber(bx)
		end)
		local otherTags = table.sorted(alltags["pack_tag"] or {})
		local bundleTags = table.withfuncapplied(alltags["pack_bundle"] or {}, function(key,val)
			return key, "Bundle: " .. val:sub(1,1):upper() .. val:sub(2)
		end)
		orderedTags = table.combine(keycountTags, skillsetTags, otherTags, bundleTags)
	end
	loadTags()

	local function movePage(n)
		local newpage = curpage + n
		local maxpage = math.max(1, math.ceil(#orderedTags / maxtags))
		if newpage < 1 then
			newpage = maxpage
		elseif newpage > maxpage then
			newpage = 1
		end
		curpage = newpage
		MESSAGEMAN:Broadcast("SetTagPage")
	end

	local t = Def.ActorFrame {
		Name = "TagFrame",
		InitCommand = function(self)
			self:xy(leftSpace, f0y - 30)
		end,
		BeginCommand = function(self)
			SCREENMAN:GetTopScreen():AddInputCallback(function(event)
				if isOver(self:GetChild("BG")) then
					if event.type == "InputEventType_FirstPress" then
						if event.DeviceInput.button == "DeviceButton_mousewheel up" then
							movePage(-1)
						elseif event.DeviceInput.button == "DeviceButton_mousewheel down" then
							movePage(1)
						end
					end
				end
			end)
			self:playcommand("UpdateTags")
		end,
		SetTagPageMessageCommand = function(self)
			self:playcommand("UpdateTags")
		end,
		PackTagsRefreshedMessageCommand = function(self)
			loadTags()
			self:playcommand("UpdateTags")
		end,

		-- Base Tag Frame Background Card
		Def.Quad {
			Name = "BG",
			InitCommand = function(self)
				self:halign(0):valign(0)
				self:zoomto(frameBGWidth, frameBGHeight)
				self:diffuse(color("#FAF7F9"))
				self:diffusealpha(0.95)
			end
		},
		-- Header Accent Strip for Tag Panel
		Def.Quad {
			Name = "TagHeaderAccent",
			InitCommand = function(self)
				self:halign(0):valign(0)
				self:zoomto(frameBGWidth, 4)
				self:diffuse(COLOR.MainHighlight)
			end
		},
		LoadFont("Common Large") .. {
			Name = "TagExplain",
			InitCommand = function(self)
				self:settext("TAG FILTERS")
				self:zoom(0.38)
				self:valign(0):halign(0)
				self:xy(leftSpace, leftSpace)
				self:diffuse(COLOR.TextMain)
			end,
		},
		LoadFont("Common Normal") .. {
			Name = "PageNum",
			InitCommand = function(self)
				self:zoom(0.55)
				self:valign(0):halign(1)
				self:xy(frameBGWidth - leftSpace, leftSpace + 2)
				self:diffuse(COLOR.TextSub1)
			end,
			UpdateTagsCommand = function(self)
				local total = #orderedTags
				if total == 0 then
					self:settext("0-0 of 0")
				else
					self:settextf("%d-%d of %d", (curpage-1) * maxtags + 1, math.min(total, curpage * maxtags), total)
				end
			end,
		},
		UIElements.TextButton(1, 1, "Common Large") .. {
			Name = "ApplyButton",
			InitCommand = function(self)
				self.bg = self:GetChild("BG")
				self.txt = self:GetChild("Text")
				self:xy(tagSpacing, tagListStartY - tagSpacing - packh*0.85)

				self.txt:xy(tagFrameWidth/6 - leftSpace/4, (packh*0.85)/2)
				self.txt:settext("Apply")
				self.txt:zoom(0.36)
				self.txt:diffuse(COLOR.TextMain)
				self.txt:maxwidth((tagFrameWidth/3 - leftSpace) / 0.36)
				self.bg:zoomto(tagFrameWidth/3 - leftSpace/2, packh*0.85)
				self.bg:halign(0):valign(0)

				self.alphaDeterminingFunction = function(self)
					if isOver(self.bg) then
						self.bg:diffuse(COLOR.MainHighlight)
						self.bg:diffusealpha(0.9)
					else
						self.bg:diffuse(color("#F4EAF2"))
						self.bg:diffusealpha(0.9)
					end
				end
				self:alphaDeterminingFunction()
			end,
			RolloverUpdateCommand = function(self, params)
				self:alphaDeterminingFunction()
			end,
			ClickCommand = function(self, params)
				if params.update ~= "OnMouseDown" then return end
				local tags = {}
				for k,v in pairs(selectedTags) do
					if v == true then
						tags[#tags+1] = unbundleize(k)
					end
				end
				MESSAGEMAN:Broadcast("InvokePackSearch", {name=nameInput, tags=tags, tagsMatchAny=tagsMatchAny})
			end,
		},
		UIElements.TextButton(1, 1, "Common Large") .. {
			Name = "ResetButton",
			InitCommand = function(self)
				self.bg = self:GetChild("BG")
				self.txt = self:GetChild("Text")
				self:xy(tagFrameWidth/3 - leftSpace/4 + tagSpacing, tagListStartY - tagSpacing - packh*0.85)

				self.txt:xy(tagFrameWidth/6 - leftSpace/4, (packh*0.85)/2)
				self.txt:settext("Reset")
				self.txt:zoom(0.36)
				self.txt:diffuse(COLOR.TextMain)
				self.txt:maxwidth((tagFrameWidth/3 - leftSpace) / 0.36)
				self.bg:zoomto(tagFrameWidth/3 - leftSpace/2, packh*0.85)
				self.bg:halign(0):valign(0)

				self.alphaDeterminingFunction = function(self)
					if isOver(self.bg) then
						self.bg:diffuse(COLOR.MainHighlight)
						self.bg:diffusealpha(0.9)
					else
						self.bg:diffuse(color("#F4EAF2"))
						self.bg:diffusealpha(0.9)
					end
				end
				self:alphaDeterminingFunction()
			end,
			RolloverUpdateCommand = function(self, params)
				self:alphaDeterminingFunction()
			end,
			ClickCommand = function(self, params)
				if params.update ~= "OnMouseDown" then return end
				selectedTags = {}
				self:GetParent():playcommand("UpdateTags")
				MESSAGEMAN:Broadcast("InvokePackSearch", {name=nameInput, tags={}, tagsMatchAny=tagsMatchAny})
			end,
		},
		UIElements.TextButton(1, 1, "Common Large") .. {
			Name = "ANDORButton",
			InitCommand = function(self)
				self.bg = self:GetChild("BG")
				self.txt = self:GetChild("Text")
				self:xy(tagFrameWidth/3 + tagFrameWidth/3 - leftSpace/3.3, tagListStartY - tagSpacing - packh*0.85)

				self.txt:xy(tagFrameWidth/6 - leftSpace/4, (packh*0.85)/2)
				self.txt:settext(tagsMatchAny and "OR" or "AND")
				self.txt:zoom(0.36)
				self.txt:diffuse(COLOR.TextMain)
				self.txt:maxwidth((tagFrameWidth/3 - leftSpace) / 0.36)
				self.bg:zoomto(tagFrameWidth/3 - leftSpace/2, packh*0.85)
				self.bg:halign(0):valign(0)

				self.alphaDeterminingFunction = function(self)
					if isOver(self.bg) then
						self.bg:diffuse(COLOR.MainHighlight)
						self.bg:diffusealpha(0.9)
					else
						self.bg:diffuse(color("#F4EAF2"))
						self.bg:diffusealpha(0.9)
					end
				end
				self:alphaDeterminingFunction()
			end,
			RolloverUpdateCommand = function(self, params)
				self:alphaDeterminingFunction()
			end,
			ClickCommand = function(self, params)
				if params.update ~= "OnMouseDown" then return end
				tagsMatchAny = not tagsMatchAny
				self.txt:settext(tagsMatchAny and "OR" or "AND")
				local tags = {}
				for k,v in pairs(selectedTags) do
					if v == true then
						tags[#tags+1] = unbundleize(k)
					end
				end
				MESSAGEMAN:Broadcast("InvokePackSearch", {name=nameInput, tags=tags, tagsMatchAny=tagsMatchAny})
			end,
		},
	}

	local function tagentry(i)
		local tagtxt = nil
		return UIElements.TextButton(1, 1, "Common Normal") .. {
			Name = "Tag"..i,
			InitCommand = function(self)
				self.bg = self:GetChild("BG")
				self.txt = self:GetChild("Text")

				self:xy(
					tagFrameWidth/2,
					tagListStartY + tagHeight/2 + tagSpacing + (i-1) * (tagHeight + tagSpacing)
				)

				self.bg:zoomto(tagWidth, tagHeight)
				self.txt:zoom(tagTextSize)

				self.alphaDeterminingFunction = function(self)
					local isSelected = selectedTags[tagtxt] == true
					if isSelected then
						self.bg:diffuse(COLOR.MainHighlight)
						self.txt:diffuse(COLOR.TextMain)
						if isOver(self.bg) then
							self.bg:diffusealpha(1.0)
						else
							self.bg:diffusealpha(0.85)
						end
					else
						self.bg:diffuse(color("#EFE6EC"))
						self.txt:diffuse(COLOR.TextSub1)
						if isOver(self.bg) then
							self.bg:diffuse(COLOR.MainHighlight)
							self.bg:diffusealpha(0.5)
							self.txt:diffuse(COLOR.TextMain)
						else
							self.bg:diffusealpha(0.8)
						end
					end
				end
				self:alphaDeterminingFunction()
			end,
			UpdateTagsCommand = function(self)
				tagtxt = orderedTags[i + ((curpage-1) * maxtags)]

				if tagtxt then
					self:visible(true)
					self.txt:settextf("%s", tagtxt)
				else
					self:visible(false)
				end
				self:alphaDeterminingFunction()
			end,
			RolloverUpdateCommand = function(self, params)
				self:alphaDeterminingFunction()
			end,
			ClickCommand = function(self, params)
				if params.update ~= "OnMouseDown" then return end
				if selectedTags[tagtxt] == true then
					selectedTags[tagtxt] = nil
				else
					selectedTags[tagtxt] = true
				end
				self:alphaDeterminingFunction()
			end,
		}
	end

	for i=1,maxtags do
		t[#t+1] = tagentry(i)
	end

	return t
end
o[#o+1] = tagframe()

local nwidth = SCREEN_WIDTH / 2
local namex = nwidth
local namey = 38
local nhite = 26
local nameoffx = 12
local inputting = 0

-- name string search
o[#o + 1] = Def.ActorFrame {
	Name = "TextEntryFrame",
	InitCommand = function(self)
		self:xy(namex, namey):halign(0):valign(0)
	end,
	BeginCommand = function(self)
		SCREENMAN:GetTopScreen():AddInputCallback(function(event)
			if event.type ~= "InputEventType_Release" then
				local btn = event.DeviceInput.button
				local shift = INPUTFILTER:IsShiftPressed()
				local ctrl = INPUTFILTER:IsControlPressed()

				if btn == "DeviceButton_enter" or event.button == "Start" then
					-- invoke search
					local tags = {}
					for k,v in pairs(selectedTags) do
						if v == true then
							tags[#tags+1] = unbundleize(k)
						end
					end
					MESSAGEMAN:Broadcast("InvokePackSearch", {name=nameInput, tags=tags, tagsMatchAny=tagsMatchAny})
				else
					local del = btn == "DeviceButton_delete"
					local bs = btn == "DeviceButton_backspace"
					local back = btn == "DeviceButton_escape"
					local copypasta = btn == "DeviceButton_v" and ctrl
					local char = inputToCharacter(event)

					-- paste
					if copypasta then
						char = Arch.getClipboard()
					end

					if bs then
						nameInput = nameInput:sub(1, -2)
					elseif back then
						SCREENMAN:GetTopScreen():Cancel()
					elseif del then
						nameInput = ""
					elseif char then
						nameInput = nameInput .. char
					else
						return
					end

					self:playcommand("Set")

				end
			end
		end)
	end,
	UIElements.QuadButton(1, 1) .. {
		Name = "SearchBox",
		InitCommand = function(self)
			self:zoomto(nwidth - leftSpace, nhite):halign(0)
			self:diffuse(color("#FAF7F9"))
			self:diffusealpha(0.95)
		end,
		MouseDownCommand = function(self, params)
			if params.event == "DeviceButton_left mouse button" then
				inputting = 1
				curInput = ""
				self:GetParent():GetParent():queuecommand("Set")
				SCREENMAN:set_input_redirected(PLAYER_1, true)
			end
		end,
		SetCommand = function(self)
			if inputting == 1 then
				self:diffuse(COLOR.MainHighlight)
				self:diffusealpha(0.35)
			elseif isOver(self) then
				self:diffuse(color("#F4EAF2"))
				self:diffusealpha(1.0)
			else
				self:diffuse(color("#FAF7F9"))
				self:diffusealpha(0.95)
			end
		end,
		MouseOverCommand = function(self)
			self:playcommand("Set")
		end,
		MouseOutCommand = function(self)
			self:playcommand("Set")
		end,
	},
	LoadFont("Common Large") .. {
		Name = "UserInputText",
		InitCommand = function(self)
			self:x(nameoffx):halign(0)
			self:zoom(0.4)
			self:diffuse(COLOR.TextMain)
			self:maxwidth((nwidth - leftSpace - nameoffx) / 0.4)
		end,
		SetCommand = function(self)
			local fval = nameInput
			self:settext(fval)
			diffuseIfActiveText(self, fval ~= "" or inputting == 1)
		end,
	},
	LoadFont("Common Large") .. {
		Name = "SearchLabel",
		InitCommand = function(self)
			self:xy(-8, 0)
			self:halign(1)
			self:zoom(0.38)
			self:diffuse(COLOR.TextMain)
			self:settextf("%s:", translated_info["SearchName"])
		end,
	},
	LoadFont("Common Normal") .. {
		Name = "PackSizeRestrictionLabel",
		InitCommand = function(self)
			self:xy(-110, 34):halign(0):valign(0)
			self:zoom(0.48)
			self:diffuse(COLOR.TextSub1)
			self:settextf("%s", translated_info["SizeExplanation"])
		end,
	}
}

o[#o + 1] = LoadActor("packlistDisplay")
o[#o + 1] = LoadActor("_mouse.lua", "ScreenPackDownloader")

return o
