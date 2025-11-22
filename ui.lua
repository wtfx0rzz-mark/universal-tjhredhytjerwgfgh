-- ui.lua
local WindLibrary = loadstring(game:HttpGet("https://raw.githubusercontent.com/synw0lf/WindUI/main/source.lua"))()

local UI = {}

function UI:CreateWindow(cfg)
    local window = WindLibrary:CreateWindow(cfg)
    self.WindowTabs = {}
    function window:CreateTab(name)
        local tab = WindLibrary:CreateTab(name)
        UI.WindowTabs[name] = tab
        return tab
    end
    return window
end

function UI:Ready()
    print("Wind UI initialized")
end

return UI
