-- Til Death tab compatibility.  The tab modules are copied unchanged; only
-- their color dependency is mapped to Willow Heart.
function getMainColor(name)
	if name == "positive" then return COLOR.MainHighlight end
	if name == "negative" then return COLOR.MainHighlight end
	if name == "frames" or name == "tabs" then return COLOR.MainBackground end
	return COLOR.TextMain
end

-- Screen-select is able to load before the optional UI helper script on some
-- Etterna builds, so provide Til Death's missing TextButton here as well.
UIElements = UIElements or {}
if not UIElements.TextButton then
	UIElements.TextButton = function(z, depth, font)
		local t = Def.ActorFrame{
			ChildMouseDownCommand = function(self, params) self:playcommand("Click", {update="OnMouseDown", event=params and params.event}) end,
			ChildMouseUpCommand = function(self, params) self:playcommand("Click", {update="OnMouseUp", event=params and params.event}) end,
			ChildMouseClickCommand = function(self, params) self:playcommand("Click", {update="OnMouseClicked", event=params and params.event}) end,
		}
		t[#t+1] = Def.Quad{Name="BG",InitCommand=function(self) self:diffuse(COLOR.MainBackground):diffusealpha(0.2) end}
		t[#t+1] = UIElements.QuadButton and UIElements.QuadButton(z, depth) or Def.Quad{InitCommand=function(self) self:zoomto(220,30):diffusealpha(0) end}
		t[#t+1] = LoadFont(font or "Common Normal")..{Name="Text",InitCommand=function(self) self:halign(0.5):valign(0.5) end}
		return t
	end
end

if not UIElements.SpriteButton then
	UIElements.SpriteButton = function(z, depth, path)
		local t = Def.ActorFrame{}
		t[#t+1] = Def.Sprite{Name="Sprite",InitCommand=function(self)
			if path and path ~= "" then self:Load(path) end
			self:z(z or 0)
		end}
		t[#t+1] = UIElements.QuadButton and UIElements.QuadButton(z or 0, depth or 0) or Def.Quad{}
		return t
	end
end

function Brightness(c, _) return c end
function Saturation(c, _) return c end
function getDifficultyColor(_) return COLOR.MainHighlight end
function isOver(actor) return actor and actor:IsOver() or false end
function MPinput(_) return false end
function tilDeathEmulationEnabled(_) return false end
function byMSD(value) return GetRatingColor(tonumber(value) or 0) end
function getClearTypeFromScore(_, _, mode) return mode == 2 and COLOR.TextSub2 or "" end
colorConfig = colorConfig or {get_data = function() return {clearType = {NoPlay = "#666666"}} end}
function GetPlayerOrMachineProfile(pn)
	return PROFILEMAN:GetProfile(pn) or PROFILEMAN:GetMachineProfile()
end
function getCurRateValue()
	local options = GAMESTATE:GetSongOptionsObject("ModsLevel_Current")
	return options and options.MusicRate and options:MusicRate() or 1
end
function getShortDifficulty(value) return tostring(value or "--") end
function getGradeColor(grade) return GetGradeColor(grade) end
function getScoreDate(score) return score and score.GetDateString and score:GetDateString() or "--" end
function getJudgeStrings(judge) return tostring(judge or "") end
function getModifierTranslations() return {} end
function byGrade(value) return GetGradeColor(value) end
function byJudgment(value) return COLOR.TextMain end
function byDifficulty(value) return COLOR.TextMain end
function byValidity(value) return value and COLOR.TextMain or COLOR.TextSub2 end

if not tags then
	local tagData = {playerTags = {}}
	tags = {
		get_data = function() return tagData end,
		set_dirty = function() end,
		save = function() end,
	}
end

if not notShit then
	local function round(value, places)
		local factor = 10 ^ (places or 0)
		return math.floor(value * factor + 0.5) / factor
	end
	notShit = {round = round, floor = math.floor, ceil = math.ceil}
end

if not ms then
	ms = {
		SkillSets = {"Overall", "Stream", "Jumpstream", "Handstream", "Stamina", "JackSpeed", "Chordjack", "Technical"},
		SkillSetsTranslated = {"Overall", "Stream", "Jumpstream", "Handstream", "Stamina", "Jack Speed", "Chordjack", "Technical"},
		JudgeScalers = {},
	}
end

return Def.Actor{}
