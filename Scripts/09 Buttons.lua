--[[ 
USAGE:
___________________________________________________
Setup:

Some form of continous loop is required on the Screen for calling the BUTTON:UpdateMouseState() function. This is usually done via an update function.

Input callback function is required that will call BUTTON:SetMouseDown() and the BUTTON:SetMouseUp() functions. 
Currently, both take the Event.DeviceInput.button parameters but is currently unused.

Whenever a given screen initially comes on, BUTTON:ResetButtonTable() should be called to clear any pre-existing references to any buttons.
Otherwise you will likely see error messages relating to accessing actors that no longer exist.

___________________________________________________
Button Creation:
For any actor that you want to designate as a button, call BUTTON:AddButton() from the actor.
(Usually from the OnCommand, you will likely run into issues when calling from InitCommand from uninitialized actors.)

The function takes the following parameters:

Actor - actor
The Actor object you want to designate as a button, 
actor should have a non-zero positive value when actor:GetWidth()/actor:GetHeight() is called, but otherwise can be anything.

Screen - screen
The Screen object that the actor belongs to. This is needed to handle multiple overlapping screens.
e.g: if the actor specified above was created in ScreenSelectMusic, then the screen object for ScreenSelectMusic should be specified here.
	usually you can get this value via SCREENMAN:GetTopScreen()

int	- depth (optional, default = 0)
Some more complex buttons will usually involve an ActorFrame with multiple elements. Since the ActorFrame will have no width/height values,
the ActorFrame itself cannot be used as a button. However, you can create a child Actor with a defined width/height that will act as the button boundary for the actorframe.
The depth value corresponds to the number of nodes it needs to travel before reaching the "root" Actor/ActorFrame of the button.
e.g.: If there's an actorframe and a button child, the button child will specify a depth value of 1. When it's just the button as a standalone, the depth value should be specified as 0.

In addition, the Z value of the button actor is used to detect which button should be on top in the case of overlapping buttons.
This can be set by calling Actor:z(zValue).
The button who called BUTTON:AddButton() last will be considered as being on Top for tiebreakers.
___________________________________________________
Commands/Messages Broadcast:
None

___________________________________________________
Commands/Messages Unicast:

MouseOverCommand
Is played once when the mouse first goes over the specified button. The conditions are checked every time the BUTTON:UpdateMouseState() function is called.
ChildMouseOverCommand is also played for the actor designated as the "root" as specified by the depth value.

MouseOutCommand
Is played once when the mouse that was over an actor moves off the button. The conditions are checked every time the BUTTON:UpdateMouseState() function is called.
ChildMouseOutCommand is also played for the actor designated as the "root" as specified by the depth value.

MouseDownCommand
Is played once when the left click is pressed down for the first time while being over the button. The conditions are checked every time the BUTTON:SetMouseDown() function is called.
ChildMouseDownCommand is also played for the actor designated as the "root" as specified by the depth value.

MouseUpCommand
Is played once when the mouse is released while being over the button. The conditions are checked every time the BUTTON:SetMouseUp() function is called.
ChildMouseUpCommand is also played for the actor designated as the "root" as specified by the depth value.

MouseClickCommand
Is played once when both MouseDown and MouseUp events occur on the same button. The conditions are checked every time the BUTTON:SetMouseUp() function is called.
ChildMouseClickCommand is also played for the actor designated as the "root" as specified by the depth value.

MouseReleaseCommand
Is played once when a button was pressed, but released while the mouse was no longer over the button.  The conditions are checked every time the BUTTON:SetMouseUp() function is called.
ChildMouseReleaseCommand is also played for the actor designated as the "root" as specified by the depth value.

MouseHoldCommand
Is played every time BUTTON:UpdateMouseState() is called while a button is considered to be held down (e.g. between MouseDown and MouseUp events).
The Following parameters are also passed:
	MouseX - X coordinates relative to the actor designated as the "root" as specified by the depth value.
	MouseY - Y coordinates relative to the actor designated as the "root" as specified by the depth value.

	ChildMouseHoldCommand is also played for the actor designated as the "root" as specified by the depth value.

MouseDragCommand
Is played every time BUTTON:UpdateMouseState() is called while a button is considered to be held down and movement is detected since the last time the function was called.
	(e.g. holding a button down and dragging it around).
The Following parameters are also passed:
	MouseX - X coordinates relative to the actor designated as the "root" as specified by the depth value.
	MouseY - Y coordinates relative to the actor designated as the "root" as specified by the depth value.

	ChildMouseDragCommand is also played for the actor designated as the "root" as specified by the depth value.

___________________________________________________
Limitations:

Button rollover detection only takes the following into account:

	X, Y coordinates of the Button Actors and its parent/direct ancestors.
	Rotations on the Z axis for the Button Actors and its parent/direct ancestors.
	Halign/Valign values of the Button Actor.
	Width/Height of the Button Actor.

Any other transformations applied on the actor or any of its parent/ancestors will cause the button rollover detection to fail.
	e.g. Skew, rotations on X/Y axis, zoom on parent actors.

--]]





