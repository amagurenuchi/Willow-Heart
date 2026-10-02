UIElements = {}

-- Adapted from  Simply-Love-SM5/Scripts/SL-Helpers.lua
function UIElements.Border(width, height, bw)
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
				self:zoomto(width+2*bw,height+2*bw):MaskDest()
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

-- Basic clickable button implementation with quads
function UIElements.QuadButton(z, depth)

	local t = Def.Quad{
		InitCommand = function(self) 
			self:z(z)
		end,
		OnCommand = function(self)
			local screen = SCREENMAN:GetTopScreen()
			if screen ~= nil then
				BUTTON:AddButton(self, screen:GetName(), depth)
			end
		end,
		MouseOverCommand = function(self) end,
		MouseOutCommand = function(self) end,
		MouseUpCommand = function(self, params) end,
		MouseDownCommand = function(self, params) end,
		MouseClickCommand = function(self, params) end,
		MouseReleaseCommand = function(self, params) end,
		MouseDragCommand = function(self, params) end,
		MouseHoldCommand = function(self, params) end,
	}
	return t
end

-- Clickable text element implementation with font actors
function UIElements.TextToolTip(z, depth, font)
	local t = LoadFont(font or "Common Normal") .. {
		InitCommand = function(self) 
			if z then self:z(z) end
		end,
		OnCommand = function(self)
			local screen = SCREENMAN:GetTopScreen()
			if screen ~= nil then
				BUTTON:AddButton(self, screen:GetName(), depth or 0)
			end
		end,
		MouseOverCommand = function(self) end,
		MouseOutCommand = function(self) end,
		MouseUpCommand = function(self, params) end,
		MouseDownCommand = function(self, params) end,
		MouseClickCommand = function(self, params) end,
		MouseReleaseCommand = function(self, params) end,
		MouseDragCommand = function(self, params) end,
		MouseHoldCommand = function(self, params) end,
	}
	return t
end

