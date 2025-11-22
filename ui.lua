-- ui.lua
-- Wind UI wrapper
local WindLibrary = loadstring(game:HttpGet("https://raw.githubusercontent.com/synw0lf/WindUI/main/source.lua"))()

local UI = {}

function UI:CreateWindow(cfg)
    return WindLibrary:CreateWindow(cfg)
end

function UI:AttachSettingsTab(tab)
    tab:CreateLabel("UI Settings")
    tab:CreateToggle("Dark Mode", WindLibrary.Theme == "Dark", function(state)
        WindLibrary:SetTheme(state and "Dark" or "Light")
    end)
end

return UI