-- Rotates coordinates x,y by an angle (degrees) from the origin.
function rotateFromOrigin(x, y, angle)
    local rad = math.rad(angle)
    return x*math.cos(rad) - y*math.sin(rad), x*math.sin(rad) + y*math.cos(rad)
end

-- Returns x2,x2 after rotated from x1,y1 by a specified angle
function rotateFromPoint(x1, y1, x2, y2, angle)
    local x = x2-x1
    local y = y2-y1

    local newx, newy = rotateFromOrigin(x, y, angle)
    return newx+x1, newy+y1
end

-- Recursively grabs the total rotation value from the Z axis.
function Actor.GetTrueRotationZ(self)
    if self == nil then
        return 0
    end

    local parent = self:GetParent()

    if parent == nil then
        return self:GetRotationZ()
    else 
        return self:GetRotationZ() + parent:GetTrueRotationZ()
    end
end

--Gets the true X/Y Position by recursively grabbing the parents' position.
--Now Attempts to take parent actors rotation into account.
function Actor.GetTrueX(self)
	if self == nil then
		return 0
	end

	local parent = self:GetParent()

	if parent == nil then
		return self:GetX()
    else
        local newX,newY = rotateFromOrigin(self:GetX(), self:GetY(), parent:GetTrueRotationZ())
		return newX + parent:GetTrueX()
	end
end

function Actor.GetTrueY(self)
	if self == nil then
		return 0
	end

	local parent = self:GetParent()

	if parent == nil then
		return self:GetY()
    else
        local newX,newY = rotateFromOrigin(self:GetX(), self:GetY(), parent:GetTrueRotationZ())
		return newY + parent:GetTrueY()
	end
end

function Actor.GetButtonRoot(self, depth)
	if self == nil then return nil end
	assert(depth >= 0, "Invalid Button Depth")
	
	local buttonRoot = self
	for i=1, depth, 1 do
		buttonRoot = buttonRoot:GetParent()
	end

	return buttonRoot
end

-- Gets the X/Y coordinates relative to the parent of the actor's "root" node.
-- "root" node is specified by the depth value, which is the number of parent nodes needed to reach the "root"
function Actor.GetLocalMousePos(self, mouseX, mouseY, depth)
    if self == nil then
        return 0,0
    end

	local buttonRoot = self:GetButtonRoot(depth)

    if buttonRoot == nil then
        return mouseX, mouseY
    else
        local rotationZ = buttonRoot:GetTrueRotationZ()
        local rootX = buttonRoot:GetTrueX()
        local rootY = buttonRoot:GetTrueY()
        return rotateFromOrigin(mouseX - rootX, mouseY - rootY, -rotationZ)
    end

end

