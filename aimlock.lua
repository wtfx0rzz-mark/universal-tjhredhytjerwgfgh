return function(C, R, UI)
    C  = C  or _G.C
    R  = R  or _G.R
    UI = UI or _G.UI

    local Services = C.Services or {}
    local Players  = Services.Players or game:GetService("Players")
    local Run      = Services.Run     or game:GetService("RunService")
    local WS       = Services.WS      or game:GetService("Workspace")

    local lp = C.LocalPlayer or Players.LocalPlayer
    if not (lp and UI and UI.Tabs and UI.Tabs.Combat) then return end

    local tab = UI.Tabs.Combat

    C.Config        = C.Config or {}
    C.State         = C.State  or {}
    C.State.Toggles = C.State.Toggles or {}

    local aimlockOn    = C.State.Toggles.Aimlock or false
    local aimlockTarget = nil
    local aimlockConn   = nil
    local snapRadius   = tonumber(C.Config.AimlockSnapRadius) or 80
    local aimlockRange = tonumber(C.Config.AimlockRange)      or 150
    local SMOOTHING    = 0.12

    local lockPlayers  = C.State.Toggles.AimlockPlayers ~= false
    local lockNPCs     = C.State.Toggles.AimlockNPCs    or false

    local npcFolder    = nil

    local cam = WS.CurrentCamera

    local unlockGui = nil
    local unlockBtn = nil

    local hideUnlockButton
    local showUnlockButton

    local function buildUnlockButton()
        if unlockGui then return end

        local screenGui = Instance.new("ScreenGui")
        screenGui.Name           = "__AimlockUnlockGui"
        screenGui.ResetOnSpawn   = false
        screenGui.DisplayOrder   = 999
        screenGui.IgnoreGuiInset = true

        local btn = Instance.new("TextButton")
        btn.Size             = UDim2.new(0, 90, 0, 28)
        btn.Position         = UDim2.new(1, -100, 0.5, 80)
        btn.BackgroundColor3 = Color3.fromRGB(20, 20, 20)
        btn.BorderSizePixel  = 0
        btn.Text             = "Unlock"
        btn.TextColor3       = Color3.fromRGB(180, 255, 120)
        btn.TextSize         = 13
        btn.Font             = Enum.Font.GothamBold
        btn.AutoButtonColor  = true

        local corner = Instance.new("UICorner")
        corner.CornerRadius = UDim.new(0, 6)
        corner.Parent       = btn

        btn.Parent       = screenGui
        screenGui.Parent = lp.PlayerGui

        unlockBtn = btn
        unlockGui = screenGui

        btn.MouseButton1Click:Connect(function()
            aimlockTarget = nil
            hideUnlockButton()
        end)
    end

    hideUnlockButton = function()
        if unlockGui then
            unlockGui:Destroy()
            unlockGui = nil
            unlockBtn = nil
        end
    end

    showUnlockButton = function()
        if not unlockGui then
            buildUnlockButton()
        end
    end

    local function isOnScreen(worldPos)
        local screenPos, onScreen = cam:WorldToScreenPoint(worldPos)
        return onScreen, screenPos
    end

    local function getTargetPart(model)
        if not model then return nil end
        return model:FindFirstChild("Head") or model:FindFirstChild("HumanoidRootPart")
    end

    local function isAliveModel(model)
        if not model then return false end
        local hum = model:FindFirstChildOfClass("Humanoid")
        return hum and hum.Health > 0
    end

    local function getScreenCenter()
        local vp = cam.ViewportSize
        return Vector2.new(vp.X / 2, vp.Y / 2)
    end

    local function screenDistFromCenter(worldPos)
        local onScreen, screenPos = isOnScreen(worldPos)
        if not onScreen then return math.huge end
        local center = getScreenCenter()
        return (Vector2.new(screenPos.X, screenPos.Y) - center).Magnitude
    end

    local playerCharSet = {}

    local function rebuildPlayerCharSet()
        playerCharSet = {}
        for _, p in ipairs(Players:GetPlayers()) do
            if p.Character then
                playerCharSet[p.Character] = true
            end
        end
    end

    Players.PlayerAdded:Connect(function(p)
        p.CharacterAdded:Connect(function(ch)
            playerCharSet[ch] = true
        end)
    end)

    Players.PlayerRemoving:Connect(function(p)
        if p.Character then
            playerCharSet[p.Character] = nil
        end
    end)

    for _, p in ipairs(Players:GetPlayers()) do
        p.CharacterAdded:Connect(function(ch)
            playerCharSet[ch] = true
        end)
        if p.Character then
            playerCharSet[p.Character] = true
        end
    end

    local function isPlayerCharacter(model)
        return playerCharSet[model] == true
    end

    local function tryDetectNpcFolder(model)
        if npcFolder then return end
        local node = model.Parent
        while node and node ~= WS do
            if node ~= WS and node:IsA("Folder") or node:IsA("Model") then
                if node.Parent == WS then
                    npcFolder = node
                    return
                end
            end
            node = node.Parent
        end
    end

    local function getNPCSearchRoot()
        if npcFolder and npcFolder.Parent then
            return npcFolder
        end
        return WS
    end

    local function getCandidates()
        local candidates = {}

        if lockPlayers then
            for _, p in ipairs(Players:GetPlayers()) do
                if p == lp then continue end
                local ch = p.Character
                if ch and isAliveModel(ch) then
                    table.insert(candidates, ch)
                end
            end
        end

        if lockNPCs then
            local root = getNPCSearchRoot()
            for _, model in ipairs(root:GetChildren()) do
                if not model:IsA("Model") then continue end
                if isPlayerCharacter(model) then continue end
                if model == lp.Character then continue end
                if not isAliveModel(model) then continue end
                local part = getTargetPart(model)
                if not part then continue end
                table.insert(candidates, model)
            end
        end

        return candidates
    end

    local function findBestTarget()
        local best     = nil
        local bestDist = math.huge

        for _, model in ipairs(getCandidates()) do
            local part = getTargetPart(model)
            if not part then continue end

            local onScreen = isOnScreen(part.Position)
            if not onScreen then continue end

            local dist3D = (part.Position - cam.CFrame.Position).Magnitude
            if dist3D > aimlockRange then continue end

            local screenDist = screenDistFromCenter(part.Position)
            if screenDist < snapRadius and screenDist < bestDist then
                bestDist = screenDist
                best     = model
            end
        end

        return best
    end

    local function getTargetModel(target)
        if not target then return nil end
        for _, p in ipairs(Players:GetPlayers()) do
            if p.Character == target then
                return target
            end
        end
        return target
    end

    local function startAimlock()
        if aimlockConn then return end

        aimlockConn = Run.RenderStepped:Connect(function()
            if not aimlockOn then return end

            cam = WS.CurrentCamera

            if aimlockTarget then
                if not isAliveModel(aimlockTarget) then
                    aimlockTarget = nil
                    hideUnlockButton()
                    return
                end

                local part = getTargetPart(aimlockTarget)
                if not part then
                    aimlockTarget = nil
                    hideUnlockButton()
                    return
                end

                local onScreen = isOnScreen(part.Position)
                if not onScreen then
                    aimlockTarget = nil
                    hideUnlockButton()
                    return
                end

                local currentScreenDist = screenDistFromCenter(part.Position)
                local closer = findBestTarget()
                if closer and closer ~= aimlockTarget then
                    local closerPart = getTargetPart(closer)
                    if closerPart then
                        local closerDist = screenDistFromCenter(closerPart.Position)
                        if closerDist < currentScreenDist then
                            aimlockTarget = closer
                            part = closerPart
                        end
                    end
                end

                local activePart = getTargetPart(aimlockTarget)
                if not activePart then
                    aimlockTarget = nil
                    hideUnlockButton()
                    return
                end

                local targetCF  = CFrame.new(cam.CFrame.Position, activePart.Position)
                local currentCF = cam.CFrame

                local currentYaw   = math.atan2(-currentCF.LookVector.X, -currentCF.LookVector.Z)
                local targetYaw    = math.atan2(-targetCF.LookVector.X, -targetCF.LookVector.Z)
                local currentPitch = math.asin(math.clamp(currentCF.LookVector.Y, -1, 1))
                local targetPitch  = math.asin(math.clamp(targetCF.LookVector.Y,  -1, 1))

                local newYaw   = currentYaw   + (targetYaw   - currentYaw)   * SMOOTHING
                local newPitch = currentPitch + (targetPitch - currentPitch) * SMOOTHING

                newPitch = math.clamp(newPitch, -math.rad(80), math.rad(80))

                local newCF = CFrame.new(currentCF.Position)
                    * CFrame.Angles(0, newYaw, 0)
                    * CFrame.Angles(newPitch, 0, 0)

                cam.CFrame = newCF
            else
                local found = findBestTarget()
                if found then
                    aimlockTarget = found
                    if lockNPCs and not isPlayerCharacter(found) then
                        tryDetectNpcFolder(found)
                    end
                    showUnlockButton()
                end
            end
        end)
    end

    local function stopAimlock()
        if aimlockConn then aimlockConn:Disconnect(); aimlockConn = nil end
        aimlockTarget = nil
        hideUnlockButton()
        C.State.Toggles.Aimlock = false
        aimlockOn = false
    end

    rebuildPlayerCharSet()

    tab:Section({ Title = "Aimlock" })

    tab:Toggle({
        Title    = "Aimlock",
        Value    = aimlockOn,
        Callback = function(on)
            aimlockOn = (on == true)
            C.State.Toggles.Aimlock = aimlockOn
            if aimlockOn then
                rebuildPlayerCharSet()
                startAimlock()
            else
                stopAimlock()
            end
        end
    })

    tab:Toggle({
        Title    = "Lock Players",
        Value    = lockPlayers,
        Callback = function(on)
            lockPlayers = (on == true)
            C.State.Toggles.AimlockPlayers = lockPlayers
            if aimlockTarget and not lockPlayers and isPlayerCharacter(aimlockTarget) then
                aimlockTarget = nil
                hideUnlockButton()
            end
        end
    })

    tab:Toggle({
        Title    = "Lock NPCs",
        Value    = lockNPCs,
        Callback = function(on)
            lockNPCs = (on == true)
            C.State.Toggles.AimlockNPCs = lockNPCs
            if aimlockTarget and not lockNPCs and not isPlayerCharacter(aimlockTarget) then
                aimlockTarget = nil
                hideUnlockButton()
            end
        end
    })

    tab:Toggle({
        Title    = "Reset NPC Folder",
        Value    = false,
        Callback = function(on)
            if on then
                npcFolder = nil
            end
        end
    })

    tab:Slider({
        Title = "Snap Radius (px)",
        Value = {
            Min     = 20,
            Max     = 300,
            Default = snapRadius
        },
        Callback = function(v)
            local n = tonumber(type(v) == "table" and (v.Value or v.Current or v.Default) or v)
            if not n then return end
            n = math.clamp(n, 20, 300)
            snapRadius                 = n
            C.Config.AimlockSnapRadius = n
        end
    })

    tab:Slider({
        Title = "Max Range (studs)",
        Value = {
            Min     = 20,
            Max     = 500,
            Default = aimlockRange
        },
        Callback = function(v)
            local n = tonumber(type(v) == "table" and (v.Value or v.Current or v.Default) or v)
            if not n then return end
            n = math.clamp(n, 20, 500)
            aimlockRange          = n
            C.Config.AimlockRange = n
        end
    })

    lp.CharacterAdded:Connect(function()
        aimlockTarget = nil
        hideUnlockButton()
        rebuildPlayerCharSet()
        if aimlockOn and not aimlockConn then
            startAimlock()
        end
    end)
end
