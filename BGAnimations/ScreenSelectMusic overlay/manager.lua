local active = true
local numericinputactive = false
local whee

local function IgnoreTabInputs()
	local IgnoreTabInput = themeConfig:get_data().global.IgnoreTabInput
	if IgnoreTabInput == 3 then
		return true
	elseif IgnoreTabInput == 2 and getTabIndex() == 3 then
		return true
	else
		return false
	end
end

local tabNames = {"General", "Scores", "Search", "Profile", "Filters", "Goals", "Playlists", "Tags"}
-- Keep Til Death's original internal indices so the copied tab modules remain
-- compatible, while MSD (index 1) and Packs (index 8) are no longer exposed in the UI.
local legacyIndices = {0, 2, 3, 4, 5, 6, 7, 9}
local keyBadges = {"1", "2", "3", "4", "5", "6", "7", "8"}

local function input(event)
	if event.type ~= "InputEventType_Release" and active then
		if numericinputactive == false then
			if
				not (INPUTFILTER:IsBeingPressed("left ctrl") or INPUTFILTER:IsBeingPressed("right ctrl") or
					(SCREENMAN:GetTopScreen():GetName() ~= "ScreenSelectMusic" and
					 SCREENMAN:GetTopScreen():GetName() ~= "ScreenNetSelectMusic"))
			 then
				if event.DeviceInput.button == "DeviceButton_0" then
					local tind = getTabIndex()
					-- if on the search tab dont let them press 0 if currently holding shift...
					if tind == 3 and (INPUTFILTER:IsBeingPressed("left shift") or INPUTFILTER:IsBeingPressed("right shift")) then
						return false
					end

					if not IgnoreTabInputs() then
						setTabIndex(9)
						MESSAGEMAN:Broadcast("TabChanged", {from = tind, to = 9})
					end
				else
					for i = 1, #tabNames do
						local numpad = event.DeviceInput.button == "DeviceButton_KP "..event.char	-- explicitly ignore numpad inputs for tab swapping
						if not numpad and event.char and tonumber(event.char) and tonumber(event.char) == i and not IgnoreTabInputs() then
							local tind = getTabIndex()
							setTabIndex(legacyIndices[i])
							MESSAGEMAN:Broadcast("TabChanged", {from = tind, to = legacyIndices[i]})
						end
					end
				end
			end
		end
	end
	return false
end

local t = Def.ActorFrame {
	BeginCommand = function(self)
		SCREENMAN:GetTopScreen():AddInputCallback(MPinput)
		SCREENMAN:GetTopScreen():AddInputCallback(input)
		resetTabIndex()
	end,
	NumericInputActiveMessageCommand = function(self)
		numericinputactive = true
	end,
	NumericInputEndedMessageCommand = function(self)
		numericinputactive = false
	end,
	ReloadedScriptsMessageCommand = function(self)
		MESSAGEMAN:Broadcast("TabChanged", {from = 1, to = 1})
	end,
}