-- Button Rollover detection
function Actor.IsOver(self, mouseX, mouseY)

    if mouseX == nil then
        mouseX = INPUTFILTER:GetMouseX()
    end

    if mouseY == nil then
        mouseY = INPUTFILTER:GetMouseY()
    end
    
    local rotationZ = self:GetTrueRotationZ()

    local x, y = self:GetX(), self:GetY()
    local tx, ty =  self:GetTrueX(), self:GetTrueY()
    local hAlign, vAlign = self:GetHAlign(), self:GetVAlign()
    local w, h = self:GetZoomedWidth(), self:GetZoomedHeight()

    -- Since the boundaries for a rotated rectangle is a pain to calculate, rotate the mouse X/Y coordinates in the opposite direction and compare.
    local newMouseX, newMouseY = rotateFromOrigin(mouseX-tx, mouseY-ty, -rotationZ)
    newMouseX = newMouseX + tx
    newMouseY = newMouseY + ty
    
    local withinX = (newMouseX >= (tx-(hAlign*w))) and (newMouseX <= ((tx+w)-(hAlign*w)))
    local withinY = (newMouseY >= (ty-(vAlign*h))) and (newMouseY <= ((ty+h)-(vAlign*h)))

    return (withinX and withinY)
end

-- Singleton for button related events.
BUTTON = {
	ButtonTable = {}, -- Table containing all the registered buttons for the current screen.
	DepthTable = {}, -- Button "depth" (# of parent actors until it reaches the "root" of the button)
	CurTopButton = nil, -- Current top button that the mouse is hovering over.
	CurTopButtonDepth = 0,
	CurDownButton = {}, -- Current button that is being held down.
	CurDownButtonDepth = {},
	UpdateOnlyOnMouseMovement = false
}

-- Actor userdata can outlive the screen that created it.  Keep stale entries
-- from escaping into the mouse callback paths below.
local function buttonActorAlive(actor)
	if actor == nil then return false end
	return pcall(function() actor:GetParent() end)
end

-- List of DeviceInput enum strings to handle for button inputs.
-- Check DeviceButton under http://dguzek.github.io/Lua-For-SM5/API/Lua.xml#Enums for all possible buttons.
BUTTON.AcceptedDeviceInput = {
	["DeviceButton_left mouse button"] = true,
	["DeviceButton_right mouse button"] = true,
	["DeviceButton_middle mouse button"] = true
}

-- Function for handling input callbacks
-- Call screen:AddInputCallback(BUTTON.InputCallback) on the OnCommand of the screen where you want mouse inputs.
function BUTTON.InputCallback(event)
	local deviceInput = event and event.DeviceInput
	if not deviceInput then return false end

	local button = deviceInput.button
	if not BUTTON.AcceptedDeviceInput[button] then return false end

	-- A click can arrive before the first frame update on a newly opened screen.
	-- Keep the coordinates valid for SetMouseDown/SetMouseUp in that case.
	BUTTON.MouseX = INPUTFILTER:GetMouseX()
	BUTTON.MouseY = INPUTFILTER:GetMouseY()

	if event.type == "InputEventType_FirstPress" then
		BUTTON:SetMouseDown(button)
	elseif event.type == "InputEventType_Release" then
		BUTTON:SetMouseUp(button)
	end

	return false
end

-- Resets the list of buttons currently added to the given screen. Call when the screen is being initialized.
function BUTTON.ResetButtonTable(self, screenName)
    if screenName ~= nil then
		self.ButtonTable[screenName] = nil
		self.CurTopButton = nil
		self.CurTopButtonDepth = 0
		self.CurDownButton = {}
		self.CurDownButtonDepth = {}
		self.MouseX = INPUTFILTER:GetMouseX()
		self.MouseY = INPUTFILTER:GetMouseY()
    end
end

-- Add/Register actors to act as buttons. This is called whenever QuadButton() is called.
function BUTTON.AddButton(self, actor, screenName, depth)
	if screenName ~= nil then
		if depth == nil then
			depth = 0
		end

        if self.ButtonTable[screenName] == nil then 
			self.ButtonTable[screenName] = {}
		end
		
		if self.DepthTable[screenName] == nil then
			self.DepthTable[screenName] = {}
		end

		self.ButtonTable[screenName][#self.ButtonTable[screenName]+1] = actor
		self.DepthTable[screenName][#self.DepthTable[screenName]+1] = depth
    end
end

-- Updates the position. Sends a broadcast if the position has changed.
-- This is called constantly from _mouse.lua via an updatefunction.
function BUTTON.UpdateMouseState(self)

	local topScreen = SCREENMAN:GetTopScreen()

    if topScreen == nil then
        return
	end

	if self.ButtonTable[topScreen:GetName()] == nil then
		if self.CurTopButton ~= nil then
			self:OnMouseOut(self.CurTopButton, self.CurTopButtonDepth)
			self.CurTopButton = nil
			self.CurTopButtonDepth = 0
		end
		return
	end

	local oldX = self.MouseX
	local oldY = self.MouseY
	self.MouseX = INPUTFILTER:GetMouseX()
	self.MouseY = INPUTFILTER:GetMouseY()


	local curButton, curButtonDepth = self:GetTopButton(self.MouseX, self.MouseY)
	-- If the top actor in which the mouse was hovering over has changed.
	if curButton ~= self.CurTopButton then
		if curButton ~= nil then 
			self:OnMouseOver(curButton, curButtonDepth)
		end
		if self.CurTopButton ~= nil then
			self:OnMouseOut(self.CurTopButton, self.CurTopButtonDepth)
		end
	end
	self.CurTopButton = curButton
	self.CurTopButtonDepth = curButtonDepth
	
	for event,curDownButton in pairs(self.CurDownButton) do

		if curDownButton ~= nil then
			if not buttonActorAlive(curDownButton) then
				self.CurDownButton[event] = nil
				self.CurDownButtonDepth[event] = nil
				goto continue
			end
			local localX, localY = curDownButton:GetLocalMousePos(self.MouseX, self.MouseY, self.CurDownButtonDepth[event])
			if oldX ~= self.MouseX or oldY ~= self.MouseY then
				self:OnMouseDrag(curDownButton, self.CurDownButtonDepth[event], {event = event, MouseX = localX, MouseY = localY})
			end
			self:OnMouseHold(curDownButton, self.CurDownButtonDepth[event], {event = event, MouseX = localX, MouseY = localY})
		end
		::continue::
	end
end

-- Record where the mousedown event occured.
function BUTTON.SetMouseDown(self, event)
	local localX, localY

	self.CurDownButton[event] = self.CurTopButton
	self.CurDownButtonDepth[event] = self.CurTopButtonDepth
	if self.CurDownButton[event] ~= nil then -- Only call onmousedown if a button is pressed.
		localX, localY = self.CurDownButton[event]:GetLocalMousePos(self.MouseX, self.MouseY, self.CurDownButtonDepth[event])
		self:OnMouseDown(self.CurDownButton[event], self.CurDownButtonDepth[event], {event = event, MouseX = localX, MouseY = localY})
	end
end

-- Record where the mouseup event occured.
function BUTTON.SetMouseUp(self, event)

	-- Make local copies as the values can change before the function ends.
	local curTopButton = self.CurTopButton
	local curTopButtonDepth = self.CurTopButtonDepth
	local curDownButton = self.CurDownButton[event]
	local curDownButtonDepth = self.CurDownButtonDepth[event]
	local localX, localY
	if not buttonActorAlive(curTopButton) then
		curTopButton = nil
		self.CurTopButton = nil
	end
	if not buttonActorAlive(curDownButton) then
		curDownButton = nil
		self.CurDownButton[event] = nil
		self.CurDownButtonDepth[event] = nil
	end

	if curTopButton == nil then
		if curDownButton == nil then -- Clicked non-button, release at non-button
            return
            
		else -- Clicked button, release at non-button
			localX, localY = curDownButton:GetLocalMousePos(self.MouseX, self.MouseY, curDownButtonDepth)
			self:OnMouseRelease(curDownButton, curDownButtonDepth, {event = event, MouseX = localX, MouseY = localY})
		end

	else
		if curDownButton == nil then -- Clicked non-button, release at button
			localX, localY = curTopButton:GetLocalMousePos(self.MouseX, self.MouseY, curTopButtonDepth)
			self:OnMouseUp(curTopButton, curTopButtonDepth, {event = event, MouseX = localX, MouseY = localY})

		elseif curDownButton == curTopButton then -- Clicked button, released on same button
			localX, localY = curTopButton:GetLocalMousePos(self.MouseX, self.MouseY, curTopButtonDepth)
			self:OnMouseUp(curTopButton, curTopButtonDepth, {event = event, MouseX = localX, MouseY = localY})
			self:OnMouseClick(curTopButton, curTopButtonDepth, {event = event, MouseX = localX, MouseY = localY})

		else -- Clicked button, released at different button
			localX, localY = curTopButton:GetLocalMousePos(self.MouseX, self.MouseY, curTopButtonDepth)
			self:OnMouseUp(curTopButton, curTopButtonDepth, {event = event, MouseX = localX, MouseY = localY})
			self:OnMouseRelease(curDownButton, curDownButtonDepth, {event = event, MouseX = localX, MouseY = localY})
		end
	end
	

	self.CurDownButton[event] = nil
	self.CurDownButtonDepth[event] = nil

end

-- Return the button with the highest Z value that is clickable from coordinates (X,Y)
function BUTTON.GetTopButton(self, x, y)
    local topScreen = SCREENMAN:GetTopScreen()
    if topScreen == nil then
        return
    end

	local topZ = 0
	local topButton = nil
	local topButtonDepth = 0

	if self.ButtonTable[topScreen:GetName()] == nil then
		return
	end

	if #self.ButtonTable[topScreen:GetName()] == 0 then
		return
	end

	for i,v in ipairs(self.ButtonTable[topScreen:GetName()]) do
		local ok, over = pcall(function()
			if not v:IsVisible() then return false end
			return v:IsOver(x, y)
		end)
		if ok and over then
			local z = v:GetZ()
			if z >= topZ then
				topButton = v
				topZ = z
				topButtonDepth = self.DepthTable[topScreen:GetName()][i]
			end
		end
	end

	return topButton, topButtonDepth
end

-- Called while an actor is held down.
function BUTTON.OnMouseHold(self, actor, depth, param)
	pcall(function()
		actor:playcommand("MouseHold", param)
		local root = actor:GetButtonRoot(depth)
		if root then root:playcommand("ChildMouseHold", param) end
	end)
end

-- Called when the mouse is moved while an actor is held down.
function BUTTON.OnMouseDrag(self, actor, depth, param)
	pcall(function()
		actor:playcommand("MouseDrag", param)
		local root = actor:GetButtonRoot(depth)
		if root then root:playcommand("ChildMouseDrag", param) end
	end)
end

-- Called when mouse begins to hover over the actor.
function BUTTON.OnMouseOver(self, actor, depth)
	pcall(function()
		actor:playcommand("MouseOver")
		local root = actor:GetButtonRoot(depth)
		if root then root:playcommand("ChildMouseOver") end
	end)
end

-- Called when the mouse is no longer hovering over the actor.
function BUTTON.OnMouseOut(self, actor, depth)
	pcall(function()
		actor:playcommand("MouseOut")
		local root = actor:GetButtonRoot(depth)
		if root then root:playcommand("ChildMouseOut") end
	end)
end

-- Called when a mouse button is pressed while over the actor.
function BUTTON.OnMouseDown(self, actor, depth, param)
	pcall(function()
		actor:playcommand("MouseDown", param)
		local root = actor:GetButtonRoot(depth)
		if root then root:playcommand("ChildMouseDown", param) end
	end)
end

-- Called when a mouse button is released while over the actor.
function BUTTON.OnMouseUp(self, actor, depth, param)
	pcall(function()
		actor:playcommand("MouseUp", param)
		local root = actor:GetButtonRoot(depth)
		if root then root:playcommand("ChildMouseUp", param) end
	end)
end

-- Called when both mousedown and mouseup events occur on the same actor.
function BUTTON.OnMouseClick(self, actor, depth, param)
	pcall(function()
		actor:playcommand("MouseClick", param)
		local root = actor:GetButtonRoot(depth)
		if root then root:playcommand("ChildMouseClick", param) end
	end)
end

-- Called when a button was pressed but a mouseup event occured while not on the button.
function BUTTON.OnMouseRelease(self, actor, depth, param)
	pcall(function()
		actor:playcommand("MouseRelease", param)
		local root = actor:GetButtonRoot(depth)
		if root then root:playcommand("ChildMouseRelease", param) end
	end)
end
