-- player.lua

return function(C, R, UI)
    C  = C  or _G.C
    R  = R  or _G.R
    UI = UI or _G.UI

    if not UI or not UI.Tabs or not UI.Tabs.Player then
        warn("player.lua: Player tab missing")
        return
    end

    local tab = UI.Tabs.Player

    local Services = C.Services or {}
    local Players  = Services.Players or game:GetService("Players")
    local lp       = C.LocalPlayer or Players.LocalPlayer

    local function getHumanoid()
        local char = lp.Character or lp.CharacterAdded:Wait()
        return char:WaitForChild("Humanoid")
    end

    local section = tab:Section({
        Title = "Movement",
    })

    local hum = getHumanoid()

    section:Slider({
        Title = "WalkSpeed",
        Flag = "UH_WalkSpeed",
        Step = 1,
        Value = {
            Min     = 8,
            Max     = 250,
            Default = hum.WalkSpeed,
        },
        Callback = function(v)
            local h = getHumanoid()
            h.WalkSpeed = v
        end,
    })

    section:Slider({
        Title = "JumpPower",
        Flag = "UH_JumpPower",
        Step = 1,
        Value = {
            Min     = 25,
            Max     = 200,
            Default = hum.JumpPower,
        },
        Callback = function(v)
            local h = getHumanoid()
            if h.UseJumpPower ~= nil then
                h.UseJumpPower = true
            end
            h.JumpPower = v
        end,
    })

    section:Button({
        Title = "Reset Position",
        Icon  = "rotate-ccw",
        Callback = function()
            local char = lp.Character or lp.CharacterAdded:Wait()
            local hrp  = char:FindFirstChild("HumanoidRootPart")
            if hrp then
                hrp.CFrame = CFrame.new(0, 10, 0)
            end
        end,
    })
end
