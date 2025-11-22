-- player.lua
-- Universal hub • Player tab: movement + godmode

return function(C, R, UI)
    C  = C  or _G.C
    R  = R  or _G.R
    UI = UI or _G.UI

    local Services = C.Services or {}
    local Players  = Services.Players  or game:GetService("Players")
    local Run      = Services.Run      or game:GetService("RunService")
    local UIS      = Services.UIS      or game:GetService("UserInputService")
    local RS       = Services.RS       or game:GetService("ReplicatedStorage")
    local WS       = Services.WS       or game:GetService("Workspace")

    local lp = C.LocalPlayer or Players.LocalPlayer
    if not (lp and UI and UI.Tabs and UI.Tabs.Player) then return end

    local tab = UI.Tabs.Player

    C.Config         = C.Config or {}
    C.State          = C.State  or {}
    C.State.Toggles  = C.State.Toggles or {}

    ------------------------------------------------------------------------
    -- Helpers
    ------------------------------------------------------------------------

    local function getCharacter()
        return lp.Character or lp.CharacterAdded:Wait()
    end

    local function getHumanoid()
        local ch = getCharacter()
        return ch:FindFirstChildOfClass("Humanoid")
    end

    local function getRoot()
        local ch = getCharacter()
        return ch:FindFirstChild("HumanoidRootPart")
    end

    ------------------------------------------------------------------------
    -- Movement: WalkSpeed / JumpPower
    ------------------------------------------------------------------------

    local DEFAULT_SPEED     = 16
    local DEFAULT_JUMPPOWER = 50

    local function applyMovementConfig()
        local hum = getHumanoid()
        if not hum then return end

        local ws  = tonumber(C.Config.WalkSpeed)  or DEFAULT_SPEED
        local jp  = tonumber(C.Config.JumpPower) or DEFAULT_JUMPPOWER

        hum.UseJumpPower = true
        hum.WalkSpeed    = ws
        hum.JumpPower    = jp
    end

    tab:Section({ Title = "Movement" })

    tab:Slider({
        Title = "Walk Speed",
        Value = {
            Min     = 8,
            Max     = 120,
            Default = tonumber(C.Config.WalkSpeed) or DEFAULT_SPEED
        },
        Callback = function(v)
            local n = tonumber(type(v) == "table" and (v.Value or v.Current or v.Default) or v)
            if not n then return end
            n = math.clamp(n, 8, 120)
            C.Config.WalkSpeed = n
            local hum = getHumanoid()
            if hum then hum.WalkSpeed = n end
        end
    })

    tab:Slider({
        Title = "Jump Power",
        Value = {
            Min     = 25,
            Max     = 200,
            Default = tonumber(C.Config.JumpPower) or DEFAULT_JUMPPOWER
        },
        Callback = function(v)
            local n = tonumber(type(v) == "table" and (v.Value or v.Current or v.Default) or v)
            if not n then return end
            n = math.clamp(n, 25, 200)
            C.Config.JumpPower = n
            local hum = getHumanoid()
            if hum then
                hum.UseJumpPower = true
                hum.JumpPower    = n
            end
        end
    })

    ------------------------------------------------------------------------
    -- Infinite Jump
    ------------------------------------------------------------------------

    local infJumpOn  = C.State.Toggles.InfiniteJump or false
    local infJumpCon = nil

    local function enableInfiniteJump()
        if infJumpOn then return end
        infJumpOn = true
        C.State.Toggles.InfiniteJump = true

        if infJumpCon then
            infJumpCon:Disconnect()
            infJumpCon = nil
        end

        infJumpCon = UIS.JumpRequest:Connect(function()
            if not infJumpOn then return end
            local hum = getHumanoid()
            if hum then
                pcall(function()
                    hum:ChangeState(Enum.HumanoidStateType.Jumping)
                end)
            end
        end)
    end

    local function disableInfiniteJump()
        infJumpOn = false
        C.State.Toggles.InfiniteJump = false
        if infJumpCon then
            infJumpCon:Disconnect()
            infJumpCon = nil
        end
    end

    tab:Toggle({
        Title   = "Infinite Jump",
        Value   = infJumpOn,
        Callback = function(on)
            if on then enableInfiniteJump() else disableInfiniteJump() end
        end
    })

    ------------------------------------------------------------------------
    -- Fly (desktop-style, with slight forward tilt, no sideways flatten)
    ------------------------------------------------------------------------

    tab:Section({ Title = "Fly" })

    local flyOn        = C.State.Toggles.Fly or false
    local flySpeed     = C.Config.FlySpeed or 60
    local flyBV        = nil
    local flyBG        = nil
    local flyHB        = nil
    local flyInputCon  = nil

    local moveDir      = Vector3.new()
    local verticalDir  = 0

    local function destroyFlyBodies()
        if flyBV then flyBV:Destroy() flyBV = nil end
        if flyBG then flyBG:Destroy() flyBG = nil end
    end

    local function stopFly()
        flyOn = false
        C.State.Toggles.Fly = false

        if flyHB then flyHB:Disconnect() flyHB = nil end
        if flyInputCon then flyInputCon:Disconnect() flyInputCon = nil end
        destroyFlyBodies()

        local hum = getHumanoid()
        if hum then
            pcall(function()
                hum.PlatformStand = false
            end)
        end
        moveDir = Vector3.new()
        verticalDir = 0
    end

    local function ensureFlyBodies(root)
        if not flyBV or not flyBV.Parent then
            flyBV = Instance.new("BodyVelocity")
            flyBV.Velocity = Vector3.new()
            flyBV.MaxForce = Vector3.new(1e5, 1e5, 1e5)
            flyBV.Name     = "__FlyBV"
            flyBV.Parent   = root
        end
        if not flyBG or not flyBG.Parent then
            flyBG = Instance.new("BodyGyro")
            flyBG.D = 1000
            flyBG.P = 1e4
            flyBG.MaxTorque = Vector3.new(1e5, 1e5, 1e5)
            flyBG.Name      = "__FlyBG"
            flyBG.Parent    = root
        end
    end

    local function beginFly()
        if flyOn then return end
        local root = getRoot()
        local hum  = getHumanoid()
        if not (root and hum) then return end

        flyOn = true
        C.State.Toggles.Fly = true
        moveDir     = Vector3.new()
        verticalDir = 0

        hum.PlatformStand = true
        ensureFlyBodies(root)

        if flyInputCon then
            flyInputCon:Disconnect()
            flyInputCon = nil
        end

        flyInputCon = UIS.InputBegan:Connect(function(input, gp)
            if gp then return end
            if input.KeyCode == Enum.KeyCode.W then
                moveDir = Vector3.new(moveDir.X, moveDir.Y, -1)
            elseif input.KeyCode == Enum.KeyCode.S then
                moveDir = Vector3.new(moveDir.X, moveDir.Y,  1)
            elseif input.KeyCode == Enum.KeyCode.A then
                moveDir = Vector3.new(-1, moveDir.Y, moveDir.Z)
            elseif input.KeyCode == Enum.KeyCode.D then
                moveDir = Vector3.new( 1, moveDir.Y, moveDir.Z)
            elseif input.KeyCode == Enum.KeyCode.Space then
                verticalDir = 1
            elseif input.KeyCode == Enum.KeyCode.LeftControl
                or input.KeyCode == Enum.KeyCode.LeftShift then
                verticalDir = -1
            elseif input.KeyCode == Enum.KeyCode.F then
                -- F toggles fly
                if flyOn then
                    stopFly()
                else
                    beginFly()
                end
            end
        end)

        UIS.InputEnded:Connect(function(input, gp)
            if gp then return end
            if input.KeyCode == Enum.KeyCode.W or input.KeyCode == Enum.KeyCode.S then
                moveDir = Vector3.new(moveDir.X, moveDir.Y, 0)
            elseif input.KeyCode == Enum.KeyCode.A or input.KeyCode == Enum.KeyCode.D then
                moveDir = Vector3.new(0, moveDir.Y, moveDir.Z)
            elseif input.KeyCode == Enum.KeyCode.Space
                or input.KeyCode == Enum.KeyCode.LeftControl
                or input.KeyCode == Enum.KeyCode.LeftShift then
                verticalDir = 0
            end
        end)

        if flyHB then
            flyHB:Disconnect()
            flyHB = nil
        end

        flyHB = Run.RenderStepped:Connect(function()
            if not flyOn then return end
            local rootNow = getRoot()
            if not rootNow then
                stopFly()
                return
            end
            ensureFlyBodies(rootNow)

            local cam = WS.CurrentCamera
            if not cam then return end

            -- Horizontal move based on camera
            local cf   = cam.CFrame
            local look = cf.LookVector
            local right = cf.RightVector

            local horiz = (look * -moveDir.Z) + (right * moveDir.X)
            horiz = Vector3.new(horiz.X, 0, horiz.Z)

            local dir = horiz.Magnitude > 1e-3 and horiz.Unit or Vector3.new()
            local vel = dir * flySpeed + Vector3.new(0, verticalDir * flySpeed, 0)

            flyBV.Velocity = vel

            -- Keep up vector global Y; add a small forward tilt
            local faceAt = rootNow.Position + look
            local baseCF = CFrame.lookAt(rootNow.Position, faceAt, Vector3.yAxis)
            local tilt   = CFrame.Angles(math.rad(-5), 0, 0) -- slight forward tilt
            flyBG.CFrame = baseCF * tilt
        end)
    end

    tab:Toggle({
        Title = "Fly (F to toggle)",
        Value = flyOn,
        Callback = function(on)
            if on then
                beginFly()
            else
                stopFly()
            end
        end
    })

    tab:Slider({
        Title = "Fly Speed",
        Value = {
            Min     = 20,
            Max     = 200,
            Default = flySpeed
        },
        Callback = function(v)
            local n = tonumber(type(v) == "table" and (v.Value or v.Current or v.Default) or v)
            if not n then return end
            n = math.clamp(n, 20, 200)
            flySpeed        = n
            C.Config.FlySpeed = n
        end
    })

    ------------------------------------------------------------------------
    -- Godmode (DamagePlayer remote)
    -- Two modes: Negative damage and Positive heal
    ------------------------------------------------------------------------

    tab:Section({ Title = "Godmode" })

    local function getDamageRemote()
        local folder = RS:FindFirstChild("RemoteEvents") or RS:FindFirstChild("Events") or RS
        if not folder then return nil end
        local ev = folder:FindFirstChild("DamagePlayer") or folder:FindFirstChild("Damage")
        return ev
    end

    local GOD_INTERVAL = 0.5

    local godNegOn     = C.State.Toggles.GodmodeNegative or false
    local godPosOn     = C.State.Toggles.GodmodePositive or false
    local negConn      = nil
    local posConn      = nil
    local negAcc       = 0
    local posAcc       = 0

    local function stopGodNegative()
        godNegOn = false
        C.State.Toggles.GodmodeNegative = false
        if negConn then
            negConn:Disconnect()
            negConn = nil
        end
        negAcc = 0
    end

    local function stopGodPositive()
        godPosOn = false
        C.State.Toggles.GodmodePositive = false
        if posConn then
            posConn:Disconnect()
            posConn = nil
        end
        posAcc = 0
    end

    local function startGodNegative()
        if godNegOn then return end

        local ev = getDamageRemote()
        if not (ev and ev:IsA("RemoteEvent")) then return end

        -- Ensure the other mode is off
        if godPosOn then
            stopGodPositive()
        end

        godNegOn = true
        C.State.Toggles.GodmodeNegative = true
        negAcc = 0

        local function tick()
            pcall(function()
                ev:FireServer(-math.huge)
            end)
        end

        tick()

        if negConn then
            negConn:Disconnect()
            negConn = nil
        end

        negConn = Run.Heartbeat:Connect(function(dt)
            if not godNegOn then return end
            negAcc = negAcc + dt
            if negAcc >= GOD_INTERVAL then
                negAcc = 0
                tick()
            end
        end)
    end

    local function startGodPositive()
        if godPosOn then return end

        local ev = getDamageRemote()
        if not (ev and ev:IsA("RemoteEvent")) then return end

        -- Ensure the other mode is off
        if godNegOn then
            stopGodNegative()
        end

        godPosOn = true
        C.State.Toggles.GodmodePositive = true
        posAcc = 0

        local function tick()
            pcall(function()
                ev:FireServer(math.huge)
            end)
        end

        tick()

        if posConn then
            posConn:Disconnect()
            posConn = nil
        end

        posConn = Run.Heartbeat:Connect(function(dt)
            if not godPosOn then return end
            posAcc = posAcc + dt
            if posAcc >= GOD_INTERVAL then
                posAcc = 0
                tick()
            end
        end)
    end

    tab:Toggle({
        Title = "Godmode (Negative Damage)",
        Value = godNegOn,
        Callback = function(on)
            if on then
                startGodNegative()
            else
                stopGodNegative()
            end
        end
    })

    tab:Toggle({
        Title = "Godmode (Positive Heal)",
        Value = godPosOn,
        Callback = function(on)
            if on then
                startGodPositive()
            else
                stopGodPositive()
            end
        end
    })

    ------------------------------------------------------------------------
    -- Character respawn handling: re-apply movement + re-arm godmode if on
    ------------------------------------------------------------------------

    lp.CharacterAdded:Connect(function()
        task.defer(function()
            applyMovementConfig()

            if infJumpOn then
                enableInfiniteJump()
            end

            if flyOn then
                beginFly()
            end

            if godNegOn then
                startGodNegative()
            elseif godPosOn then
                startGodPositive()
            end
        end)
    end)

    -- Initial apply on first load
    task.defer(function()
        applyMovementConfig()

        if infJumpOn then
            enableInfiniteJump()
        end

        if flyOn then
            beginFly()
        end

        -- Per your request, both godmodes default OFF
        -- but if state was persisted, re-arm them:
        if godNegOn then
            startGodNegative()
        elseif godPosOn then
            startGodPositive()
        end
    end)
end
