-- player.lua
return function(C, R, UI)
    local tab = UI.WindowTabs and UI.WindowTabs.Player
    if not tab then
        warn("Player tab missing")
        return
    end

    local lp = C.LocalPlayer
    local char = lp.Character or lp.CharacterAdded:Wait()
    local hum = char:WaitForChild("Humanoid")

    tab:CreateLabel("Player Controls")

    tab:CreateSlider("WalkSpeed", 16, 250, hum.WalkSpeed, function(value)
        hum.WalkSpeed = value
    end)

    tab:CreateSlider("JumpPower", 50, 200, hum.JumpPower, function(value)
        hum.JumpPower = value
    end)

    tab:CreateButton("Reset Position", function()
        if char:FindFirstChild("HumanoidRootPart") then
            char.HumanoidRootPart.CFrame = CFrame.new(0, 10, 0)
        end
    end)
end
