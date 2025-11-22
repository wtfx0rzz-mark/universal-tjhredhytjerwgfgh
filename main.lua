-- main.lua
-- Entry point for Wind UI project

-- Services
local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer

-- Load external modules
local playerModule = loadstring(game:HttpGet("https://raw.githubusercontent.com/wtfx0rzz-mark/universal-tjhredhytjerwgfgh/main/player.lua"))()
local uiModule     = loadstring(game:HttpGet("https://raw.githubusercontent.com/wtfx0rzz-mark/universal-tjhredhytjerwgfgh/main/ui.lua"))()

-- Initialize Wind UI window
local Window = uiModule:CreateWindow({
    Name = "Universal Hub",
    Themeable = true,
    DefaultSize = UDim2.new(0, 500, 0, 400),
    Keybind = Enum.KeyCode.RightShift
})

-- Tabs
local mainTab   = Window:CreateTab("Main")
local playerTab = Window:CreateTab("Player")
local uiTab     = Window:CreateTab("UI")

-- Add elements to Main Tab
mainTab:CreateLabel("Welcome to Universal Hub!")
mainTab:CreateButton("Print Hello", function()
    print("Hello from Universal Hub!")
end)

-- Load Player Tab content
playerModule(playerTab)

-- Load UI Tab content
uiModule:AttachSettingsTab(uiTab)

Window:Ready()
