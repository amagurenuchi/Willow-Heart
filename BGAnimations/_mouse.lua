local screenName = Var("LoadingScreen") or ...
local topScreen

assert(type(screenName) == "string", "Screen Name was missing when loading _mouse.lua")
BUTTON:ResetButtonTable(screenName)

local function updateMouse(frame)
    local mouseX = INPUTFILTER:GetMouseX()
    local mouseY = INPUTFILTER:GetMouseY()

    BUTTON:UpdateMouseState()

    local pointer = frame:GetChild("MousePointer")
    if pointer then
        pointer:xy(mouseX, mouseY)
    end

    if TOOLTIP and TOOLTIP.Actor then
        TOOLTIP:SetPosition(mouseX, mouseY)
    end

    return false
end

local t = Def.ActorFrame{
    InitCommand = function(self)
        self:draworder(999999)
    end,
    OnCommand = function(self)
        topScreen = SCREENMAN:GetTopScreen()
        if topScreen then
            topScreen:AddInputCallback(function(event)
                BUTTON.InputCallback(event)
            end)
        end

        self:SetUpdateFunction(updateMouse)
        local refreshRate = DISPLAY:GetDisplayRefreshRate()
        if refreshRate and refreshRate > 0 then
            self:SetUpdateFunctionInterval(1 / refreshRate)
        end
    end,
    OffCommand = function(self)
        self:SetUpdateFunction(nil)
        BUTTON:ResetButtonTable(screenName)
        if TOOLTIP and TOOLTIP.Actor then
            TOOLTIP:Hide()
        end
    end,
    CancelCommand = function(self)
        self:playcommand("Off")
    end,
}

t[#t + 1] = Def.Quad{
    Name = "MousePointer",
    InitCommand = function(self)
        self:draworder(999999):zoomto(6, 6):rotationz(45):diffuse(color("0,0,0,1"))
    end,
}

return t