-- Horizontal tab bar layout on the right side of the screen
local barWidth = capWideScale(get43size(480), 560)
local itemWidth = (barWidth / #tabNames) - 3
local itemHeight = 24
local frameY = SCREEN_HEIGHT - 18
local barRight = SCREEN_WIDTH - 10
local startX = (barRight - barWidth) + (barWidth / #tabNames) / 2

local function tabs(index)
	local stepX = barWidth / #tabNames
	local targetX = startX + (index - 1) * stepX

	local tab = Def.ActorFrame {
		Name = "Tab" .. index,
		InitCommand = function(self)
			self:xy(targetX, frameY)
		end,
		BeginCommand = function(self)
			self:queuecommand("Set")
		end,
		SetCommand = function(self)
			self:finishtweening()
			self:smooth(0.1)
			local isSelected = (getTabIndex() == legacyIndices[index])
			if isSelected then
				self:y(frameY - 2)
			else
				self:y(frameY)
			end

			local bg = self:GetChild("TabBG")
			if bg then
				bg:diffuse(isSelected and COLOR.MainHighlight or COLOR.MainBackground)
				bg:diffusealpha(isSelected and 0.95 or 0.65)
			end

			local border = self:GetChild("TabBorder")
			if border then
				border:diffuse(COLOR.MainBorder)
				border:diffusealpha(isSelected and 0.8 or 0.3)
			end

			local pill = self:GetChild("ActivePill")
			if pill then
				pill:visible(isSelected)
			end

			local badge = self:GetChild("KeyBadge")
			if badge then
				badge:diffuse(isSelected and color("#333333") or COLOR.TextSub2)
			end

			local textActor = self:GetChild("TabText")
			if textActor then
				textActor:settext(THEME:GetString("TabNames", tabNames[index]))
				if isTabEnabled(legacyIndices[index] + 1) then
					if legacyIndices[index] == 5 and FILTERMAN:AnyActiveFilter() then
						textActor:diffuse(color("#CC2929"))
					else
						textActor:diffuse(isSelected and color("#111111") or COLOR.TextMain)
					end
				else
					textActor:diffuse(color("#888888"))
				end
			end

			local filterDot = self:GetChild("FilterDot")
			if filterDot then
				filterDot:visible(legacyIndices[index] == 5 and FILTERMAN:AnyActiveFilter())
			end
		end,
		TabChangedMessageCommand = function(self)
			self:queuecommand("Set")
		end,
	}

	-- Card background fill Quad
	tab[#tab + 1] = UIElements.QuadButton(1, 1) .. {
		Name = "TabBG",
		InitCommand = function(self)
			self:zoomto(itemWidth, itemHeight)
				:diffuse(COLOR.MainBackground)
				:diffusealpha(0.65)
		end,
		MouseOverCommand = function(self)
			if getTabIndex() ~= legacyIndices[index] then
				self:diffusealpha(0.85)
			end
		end,
		MouseOutCommand = function(self)
			if getTabIndex() ~= legacyIndices[index] then
				self:diffusealpha(0.65)
			end
		end,
		MouseDownCommand = function(self, params)
			if params.event == "DeviceButton_left mouse button" then
				local tind = getTabIndex()
				setTabIndex(legacyIndices[index])
				MESSAGEMAN:Broadcast("TabChanged", {from = tind, to = legacyIndices[index]})
			end
		end
	}

	-- Border outline frame
	tab[#tab + 1] = UIElements.Border(itemWidth, itemHeight, 1) .. {
		Name = "TabBorder",
		InitCommand = function(self)
			self:diffuse(COLOR.MainBorder):diffusealpha(0.3)
		end
	}

	-- Top active indicator bar pill
	tab[#tab + 1] = Def.Quad {
		Name = "ActivePill",
		InitCommand = function(self)
			self:xy(0, -itemHeight / 2 + 1.5)
				:zoomto(itemWidth - 6, 3)
				:diffuse(COLOR.MainHighlight)
				:visible(false)
		end
	}

	-- Key badge [1], [2]...
	tab[#tab + 1] = LoadFont("Common Normal") .. {
		Name = "KeyBadge",
		InitCommand = function(self)
			self:xy(-itemWidth / 2 + 5, 0)
				:halign(0):valign(0.5)
				:zoom(0.3)
				:diffuse(COLOR.TextSub2)
				:settext(keyBadges[index] or "")
		end
	}

	-- Tab title label
	tab[#tab + 1] = LoadFont("Common Normal") .. {
		Name = "TabText",
		InitCommand = function(self)
			self:xy(-itemWidth / 2 + 16, 0)
				:halign(0):valign(0.5)
				:zoom(0.38)
				:diffuse(COLOR.TextMain)
				:maxwidth((itemWidth - 20) / 0.38)
		end
	}

	-- Active Filter dot indicator
	if legacyIndices[index] == 5 then
		tab[#tab + 1] = Def.Quad {
			Name = "FilterDot",
			InitCommand = function(self)
				self:xy(itemWidth / 2 - 6, -itemHeight / 2 + 5)
					:zoomto(6, 6)
					:diffuse(color("#CC2929"))
					:visible(false)
			end
		}
	end

	return tab
end

-- Render horizontal tabs bar at the bottom right
for i = 1, #tabNames do
	t[#t + 1] = tabs(i)
end

return t
