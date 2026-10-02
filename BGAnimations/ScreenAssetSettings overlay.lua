-- Keep the cursor on this screen too; the picker is otherwise above the
-- song-select overlay that normally owns the mouse actor.
local t = Def.ActorFrame {
	InitCommand = function(self)
		self:draworder(999999)
	end
}

t[#t + 1] = LoadActor("_mouse.lua", "ScreenAssetSettings")

return t
