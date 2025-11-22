repeat task.wait() until game:IsLoaded()

local function httpget(url)
    return game:HttpGet(url)
end

-- Load UI core
local UI = (function()
    local ok, ret = pcall(function()
        return loadstring(httpget("https://raw.githubusercontent.com/wtfx0rzz-mark/universal-tjhredhytjerwgfgh/main/ui.lua"))()
    end)
    if ok and type(ret) == "table" then
        return ret
    end
    warn("ui.lua load error: " .. tostring(ret))
    error("ui.lua failed to load")
end)()

-- Core context
local C = {}
C.Services = {
    Players = game:GetService("Players"),
    RS      = game:GetService("ReplicatedStorage"),
    WS      = game:GetService("Workspace"),
    Run     = game:GetService("RunService"),
}
C.LocalPlayer = C.Services.Players.LocalPlayer
C.Config      = C.Config or {}
C.State       = C.State or {}

_G.C  = C
_G.R  = _G.R or {}
_G.UI = UI

-- Modules to load
local modules = {
    Player = "https://raw.githubusercontent.com/wtfx0rzz-mark/universal-tjhredhytjerwgfgh/main/player.lua",
}

-- Load each module safely
for name, url in pairs(modules) do
    local ok, fn = pcall(function()
        return loadstring(httpget(url))()
    end)
    if ok and type(fn) == "function" then
        task.spawn(fn, _G.C, _G.R, _G.UI)
    else
        warn(("Failed to load module %s: %s"):format(name, tostring(fn)))
    end
end

-- Initialize Wind UI window
local Window = UI:CreateWindow({
    Name = "Universal UI",
    Themeable = true,
    DefaultSize = UDim2.new(0, 500, 0, 400),
    Keybind = Enum.KeyCode.RightShift
})

local Tabs = {
    Main   = Window:CreateTab("Main"),
    Player = Window:CreateTab("Player"),
}

Tabs.Main:CreateLabel("Universal UI Loaded!")
Tabs.Main:CreateButton("Test Button", function()
    print("Universal UI works!")
end)

Window:Ready()
