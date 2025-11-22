-- ui.lua

local Players = game:GetService("Players")
local lp = Players.LocalPlayer

local WindUI = loadstring(game:HttpGet("https://github.com/Footagesus/WindUI/releases/latest/download/main.lua"))()

local Window = WindUI:CreateWindow({
    Title = "Universal Hub",
    Icon = "grid-3x3",
    Author = "Mark",
    Folder = "UniversalHub",
    Size = UDim2.fromOffset(500, 350),
    Transparent = false,
    Theme = "Dark",
    Resizable = true,
    SideBarWidth = 150,
    HideSearchBar = false,
    ScrollBarEnabled = true,
    User = {
        Enabled = true,
        Anonymous = false,
        Callback = function()
            WindUI:Notify({
                Title = "User Info",
                Content = "Logged In As: " .. (lp.DisplayName or lp.Name),
                Duration = 3,
                Icon = "user",
            })
        end,
    },
})

-- Toggle key for entire UI
Window:SetToggleKey(Enum.KeyCode.V)

local Tabs = {
    Main = Window:Tab({
        Title = "Main",
        Icon = "home",
        Desc = "Main controls",
    }),

    Player = Window:Tab({
        Title = "Player",
        Icon = "user",
        Desc = "Player controls",
    }),
}

-- Optional: simple status section on Main tab
do
    local section = Tabs.Main:Section({
        Title = "Universal Hub",
    })

    section:Paragraph({
        Title = "Status",
        Content = "UI loaded successfully.",
    })
end

return {
    Lib    = WindUI,
    Window = Window,
    Tabs   = Tabs,
}
