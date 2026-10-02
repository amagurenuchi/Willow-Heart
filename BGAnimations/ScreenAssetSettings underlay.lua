-- Restyled ScreenAssetSettings underlay for Willow Heart theme
local top
local profile = PROFILEMAN:GetProfile(PLAYER_1)

-- Compatibility colors for the asset picker borrowed from Til Death / Willow Heart
local function getMainColor(name)
	if name == "positive" or name == "highlight" then return COLOR.MainHighlight end
	return COLOR.MainBorder
end

-- Fallback safety for UIElements
if not UIElements then UIElements = {} end
if not UIElements.QuadButton then
	UIElements.QuadButton = function(z, depth)
		return Def.Quad {
			InitCommand = function(self) if z then self:z(z) end end,
			OnCommand = function(self)
				local screen = SCREENMAN:GetTopScreen()
				if screen ~= nil then BUTTON:AddButton(self, screen:GetName(), depth or 0) end
			end
		}
	end
end

if not UIElements.TextButton then
	UIElements.TextButton = function(z, depth, font)
		local button = Def.ActorFrame {
			UIElements.QuadButton(z, depth) .. {
				Name = "MouseButton",
				InitCommand = function(self)
					self:zoomto(100, 30):diffusealpha(0)
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

if not UIElements.Border then
	UIElements.Border = function(width, height, bw)
		return Def.ActorFrame {
			Def.Quad {
				Name = "MaskSource",
				InitCommand = function(self)
					self:zoomto(width, height):MaskSource(true)
				end
			},
			Def.Quad {
				Name = "MaskDest",
				InitCommand = function(self)
					self:zoomto(width + 2 * bw, height + 2 * bw):MaskDest()
				end
			},
			Def.Quad {
				Name = "ClearBuffer",
				InitCommand = function(self)
					self:diffusealpha(0):clearzbuffer(true)
				end
			},
		}
	end
end

local curType = 2
local assetTypes = {
	"toasty",
	"avatar",
	"judgment",
}
local translated_assets = {}
for _, v in ipairs(assetTypes) do
	translated_assets[v] = THEME:GetString("ScreenAssetSettings", v)
end

local translated_info = {
	Title = THEME:GetString("ScreenAssetSettings", "Title"),
	Selected = THEME:GetString("ScreenAssetSettings", "Selected"),
	Hovered = THEME:GetString("ScreenAssetSettings", "Hovered")
}

local maxPage = 1
local curPage = 1
local maxRows = 5
local maxColumns = 5
local curIndex = 1
local selectedIndex = 0
local GUID = profile:GetGUID()
local curPath = ""
local selectedPath = ""
local lastClickedIndex = 0

local assetTable = {}

-- Responsive Panel Geometry for Willow Heart aesthetic
local panelWidth = math.min(840, SCREEN_WIDTH - 40)
local panelHeight = math.min(500, SCREEN_HEIGHT - 90)

local gridWidth = panelWidth - 40
local gridHeight = panelHeight - 130
local cellWidth = gridWidth / maxColumns
local cellHeight = gridHeight / maxRows

local squareWidth = 52
local judgmentWidth = 130
local judgmentHeight = 22
local assetWidth = squareWidth
local assetHeight = squareWidth

local co -- for async loading images

local function findIndexForCurPage()
	local type = assetTypes[curType]
	for i = 1 + ((curPage - 1) * maxColumns * maxRows), 1 + (curPage * maxColumns * maxRows) do
		if assetTable[i] == nil then return nil end
		if assetFolders[type] .. assetTable[i] == curPath then
			return i
		end
	end
end

local function findPickedIndexForCurPage()
	local type = assetTypes[curType]
	for i = 1, #assetTable do
		if assetTable[i] == nil then return nil end
		if assetFolders[type] .. assetTable[i] == selectedPath then
			return i
		end
	end
end

local function isImage(filename)
	local extensions = {".png", ".jpg", ".jpeg"}
	local ext = string.sub(filename, #filename - 3)
	for i = 1, #extensions do
		if extensions[i] == ext then return true end
	end
	return false
end

local function isAudio(filename)
	local extensions = {".wav", ".mp3", ".ogg", ".mp4"}
	local ext = string.sub(filename, #filename - 3)
	for i = 1, #extensions do
		if extensions[i] == ext then return true end
	end
	return false
end

local function isNotFolder(filename)
	return filename:find("[.]") == nil
end

local function getImagePath(path, assets)
	for i = 1, #assets do
		if isImage(assets[i]) then
			return path .. "/" .. assets[i]
		end
	end
	return assetsFolder .. assetFolders[assetTypes[curType]] .. getDefaultAssetByType(assetTypes[curType]) .. "/default.png"
end

local function getSoundPath(path, assets)
	for i = 1, #assets do
		if isAudio(assets[i]) then
			return path .. "/" .. assets[i]
		end
	end
	return assetsFolder .. assetFolders[assetTypes[curType]] .. getDefaultAssetByType(assetTypes[curType]) .. "/default.ogg"
end

local function containsDirsOnly(dirlisting)
	if #dirlisting == 0 then return true end
	for i = 1, #dirlisting do
		if isImage(dirlisting[i]) or isAudio(dirlisting[i]) then
			return false
		end
	end
	return true
end

local function loadAssetTable()
	local type = assetTypes[curType]
	curPath = getAssetByType(type, GUID)
	selectedPath = getAssetByType(type, GUID)
	local dirlisting = FILEMAN:GetDirListing(assetFolders[type])
	if containsDirsOnly(dirlisting) then
		assetTable = filter(isNotFolder, dirlisting)
	else
		assetTable = filter(isImage, dirlisting)
	end
	maxPage = math.max(1, math.ceil(#assetTable / (maxColumns * maxRows)))
	local ind = findIndexForCurPage()
	local pickind = findPickedIndexForCurPage()
	if pickind ~= nil then selectedIndex = pickind end
	if ind ~= nil then curIndex = ind end
end

local function confirmPick()
	if curIndex == 0 then return end
	local type = assetTypes[curType]
	local name = assetTable[lastClickedIndex + ((curPage - 1) * maxColumns * maxRows)]
	if name == nil then return end
	local path = assetFolders[type] .. name
	curPath = path
	selectedPath = path
	selectedIndex = curIndex

	setAssetsByType(type, GUID, path)

	MESSAGEMAN:Broadcast("PickChanged")
end

local function updateImages()
	loadAssetTable()
	MESSAGEMAN:Broadcast("UpdatingAssets", {name = assetTypes[curType]})
	for i = 1, math.min(maxRows * maxColumns, #assetTable) do
		MESSAGEMAN:Broadcast("UpdateAsset", {index = i})
		coroutine.yield()
	end
	MESSAGEMAN:Broadcast("UpdateFinished")
end

local function loadAssetType(n)
	if n < 1 then n = 1 end
	if n > #assetTypes then n = #assetTypes end
	lastClickedIndex = 0
	curPage = 1
	curType = n
	co = coroutine.create(updateImages)
end

local function getIndex()
	local out = ((curPage - 1) * maxColumns * maxRows) + curIndex
	return out
end

local function getSelectedIndex()
	local out = ((curPage - 1) * maxColumns * maxRows) + selectedIndex
	return out
end

local function movePage(n)
	local nextPage = curPage + n
	if nextPage > maxPage then
		nextPage = maxPage
	elseif nextPage < 1 then
		nextPage = 1
	end

	if nextPage ~= curPage then
		curIndex = n < 0 and math.min(#assetTable, maxRows * maxColumns) or 1
		lastClickedIndex = 0
		curPage = nextPage
		MESSAGEMAN:Broadcast("PageMoved", {index = curIndex, page = curPage})
		co = coroutine.create(updateImages)
	end
end

local function moveCursor(x, y)
	local move = x + y * maxColumns
	local nextPage = curPage
	local oldIndex = curIndex

	if curPage > 1 and curIndex == 1 and move < 0 then
		curIndex = math.min(#assetTable, maxRows * maxColumns)
		nextPage = curPage - 1
	elseif curPage < maxPage and curIndex == maxRows * maxColumns and move > 0 then
		curIndex = 1
		nextPage = curPage + 1
	else
		curIndex = curIndex + move
		if curIndex < 1 then
			curIndex = 1
		elseif curIndex > math.min(maxRows * maxColumns, #assetTable - (maxRows * maxColumns * (curPage - 1))) then
			curIndex = math.min(maxRows * maxColumns, #assetTable - (maxRows * maxColumns * (curPage - 1)))
		end
	end
	lastClickedIndex = curIndex
	if curPage == nextPage then
		MESSAGEMAN:Broadcast("CursorMoved", {index = curIndex, prevIndex = oldIndex})
	else
		curPage = nextPage
		MESSAGEMAN:Broadcast("PageMoved", {index = curIndex, page = curPage})
		co = coroutine.create(updateImages)
	end
end

-- Category Tabs Component
local function makeCategoryTabs()
	local t = Def.ActorFrame {}
	local tabWidth = 115
	local tabHeight = 30
	local tabSpacing = 6

	for i, v in ipairs(assetTypes) do
		local tabX = (i - 1) * (tabWidth + tabSpacing)
		local labelText = translated_assets[v] or v:upper()

		local tabFrame = Def.ActorFrame {
			Name = "TabFrame_" .. i,
			InitCommand = function(self)
				self:x(tabX)
			end
		}

		tabFrame[#tabFrame + 1] = UIElements.QuadButton(1, 1) .. {
			Name = "TabBG",
			InitCommand = function(self)
				self:halign(0):valign(0.5)
				self:zoomto(tabWidth, tabHeight)
			end,
			SetCommand = function(self)
				self:finishtweening()
				self:smooth(0.12)
				if curType == i then
					self:diffuse(COLOR.MainHighlight):diffusealpha(1.0)
				elseif isOver(self) then
					self:diffuse(COLOR.MainHighlight):diffusealpha(0.5)
				else
					self:diffuse(color("#F4EAF2")):diffusealpha(0.9)
				end
			end,
			UpdatingAssetsMessageCommand = function(self) self:playcommand("Set") end,
			TabPressedMessageCommand = function(self) self:playcommand("Set") end,
			MouseOverCommand = function(self) self:playcommand("Set") end,
			MouseOutCommand = function(self) self:playcommand("Set") end,
			MouseDownCommand = function(self, params)
				if params and params.event == "DeviceButton_left mouse button" then
					MESSAGEMAN:Broadcast("TabPressed", {name = labelText, index = i})
					loadAssetType(i)
				end
			end
		}

		tabFrame[#tabFrame + 1] = LoadFont("Common Large") .. {
			Name = "TabText",
			InitCommand = function(self)
				self:xy(tabWidth / 2, 0)
				self:zoom(0.32)
				self:maxwidth((tabWidth - 12) / 0.32)
				self:settext(labelText:upper())
			end,
			SetCommand = function(self)
				self:finishtweening()
				if curType == i then
					self:diffuse(COLOR.TextMain)
				else
					self:diffuse(COLOR.TextSub1)
				end
			end,
			UpdatingAssetsMessageCommand = function(self) self:playcommand("Set") end,
			TabPressedMessageCommand = function(self) self:playcommand("Set") end
		}

		t[#t + 1] = tabFrame
	end
	return t
end

local function assetBox(i)
	local name = ""
	local col = (i - 1) % maxColumns
	local row = math.floor((i - 1) / maxColumns)

	local cellX = -panelWidth / 2 + 20 + (col + 0.5) * cellWidth
	local cellY = -panelHeight / 2 + 62 + (row + 0.5) * cellHeight

	local t = Def.ActorFrame {
		Name = tostring(i),
		InitCommand = function(self)
			self:xy(cellX, cellY)
			self:diffusealpha(0)
		end,
		PageMovedMessageCommand = function(self)
			self:finishtweening()
			self:smooth(0.15)
			self:diffusealpha(0)
		end,
		UpdateAssetMessageCommand = function(self, params)
			if params and params.index == i then
				local fullIndex = i + ((curPage - 1) * maxColumns * maxRows)
				if fullIndex > #assetTable then
					self:finishtweening()
					self:smooth(0.15)
					self:diffusealpha(0)
				else
					local type = assetTypes[curType]
					name = assetFolders[type] .. assetTable[fullIndex]
					if name == curPath then
						curIndex = i
					end

					if curType == 3 then
						assetWidth = judgmentWidth
						assetHeight = judgmentHeight
					else
						assetWidth = squareWidth
						assetHeight = squareWidth
					end

					self:GetChild("Image"):playcommand("LoadAsset")
					self:GetChild("Sound"):playcommand("LoadAsset")
					self:GetChild("SelectedAssetIndicator"):playcommand("Set")
					self:playcommand("UpdateTileState")

					self:finishtweening()
					self:smooth(0.15)
					self:diffusealpha(1)
				end
			end
		end,
		UpdateFinishedMessageCommand = function(self)
			local fullIndex = i + ((curPage - 1) * maxColumns * maxRows)
			if assetTable[fullIndex] == nil then
				self:finishtweening()
				self:smooth(0.15)
				self:diffusealpha(0)
			end
			if curType == 3 and i == 1 then
				local picked = findPickedIndexForCurPage()
				if picked then
					MESSAGEMAN:Broadcast("CursorMoved", {index = picked})
				end
			end
		end,
		CursorMovedMessageCommand = function(self) self:playcommand("UpdateTileState") end,
		PickChangedMessageCommand = function(self) self:playcommand("UpdateTileState") end,
		PageMovedMessageCommand = function(self) self:playcommand("UpdateTileState") end
	}

	-- Tile Base Card
	t[#t + 1] = Def.Quad {
		Name = "TileBG",
		InitCommand = function(self)
			self:zoomto(cellWidth - 8, cellHeight - 8)
			self:diffuse(color("#F4EAF2")):diffusealpha(0.85)
		end,
		UpdateTileStateCommand = function(self)
			self:finishtweening()
			self:smooth(0.1)
			if selectedPath == name and name ~= "" then
				self:diffuse(COLOR.MainHighlight):diffusealpha(0.3)
			elseif i == curIndex then
				self:diffuse(COLOR.MainHighlight):diffusealpha(0.55)
			else
				self:diffuse(color("#F4EAF2")):diffusealpha(0.85)
			end
		end
	}

	-- Selected Asset Indicator (Required child actor contract from original code)
	t[#t + 1] = Def.Quad {
		Name = "SelectedAssetIndicator",
		InitCommand = function(self)
			self:zoomto(cellWidth - 6, 3)
			self:valign(1):y((cellHeight - 6) / 2)
			self:diffuse(COLOR.MainHighlight):diffusealpha(0)
		end,
		SetCommand = function(self)
			self:finishtweening()
			if selectedPath == name and name ~= "" then
				self:smooth(0.12)
				self:diffusealpha(1)
			else
				self:smooth(0.12)
				self:diffusealpha(0)
			end
		end,
		PageMovedMessageCommand = function(self) self:queuecommand("Set") end,
		PickChangedMessageCommand = function(self) self:queuecommand("Set") end
	}

	-- Saved Asset Text Badge
	t[#t + 1] = LoadFont("Common Normal") .. {
		Name = "SavedBadge",
		InitCommand = function(self)
			self:xy((cellWidth - 14) / 2, -(cellHeight - 14) / 2)
			self:halign(1):valign(0)
			self:zoom(0.32)
			self:diffuse(COLOR.TextMain)
			self:settext("SAVED")
			self:diffusealpha(0)
		end,
		UpdateTileStateCommand = function(self)
			self:finishtweening()
			if selectedPath == name and name ~= "" then
				self:diffusealpha(0.9)
			else
				self:diffusealpha(0)
			end
		end
	}

	-- Border / Focus Button (Required child actor contract from original code)
	t[#t + 1] = UIElements.QuadButton(1, 1) .. {
		Name = "Border",
		InitCommand = function(self)
			self:zoomto(cellWidth - 6, cellHeight - 6)
			self:diffuse(COLOR.MainHighlight):diffusealpha(0)
		end,
		SelectCommand = function(self)
			self:finishtweening()
			self:smooth(0.1)
			self:zoomto(cellWidth - 4, cellHeight - 4)
			self:diffuse(COLOR.MainHighlight):diffusealpha(0.9)
		end,
		DeselectCommand = function(self)
			self:finishtweening()
			self:smooth(0.1)
			self:zoomto(cellWidth - 6, cellHeight - 6)
			self:diffuse(COLOR.MainBorder):diffusealpha(0)
		end,
		CursorMovedMessageCommand = function(self, params)
			if params and params.index == i then
				self:playcommand("Select")
			else
				self:playcommand("Deselect")
			end
		end,
		PageMovedMessageCommand = function(self, params)
			if params and params.index == i then
				self:playcommand("Select")
			else
				self:playcommand("Deselect")
			end
		end,
		MouseDownCommand = function(self, params)
			if params and params.event == "DeviceButton_left mouse button" and assetTable[i + ((curPage - 1) * maxColumns * maxRows)] ~= nil then
				if lastClickedIndex == i then
					confirmPick()
				end
				local prev = curIndex
				lastClickedIndex = i
				curIndex = i
				MESSAGEMAN:Broadcast("CursorMoved", {index = i, prevIndex = prev})
			end
		end
	}

	-- Image Sprite (Strictly clamped to tile dimensions so native resolution images never overflow)
	t[#t + 1] = Def.Sprite {
		Name = "Image",
		LoadAssetCommand = function(self)
			local assets = findAssetsForPath(name)
			if #assets > 1 then
				local image = getImagePath(name, assets)
				self:LoadBackground(image)
			else
				self:LoadBackground(name)
			end
			local targetW = (curType == 3) and judgmentWidth or squareWidth
			local targetH = (curType == 3) and judgmentHeight or squareWidth
			if i == curIndex then
				self:zoomto(targetW + 6, targetH + 6)
			else
				self:zoomto(targetW, targetH)
			end
		end,
		UpdateTileStateCommand = function(self)
			self:finishtweening()
			local targetW = (curType == 3) and judgmentWidth or squareWidth
			local targetH = (curType == 3) and judgmentHeight or squareWidth
			if i == curIndex then
				self:smooth(0.1)
				self:zoomto(targetW + 6, targetH + 6)
			else
				self:smooth(0.1)
				self:zoomto(targetW, targetH)
			end
		end,
		CursorMovedMessageCommand = function(self, params)
			self:finishtweening()
			local targetW = (curType == 3) and judgmentWidth or squareWidth
			local targetH = (curType == 3) and judgmentHeight or squareWidth
			if params and params.index == i then
				self:smooth(0.1)
				self:zoomto(targetW + 6, targetH + 6)
			else
				self:smooth(0.1)
				self:zoomto(targetW, targetH)
			end
		end,
		PageMovedMessageCommand = function(self, params)
			self:finishtweening()
			local targetW = (curType == 3) and judgmentWidth or squareWidth
			local targetH = (curType == 3) and judgmentHeight or squareWidth
			if params and params.index == i then
				self:smooth(0.1)
				self:zoomto(targetW + 6, targetH + 6)
			else
				self:smooth(0.1)
				self:zoomto(targetW, targetH)
			end
		end
	}

	-- Sound Actor (Required child actor contract from original code)
	t[#t + 1] = Def.Sound {
		Name = "Sound",
		LoadAssetCommand = function(self)
			local assets = findAssetsForPath(name)
			if #assets > 1 then
				local soundpath = getSoundPath(name, assets)
				self:load(soundpath)
			else
				self:load("")
			end
		end,
		CursorMovedMessageCommand = function(self, params)
			if params and params.index == i and curType == 1 and params.prevIndex ~= i then
				self:play()
			end
		end
	}

	return t
end

local function mainContainer()
	local t = Def.ActorFrame {}

	-- Panel Base Card
	t[#t + 1] = Def.Quad {
		Name = "PanelBG",
		InitCommand = function(self)
			self:zoomto(panelWidth, panelHeight)
			self:diffuse(color("#FAF7F9")):diffusealpha(0.96)
		end
	}

	-- Top Accent Strip
	t[#t + 1] = Def.Quad {
		Name = "TopAccent",
		InitCommand = function(self)
			self:valign(0):y(-panelHeight / 2)
			self:zoomto(panelWidth, 4)
			self:diffuse(COLOR.MainHighlight)
		end
	}

	-- Category Tabs
	t[#t + 1] = makeCategoryTabs() .. {
		InitCommand = function(self)
			self:xy(-panelWidth / 2 + 20, -panelHeight / 2 + 24)
		end
	}

	-- Pagination & Count Badge
	t[#t + 1] = Def.ActorFrame {
		Name = "PageControls",
		InitCommand = function(self)
			self:xy(panelWidth / 2 - 20, -panelHeight / 2 + 24)
		end,

		LoadFont("Common Normal") .. {
			Name = "ItemCountText",
			InitCommand = function(self)
				self:xy(-145, 0):halign(1):zoom(0.48)
				self:diffuse(COLOR.TextSub1)
			end,
			SetCommand = function(self)
				local cur = getIndex()
				local max = #assetTable
				self:settextf("%d / %d assets", max > 0 and cur or 0, max)
			end,
			UpdateFinishedMessageCommand = function(self) self:queuecommand("Set") end,
			CursorMovedMessageCommand = function(self) self:queuecommand("Set") end,
			PageMovedMessageCommand = function(self) self:queuecommand("Set") end
		},

		UIElements.TextButton(1, 1, "Common Large") .. {
			Name = "PrevPageBtn",
			InitCommand = function(self)
				self.bg = self:GetChild("BG")
				self.txt = self:GetChild("Text")
				self:xy(-110, 0)
				if self.bg then self.bg:zoomto(26, 26):diffuse(color("#F4EAF2")) end
				if self.txt then self.txt:settext("<"):zoom(0.4):diffuse(COLOR.TextMain) end
			end,
			RolloverUpdateCommand = function(self)
				if self.bg then
					if isOver(self.bg) then
						self.bg:diffuse(COLOR.MainHighlight)
					else
						self.bg:diffuse(color("#F4EAF2"))
					end
				end
			end,
			ClickCommand = function(self, params)
				if params and params.update == "OnMouseDown" then
					movePage(-1)
				end
			end
		},

		LoadFont("Common Normal") .. {
			Name = "PageNumText",
			InitCommand = function(self)
				self:xy(-55, 0):zoom(0.5):diffuse(COLOR.TextMain)
			end,
			SetCommand = function(self)
				self:settextf("Page %d/%d", curPage, maxPage)
			end,
			UpdateFinishedMessageCommand = function(self) self:queuecommand("Set") end,
			PageMovedMessageCommand = function(self) self:queuecommand("Set") end
		},

		UIElements.TextButton(1, 1, "Common Large") .. {
			Name = "NextPageBtn",
			InitCommand = function(self)
				self.bg = self:GetChild("BG")
				self.txt = self:GetChild("Text")
				self:xy(0, 0)
				if self.bg then self.bg:zoomto(26, 26):diffuse(color("#F4EAF2")) end
				if self.txt then self.txt:settext(">"):zoom(0.4):diffuse(COLOR.TextMain) end
			end,
			RolloverUpdateCommand = function(self)
				if self.bg then
					if isOver(self.bg) then
						self.bg:diffuse(COLOR.MainHighlight)
					else
						self.bg:diffuse(color("#F4EAF2"))
					end
				end
			end,
			ClickCommand = function(self, params)
				if params and params.update == "OnMouseDown" then
					movePage(1)
				end
			end
		}
	}

	-- Grid Tiles
	for i = 1, maxRows * maxColumns do
		t[#t + 1] = assetBox(i)
	end

	-- Footer Divider Line
	t[#t + 1] = Def.Quad {
		Name = "FooterLine",
		InitCommand = function(self)
			self:xy(0, panelHeight / 2 - 52)
			self:zoomto(panelWidth - 30, 1)
			self:diffuse(COLOR.MainBorder):diffusealpha(0.15)
		end
	}

	-- Hovered Asset Info (Contract child: CurrentPath)
	t[#t + 1] = Def.ActorFrame {
		Name = "HoveredInfo",
		InitCommand = function(self)
			self:xy(-panelWidth / 2 + 24, panelHeight / 2 - 28)
		end,
		LoadFont("Common Normal") .. {
			Text = "HOVERED ASSET",
			InitCommand = function(self)
				self:halign(0):y(-9):zoom(0.34):diffuse(COLOR.TextSub2)
			end
		},
		LoadFont("Common Large") .. {
			Name = "CurrentPath",
			InitCommand = function(self)
				self:halign(0):y(6):zoom(0.38):diffuse(COLOR.TextMain)
				self:maxwidth((panelWidth / 2 - 50) / 0.38)
			end,
			SetCommand = function(self)
				local type = assetTable[getIndex()]
				if type == nil then
					self:settextf("%s: ", translated_info["Hovered"])
				else
					self:settextf("%s: " .. type:gsub("^%l", string.upper), translated_info["Hovered"])
				end
			end,
			CursorMovedMessageCommand = function(self) self:queuecommand("Set") end,
			UpdateFinishedMessageCommand = function(self) self:queuecommand("Set") end
		}
	}

	-- Saved Asset Info (Contract child: SelectedPath)
	t[#t + 1] = Def.ActorFrame {
		Name = "SavedInfo",
		InitCommand = function(self)
			self:xy(10, panelHeight / 2 - 28)
		end,
		LoadFont("Common Normal") .. {
			Text = "SAVED ASSET",
			InitCommand = function(self)
				self:halign(0):y(-9):zoom(0.34):diffuse(COLOR.TextSub2)
			end
		},
		LoadFont("Common Large") .. {
			Name = "SelectedPath",
			InitCommand = function(self)
				self:halign(0):y(6):zoom(0.38):diffuse(COLOR.MainHighlight)
				self:maxwidth((panelWidth / 2 - 50) / 0.38)
			end,
			SetCommand = function(self)
				local type = assetTable[selectedIndex]
				if type == nil then
					self:settextf("%s: ", translated_info["Selected"])
				else
					self:settextf("%s: " .. type:gsub("^%l", string.upper), translated_info["Selected"])
				end
			end,
			PickChangedMessageCommand = function(self) self:queuecommand("Set") end,
			UpdateFinishedMessageCommand = function(self) self:queuecommand("Set") end
		}
	}

	-- Category Indicator (Contract child: AssetType)
	t[#t + 1] = LoadFont("Common Large") .. {
		Name = "AssetType",
		InitCommand = function(self)
			self:visible(false)
		end,
		SetCommand = function(self)
			local type = translated_assets[assetTypes[curType]]
			self:settext(type or "")
		end,
		UpdatingAssetsMessageCommand = function(self) self:queuecommand("Set") end
	}

	return t
end

local function input(event)
	if event.type ~= "InputEventType_Release" then
		if event.button == "Back" then
			SCREENMAN:GetTopScreen():Cancel()
		end

		if event.button == "Start" then
			confirmPick()
		end

		if event.button == "Left" or event.button == "MenuLeft" then
			moveCursor(-1, 0)
		end

		if event.button == "Right" or event.button == "MenuRight" then
			moveCursor(1, 0)
		end

		if event.button == "Up" or event.button == "MenuUp" then
			moveCursor(0, -1)
		end

		if event.button == "Down" or event.button == "MenuDown" then
			moveCursor(0, 1)
		end

		if event.button == "EffectUp" then
			loadAssetType(curType + 1)
		end

		if event.button == "EffectDown" then
			loadAssetType(curType - 1)
		end

		local char = inputToCharacter(event)
		if char ~= nil and tonumber(char) ~= nil and tonumber(char) >= 1 and tonumber(char) <= 3 then
			loadAssetType(tonumber(char))
		end
	end
	if event.type == "InputEventType_FirstPress" then
		if event.DeviceInput.button == "DeviceButton_right mouse button" then
			MESSAGEMAN:Broadcast("MouseRightClick")
		elseif event.DeviceInput.button == "DeviceButton_mousewheel up" then
			movePage(-1)
		elseif event.DeviceInput.button == "DeviceButton_mousewheel down" then
			movePage(1)
		end
	end

	return false
end

local function update(self, delta)
	if coroutine.status(co) ~= "dead" then
		coroutine.resume(co)
	end
end

local t = Def.ActorFrame {
	BeginCommand = function(self)
		SCREENMAN:set_input_redirected(PLAYER_1, true)
		top = SCREENMAN:GetTopScreen()
		top:AddInputCallback(input)
		co = coroutine.create(updateImages)
		self:SetUpdateFunction(update)
	end,
	MouseRightClickMessageCommand = function(self)
		SCREENMAN:GetTopScreen():Cancel()
	end
}

-- Screen Background Quad
t[#t + 1] = Def.Quad {
	Name = "ScreenBG",
	InitCommand = function(self)
		self:FullScreen()
		self:diffuse(COLOR.MainBackground)
	end
}
-- Theme Background Actor
t[#t + 1] = LoadActor("_songbg.lua")

-- Main Container Card
t[#t + 1] = mainContainer() .. {
	InitCommand = function(self)
		self:xy(SCREEN_CENTER_X, SCREEN_CENTER_Y + 12)
	end
}

-- Bottom Navigation Hints Bar
t[#t + 1] = LoadFont("Common Normal") .. {
	Name = "NavInstructions",
	Text = "ARROWS / MOUSE: Navigate    ENTER / CLICK: Select Asset    PAGE UP/DOWN / WHEEL: Change Page    1-3: Category    ESC / RIGHT-CLICK: Back",
	InitCommand = function(self)
		self:xy(SCREEN_CENTER_X, SCREEN_HEIGHT - 16)
		self:zoom(0.42)
		self:diffuse(COLOR.TextSub2)
	end
}

return t
