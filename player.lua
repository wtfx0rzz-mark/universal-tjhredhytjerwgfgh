-- player.lua
return function(tab)
    local Players = game:GetService("Players")
    local LocalPlayer = Players.LocalPlayer
    local Character = LocalPlayer.Character or LocalPlayer.CharacterAdded:Wait()
    local Humanoid = Character:WaitForChild("Humanoid")

    tab:CreateLabel("Player Controls")

    tab:CreateSlider("WalkSpeed", 16, 250, Humanoid.WalkSpeed, function(value)
        Humanoid.WalkSpeed = value
    end)

    tab:CreateSlider("JumpPower", 50, 200, Humanoid.JumpPower, function(value)
        Humanoid.JumpPower = value
    end)

    tab:CreateButton("Reset Position", function()
        if Character:FindFirstChild("HumanoidRootPart") then
            Character.HumanoidRootPart.CFrame = CFrame.new(0, 10, 0)
        end
    end)
end