-- Til Death's copied tab modules use this small composite button.
function UIElements.TextButton(z, depth, font)
	local t = Def.ActorFrame{
		ChildMouseDownCommand = function(self, params) self:playcommand("Click", {update="OnMouseDown", event=params and params.event}) end,
		ChildMouseUpCommand = function(self, params) self:playcommand("Click", {update="OnMouseUp", event=params and params.event}) end,
		ChildMouseClickCommand = function(self, params) self:playcommand("Click", {update="OnMouseClicked", event=params and params.event}) end,
	}
	t[#t+1] = Def.Quad{Name="BG",InitCommand=function(self) self:diffuse(COLOR.MainBackground):diffusealpha(0.2) end}
	t[#t+1] = UIElements.QuadButton(z, depth)..{InitCommand=function(self) self:zoomto(220,30):diffusealpha(0) end}
	t[#t+1] = LoadFont(font or "Common Normal")..{Name="Text",InitCommand=function(self) self:halign(0.5):valign(0.5) end}
	return t
end

-- Basic clickable button implementation with quads
function ButtonDemo(z)

	local t = Def.ActorFrame{
		RolloverUpdateCommand = function(self, params)
			self:PlayCommandsOnChildren("RolloverUpdate", params)
		end,
		ClickCommand = function(self, params)
			self:PlayCommandsOnChildren("Click", params)
		end,
		DragUpdateCommand = function(self, params)
			self:xy(params.MouseX, params.MouseY)
		end,
	}
	
	t[#t+1] = UIElements.Border(150, 50, 5)..{
		InitCommand = function(self)
			self:visible(false):diffuse(color("#000000"))
		end,
		RolloverUpdateCommand = function(self, params)
			if params.update == "over" then
				self:visible(true)
				TOOLTIP:Show()
				TOOLTIP:SetText(string.format("X:%0.2f Y:%0.2f", self:GetTrueX(), self:GetTrueY()))
			end
		
			if params.update == "out" then
				self:visible(false)
				TOOLTIP:Hide()
			end
		end
	}

	t[#t+1] = UIElements.QuadButton(z, 1)..{
		InitCommand= function(self) 
			self:z(z):zoomto(150,50):diffuse(color("#000000")):diffusealpha(0.5)
		end,
		MouseOverCommand = function(self) self:GetParent():playcommand("RolloverUpdate",{update = "over"}) end,
		MouseOutCommand = function(self) self:GetParent():playcommand("RolloverUpdate",{update = "out"}) end,
		MouseUpCommand = function(self,params) self:diffuse(color("#FF0000")):diffusealpha(0.5) self:GetParent():playcommand("Click",{update = "OnMouseUp", event = params.event}) end,
		MouseDownCommand = function(self,params) self:diffuse(color("#00FF00")):diffusealpha(0.5) self:GetParent():playcommand("Click",{update = "OnMouseDown", event = params.event}) end,
		MouseClickCommand = function(self,params) self:diffuse(color("#0000FF")):diffusealpha(0.5) self:GetParent():playcommand("Click",{update = "OnMouseClicked", event = params.event}) end,
		MouseReleaseCommand = function(self,params) self:diffuse(color("#FF00FF")):diffusealpha(0.5) self:GetParent():playcommand("Click",{update = "OnMouseReleased", event = params.event}) end,
		MouseDragCommand = function(self, params) self:GetParent():playcommand("DragUpdate", params) end,
	}

	t[#t+1] = LoadFont("Common Normal") .. {
		InitCommand= function(self) 
			self:y(0):zoom(0.6):settext("init")
		end,
		ClickCommand = function(self, params)
			self:settextf("X:%.0f Y:%.0f \nAngle:%.0f \n%s",self:GetTrueX(), self:GetTrueY(), self:GetTrueRotationZ()%360, params.event)
		end,
	}

	return t
end


-- Checkboxes
function UIElements.CheckBox(z, checked)

	local zoom = 0.15
	local checked = checked

	local t = Def.ActorFrame{
		OnCommand = function(self)
			self:playcommand("Toggle")
		end,
		ChildMouseClickCommand = function(self)
			if checked then 
				checked = false
				self:playcommand("Uncheck")
				self:RunCommandsOnChildren(function(self) self:playcommand("Uncheck") end)
			else
				checked = true
				self:playcommand("Check")
				self:RunCommandsOnChildren(function(self) self:playcommand("Check") end)
			end
		end,
		CheckCommand = function(self)
		end,
		UncheckCommand = function(self)
		end
	}

	t[#t+1] = UIElements.QuadButton(z, 1) .. {
		InitCommand = function(self)
			self:zoomto(zoom*100,zoom*100)
			self:diffuse(COLOR.TextMain)
		end,
		MouseDownCommand = function(self)
			self:diffuse(COLOR.TextSub2)
		end,
		MouseUpCommand = function(self)
			self:diffuse(COLOR.TextMain)
		end,
		MouseReleaseCommand = function(self)
			self:diffuse(COLOR.TextMain)
		end
	}

	t[#t+1] = LoadActor(THEME:GetPathG("", "_x"))..{
		InitCommand = function(self)
			self:zoom(zoom)
		end,
		CheckCommand = function(self)
			self:finishtweening()
			self:smooth(0.1)
			self:zoom(zoom)
			self:diffusealpha(1)
		end,
		UncheckCommand = function(self)
			self:finishtweening()
			self:smooth(0.1)
			self:zoom(0)
			self:diffusealpha(0)
		end
	}

	return t
end

function UIElements.Slider(z, width)
	local zoom = 0.15

	local t = Def.ActorFrame{
		SliderMovedCommand = function(self, params)
			self:GetChild("ValueText"):settext(params.Value)
		end,
	}

	t[#t+1] = UIElements.QuadButton(z+1, 0) .. {
		Name = "SliderBar",
		InitCommand = function(self)
			self:zoomto(width, zoom*100/2)
			self:halign(0)
		end,
		MouseOverCommand = function(self) end,
		MouseOutCommand = function(self) end,
		MouseUpCommand = function(self, params) end,
		MouseDownCommand = function(self, params)
			local mouseX = clamp(params.MouseX,0,width)
			self:GetParent():GetChild("SliderHandle"):x(mouseX)
			self:GetParent():playcommand("SliderMoved", {Value = mouseX/width})
		end,
		MouseClickCommand = function(self, params) end,
		MouseReleaseCommand = function(self, params) end,
		MouseDragCommand = function(self, params)
			local mouseX = clamp(params.MouseX,0,width)
			self:GetParent():GetChild("SliderHandle"):x(mouseX)
			self:GetParent():playcommand("SliderMoved", {Value = mouseX/width})
		end,
	}

	t[#t+1] = UIElements.QuadButton(z, 0) .. {
		Name = "SliderHandle",
		InitCommand = function(self)
			self:zoomto(zoom*100,zoom*100)
			self:diffuse(COLOR.TextMain)
			self:x(0)
		end,
		MouseOverCommand = function(self) end,
		MouseOutCommand = function(self) end,
		MouseUpCommand = function(self, params) end,
		MouseDownCommand = function(self, params) end,
		MouseClickCommand = function(self, params) end,
		MouseReleaseCommand = function(self, params) end,
		MouseDragCommand = function(self, params)
			local mouseX = clamp(params.MouseX,0,width)
			self:x(mouseX)
			self:GetParent():playcommand("SliderMoved", {Value = mouseX/width})
		end,
	}

	t[#t+1] = LoadFont("Common Normal") .. {
		Name = "ValueText",
		InitCommand = function(self)
			self:x(width + 10):zoom(0.6):halign(0):diffuse(color("#000000"))
		end;
	}

	return t

end

function UIElements.DoubleSlider()

end
