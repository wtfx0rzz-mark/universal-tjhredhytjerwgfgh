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
    local PPS      = Services.PPS      or game:GetService("ProximityPromptService")

    local lp = C.LocalPlayer or Players.LocalPlayer
    if not (lp and UI and UI.Tabs and UI.Tabs.Player) then return end

    local tab = UI.Tabs.Player

    C.Config         = C.Config or {}
    C.State          = C.State  or {}
    C.State.Toggles  = C.State.Toggles or {}

    local function getCharacter()
        return lp.Character or lp.CharacterAdded:Wait()
    end

    local function getHumanoid()
        local ch = lp.Character or lp.CharacterAdded:Wait()
        return ch:FindFirstChildOfClass("Humanoid")
    end

    local function getRoot()
        local ch = lp.Character or lp.CharacterAdded:Wait()
        return ch:FindFirstChild("HumanoidRootPart")
    end

    local DEFAULT_SPEED     = 50
    local DEFAULT_JUMPPOWER = 50

    local function applyMovementConfig()
        local hum = getHumanoid()
        if not hum then return end
        local ws = tonumber(C.Config.WalkSpeed)  or DEFAULT_SPEED
        local jp = tonumber(C.Config.JumpPower) or DEFAULT_JUMPPOWER
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
            local hum = lp.Character and lp.Character:FindFirstChildOfClass("Humanoid")
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
            local hum = lp.Character and lp.Character:FindFirstChildOfClass("Humanoid")
            if hum then
                hum.UseJumpPower = true
                hum.JumpPower    = n
            end
        end
    })

    local infJumpOn  = C.State.Toggles.InfiniteJump or false
    local infJumpCon = nil

    local function enableInfiniteJump()
        if infJumpOn then return end
        infJumpOn = true
        C.State.Toggles.InfiniteJump = true
        if infJumpCon then infJumpCon:Disconnect(); infJumpCon = nil end
        infJumpCon = UIS.JumpRequest:Connect(function()
            if not infJumpOn then return end
            local hum = lp.Character and lp.Character:FindFirstChildOfClass("Humanoid")
            if hum then
                pcall(function() hum:ChangeState(Enum.HumanoidStateType.Jumping) end)
            end
        end)
    end

    local function disableInfiniteJump()
        infJumpOn = false
        C.State.Toggles.InfiniteJump = false
        if infJumpCon then infJumpCon:Disconnect(); infJumpCon = nil end
    end

    tab:Toggle({
        Title    = "Infinite Jump",
        Value    = infJumpOn,
        Callback = function(on)
            if on then enableInfiniteJump() else disableInfiniteJump() end
        end
    })

    tab:Section({ Title = "Fly" })

    local flySpeed    = tonumber(C.Config.FlySpeed) or 60
    C.Config.FlySpeed = flySpeed

    local flyEnabled  = C.State.Toggles.Fly or false
    local forceFlyOn  = C.State.Toggles.ForceFly or false

    local FLYING         = false
    local bodyGyro       = nil
    local bodyVelocity   = nil
    local flyRenderConn  = nil
    local flyHealConn    = nil

    local startForceFly, stopForceFly

    local function stopMobileFly()
        if not FLYING then return end
        FLYING = false

        if flyRenderConn then flyRenderConn:Disconnect(); flyRenderConn = nil end
        if flyHealConn   then flyHealConn:Disconnect();   flyHealConn   = nil end

        if bodyVelocity then bodyVelocity:Destroy(); bodyVelocity = nil end
        if bodyGyro     then bodyGyro:Destroy();     bodyGyro     = nil end

        local ch  = lp.Character
        local hum = ch and ch:FindFirstChildOfClass("Humanoid")
        if hum then pcall(function() hum.PlatformStand = false end) end
    end

    local function ensureFlyBodies(root)
        if not bodyGyro or not bodyGyro.Parent then
            bodyGyro = Instance.new("BodyGyro")
            bodyGyro.MaxTorque = Vector3.new(9e9, 9e9, 9e9)
            bodyGyro.P         = 1000
            bodyGyro.D         = 50
            bodyGyro.CFrame    = root.CFrame
            bodyGyro.Name      = "__MobileFlyBG"
            bodyGyro.Parent    = root
        end

        if not bodyVelocity or not bodyVelocity.Parent then
            bodyVelocity = Instance.new("BodyVelocity")
            bodyVelocity.MaxForce = Vector3.new(9e9, 9e9, 9e9)
            bodyVelocity.Velocity = Vector3.new()
            bodyVelocity.Name     = "__MobileFlyBV"
            bodyVelocity.Parent   = root
        end
    end

    local function startMobileFly()
        if FLYING then return end

        local ch   = lp.Character
        local hum  = ch and ch:FindFirstChildOfClass("Humanoid")
        local root = ch and ch:FindFirstChild("HumanoidRootPart")
        local cam  = WS.CurrentCamera

        if not (hum and root and cam) then return end

        FLYING = true
        hum.PlatformStand = true
        ensureFlyBodies(root)

        if flyRenderConn then flyRenderConn:Disconnect(); flyRenderConn = nil end

        flyRenderConn = Run.RenderStepped:Connect(function()
            if not FLYING then return end

            local ch2   = lp.Character
            local hum2  = ch2 and ch2:FindFirstChildOfClass("Humanoid")
            local root2 = ch2 and ch2:FindFirstChild("HumanoidRootPart")
            local cam2  = WS.CurrentCamera

            if not (hum2 and root2 and cam2) then return end

            hum2.PlatformStand = true
            ensureFlyBodies(root2)
            bodyGyro.CFrame = cam2.CFrame

            local move = Vector3.new()
            local ok, controlModule = pcall(function()
                return require(lp.PlayerScripts:WaitForChild("PlayerModule"):WaitForChild("ControlModule"))
            end)
            if ok and controlModule and controlModule.GetMoveVector then
                move = controlModule:GetMoveVector()
            end

            local vel = Vector3.new()
            vel = vel + cam2.CFrame.RightVector * (move.X * flySpeed)
            vel = vel - cam2.CFrame.LookVector  * (move.Z * flySpeed)

            bodyVelocity.Velocity = vel
        end)

        if flyHealConn then flyHealConn:Disconnect(); flyHealConn = nil end

        flyHealConn = Run.Heartbeat:Connect(function()
            if not flyEnabled then return end
            if not FLYING then
                startMobileFly()
                return
            end

            local ch2   = lp.Character
            local hum2  = ch2 and ch2:FindFirstChildOfClass("Humanoid")
            local root2 = ch2 and ch2:FindFirstChild("HumanoidRootPart")

            if not (hum2 and root2) then return end

            if not hum2.PlatformStand then
                hum2.PlatformStand = true
            end

            ensureFlyBodies(root2)

            if not bodyVelocity or not bodyVelocity.Parent then
                bodyVelocity = Instance.new("BodyVelocity")
                bodyVelocity.MaxForce = Vector3.new(9e9, 9e9, 9e9)
                bodyVelocity.Velocity = Vector3.new()
                bodyVelocity.Name     = "__MobileFlyBV"
                bodyVelocity.Parent   = root2
            end

            if not bodyGyro or not bodyGyro.Parent then
                bodyGyro = Instance.new("BodyGyro")
                bodyGyro.MaxTorque = Vector3.new(9e9, 9e9, 9e9)
                bodyGyro.P         = 1000
                bodyGyro.D         = 50
                bodyGyro.CFrame    = root2.CFrame
                bodyGyro.Name      = "__MobileFlyBG"
                bodyGyro.Parent    = root2
            end
        end)
    end

    local function startFly()
        flyEnabled = true
        C.State.Toggles.Fly = true
        if forceFlyOn and stopForceFly then stopForceFly() end
        startMobileFly()
    end

    local function stopFly()
        flyEnabled = false
        C.State.Toggles.Fly = false
        stopMobileFly()
    end

    local forceFlyConn     = nil
    local forceFlyHealConn = nil
    local ffGyro           = nil
    local ffVel            = nil
    local forceHeldPos     = nil

    startForceFly = function()
        if forceFlyConn then return end

        local ch   = lp.Character
        local hum  = ch and ch:FindFirstChildOfClass("Humanoid")
        local root = ch and ch:FindFirstChild("HumanoidRootPart")

        if not (hum and root) then return end

        if flyEnabled then stopFly() end

        forceFlyOn = true
        C.State.Toggles.ForceFly = true

        forceHeldPos = root.Position

        hum.PlatformStand = true

        ffGyro = Instance.new("BodyGyro")
        ffGyro.MaxTorque = Vector3.new(9e9, 9e9, 9e9)
        ffGyro.P         = 3000
        ffGyro.D         = 200
        ffGyro.CFrame    = root.CFrame
        ffGyro.Name      = "__ForceFlyBG"
        ffGyro.Parent    = root

        ffVel = Instance.new("BodyVelocity")
        ffVel.MaxForce = Vector3.new(9e9, 9e9, 9e9)
        ffVel.Velocity = Vector3.new()
        ffVel.Name     = "__ForceFlyBV"
        ffVel.Parent   = root

        if forceFlyConn then forceFlyConn:Disconnect(); forceFlyConn = nil end

        forceFlyConn = Run.RenderStepped:Connect(function()
            if not forceFlyOn then return end

            local ch2   = lp.Character
            local hum2  = ch2 and ch2:FindFirstChildOfClass("Humanoid")
            local root2 = ch2 and ch2:FindFirstChild("HumanoidRootPart")
            local cam2  = WS.CurrentCamera

            if not (hum2 and root2 and cam2) then return end

            hum2.PlatformStand = true

            if not ffGyro or not ffGyro.Parent then
                ffGyro = Instance.new("BodyGyro")
                ffGyro.MaxTorque = Vector3.new(9e9, 9e9, 9e9)
                ffGyro.P         = 3000
                ffGyro.D         = 200
                ffGyro.CFrame    = root2.CFrame
                ffGyro.Name      = "__ForceFlyBG"
                ffGyro.Parent    = root2
            end

            if not ffVel or not ffVel.Parent then
                ffVel = Instance.new("BodyVelocity")
                ffVel.MaxForce = Vector3.new(9e9, 9e9, 9e9)
                ffVel.Velocity = Vector3.new()
                ffVel.Name     = "__ForceFlyBV"
                ffVel.Parent   = root2
            end

            local move = Vector3.new()
            local ok, controlModule = pcall(function()
                return require(lp.PlayerScripts:WaitForChild("PlayerModule"):WaitForChild("ControlModule"))
            end)
            if ok and controlModule and controlModule.GetMoveVector then
                move = controlModule:GetMoveVector()
            end

            local cam2CF  = cam2.CFrame
            local look    = cam2CF.LookVector
            local right   = cam2CF.RightVector
            local lookY   = look.Y

            local vel      = Vector3.new()
            local isMoving = move.Magnitude > 1e-3

            if isMoving then
                vel = vel + right * (move.X * flySpeed)
                vel = vel - look  * (move.Z * flySpeed)

                local PITCH_DEADZONE = 0.22
                local a = math.abs(lookY)
                if a > PITCH_DEADZONE then
                    local t = (a - PITCH_DEADZONE) / (1 - PITCH_DEADZONE)
                    vel = vel + Vector3.new(0, (lookY > 0 and 1 or -1) * t * flySpeed, 0)
                end

                forceHeldPos = root2.Position
            else
                local diff = forceHeldPos - root2.Position
                if diff.Magnitude > 0.05 then
                    vel = diff * 20
                else
                    vel = Vector3.new()
                    root2.AssemblyLinearVelocity  = Vector3.new()
                    root2.AssemblyAngularVelocity = Vector3.new()
                end
            end

            ffVel.Velocity = vel

            local flatLook = Vector3.new(look.X, 0, look.Z)
            if flatLook.Magnitude > 1e-3 then
                ffGyro.CFrame = CFrame.new(Vector3.zero, flatLook.Unit)
            end
        end)

        if forceFlyHealConn then forceFlyHealConn:Disconnect(); forceFlyHealConn = nil end

        forceFlyHealConn = Run.Heartbeat:Connect(function()
            if not forceFlyOn then return end

            local ch2   = lp.Character
            local hum2  = ch2 and ch2:FindFirstChildOfClass("Humanoid")
            local root2 = ch2 and ch2:FindFirstChild("HumanoidRootPart")

            if not (hum2 and root2) then return end

            if not hum2.PlatformStand then
                hum2.PlatformStand = true
            end

            if not ffGyro or not ffGyro.Parent then
                ffGyro = Instance.new("BodyGyro")
                ffGyro.MaxTorque = Vector3.new(9e9, 9e9, 9e9)
                ffGyro.P         = 3000
                ffGyro.D         = 200
                ffGyro.CFrame    = root2.CFrame
                ffGyro.Name      = "__ForceFlyBG"
                ffGyro.Parent    = root2
            end

            if not ffVel or not ffVel.Parent then
                ffVel = Instance.new("BodyVelocity")
                ffVel.MaxForce = Vector3.new(9e9, 9e9, 9e9)
                ffVel.Velocity = Vector3.new()
                ffVel.Name     = "__ForceFlyBV"
                ffVel.Parent   = root2
            end

            if not forceFlyConn then
                startForceFly()
            end
        end)
    end

    stopForceFly = function()
        if forceFlyConn     then forceFlyConn:Disconnect();     forceFlyConn     = nil end
        if forceFlyHealConn then forceFlyHealConn:Disconnect(); forceFlyHealConn = nil end

        local root = lp.Character and lp.Character:FindFirstChild("HumanoidRootPart")
        if root then
            local bg = root:FindFirstChild("__ForceFlyBG")
            local bv = root:FindFirstChild("__ForceFlyBV")
            if bg then bg:Destroy() end
            if bv then bv:Destroy() end
            root.AssemblyLinearVelocity  = Vector3.new()
            root.AssemblyAngularVelocity = Vector3.new()
        end

        if ffGyro then pcall(function() ffGyro:Destroy() end); ffGyro = nil end
        if ffVel  then pcall(function() ffVel:Destroy()  end); ffVel  = nil end

        local hum = lp.Character and lp.Character:FindFirstChildOfClass("Humanoid")
        if hum then pcall(function() hum.PlatformStand = false end) end

        forceHeldPos = nil
        forceFlyOn   = false
        C.State.Toggles.ForceFly = false
    end

    local flyToggleCtrl, forceFlyToggleCtrl

    flyToggleCtrl = tab:Toggle({
        Title    = "Fly (Mobile)",
        Value    = flyEnabled,
        Callback = function(on)
            on = (on == true)
            if on then
                if forceFlyOn then
                    stopForceFly()
                    if forceFlyToggleCtrl and forceFlyToggleCtrl.Set then
                        pcall(function() forceFlyToggleCtrl:Set(false) end)
                    end
                end
                startFly()
            else
                stopFly()
            end
        end
    })

    tab:Slider({
        Title = "Fly Speed",
        Value = {
            Min     = 20,
            Max     = 400,
            Default = flySpeed
        },
        Callback = function(v)
            local n = tonumber(type(v) == "table" and (v.Value or v.Current or v.Default) or v)
            if not n then return end
            n = math.clamp(n, 20, 400)
            flySpeed          = n
            C.Config.FlySpeed = n
        end
    })

    forceFlyToggleCtrl = tab:Toggle({
        Title    = "Force Fly",
        Value    = forceFlyOn,
        Callback = function(on)
            on = (on == true)
            if on then
                if flyEnabled then
                    stopFly()
                    if flyToggleCtrl and flyToggleCtrl.Set then
                        pcall(function() flyToggleCtrl:Set(false) end)
                    end
                end
                startForceFly()
            else
                stopForceFly()
            end
        end
    })

    tab:Section({ Title = "Noclip" })

    local noclipOn = C.State.Toggles.Noclip or false

    local function applyNoclipToCharacter(ch)
        if not ch then return end
        for _, d in ipairs(ch:GetDescendants()) do
            if d:IsA("BasePart") then
                d.CanCollide = false
            end
        end
    end

    local function enableNoclip()
        if noclipOn then return end
        noclipOn = true
        C.State.Toggles.Noclip = true
        applyNoclipToCharacter(lp.Character)
    end

    local function disableNoclip()
        noclipOn = false
        C.State.Toggles.Noclip = false
        local ch = lp.Character
        if not ch then return end
        for _, d in ipairs(ch:GetDescendants()) do
            if d:IsA("BasePart") then
                d.CanCollide = true
            end
        end
    end

    tab:Toggle({
        Title    = "Noclip",
        Value    = noclipOn,
        Callback = function(on)
            if on then enableNoclip() else disableNoclip() end
        end
    })

    tab:Section({ Title = "Interactions" })

    local instantOn = (C.State.Toggles.InstantInteract ~= false)
    C.State.Toggles.InstantInteract = instantOn

    local INSTANT_HOLD, TRIGGER_COOLDOWN = 0.2, 0.2
    local EXCLUDE_NAME_SUBSTR     = { "door", "closet", "gate", "hatch" }
    local EXCLUDE_ANCESTOR_SUBSTR = { "closetdoors", "closet", "door", "landmarks" }

    local UID_OPEN_KEY = tostring(lp.UserId) .. "Opened"

    local function strfindAny(s, list)
        s = string.lower(s or "")
        for _, w in ipairs(list) do
            if string.find(s, w, 1, true) then return true end
        end
        return false
    end

    local function shouldSkipPrompt(p)
        if not p or not p.Parent then return true end
        if strfindAny(p.Name, EXCLUDE_NAME_SUBSTR) then return true end
        pcall(function()
            if strfindAny(p.ObjectText, EXCLUDE_NAME_SUBSTR) then error(true) end
            if strfindAny(p.ActionText, EXCLUDE_NAME_SUBSTR) then error(true) end
        end)
        local a = p.Parent
        while a and a ~= workspace do
            if strfindAny(a.Name, EXCLUDE_ANCESTOR_SUBSTR) then return true end
            a = a.Parent
        end
        return false
    end

    local promptDurations = setmetatable({}, { __mode = "k" })
    local shownConn, trigConn, hiddenConn

    local function restorePrompt(prompt)
        local orig = promptDurations[prompt]
        if orig ~= nil and prompt and prompt.Parent then
            pcall(function() prompt.HoldDuration = orig end)
        end
        promptDurations[prompt] = nil
    end

    local function tagChestFromPrompt(prompt)
        if not prompt then return end
        local node = prompt
        for _ = 1, 8 do
            if not node then break end
            if node:IsA("Model") then
                local n = node.Name
                if type(n) == "string" and (n:match("Chest%d*$") or n:match("Chest$")) then
                    pcall(function() node:SetAttribute(UID_OPEN_KEY, true) end)
                    break
                end
            end
            node = node.Parent
        end
    end

    local function onPromptShown(prompt)
        if not prompt or not prompt:IsA("ProximityPrompt") then return end
        if shouldSkipPrompt(prompt) then return end
        if promptDurations[prompt] == nil then
            promptDurations[prompt] = prompt.HoldDuration
        end
        if prompt and prompt.Parent and not shouldSkipPrompt(prompt) then
            pcall(function() prompt.HoldDuration = INSTANT_HOLD end)
        end
    end

    local function enableInstantInteract()
        if shownConn then return end
        shownConn = PPS.PromptShown:Connect(onPromptShown)

        trigConn = PPS.PromptTriggered:Connect(function(prompt, player)
            if player ~= lp or shouldSkipPrompt(prompt) then return end
            tagChestFromPrompt(prompt)
            if TRIGGER_COOLDOWN and TRIGGER_COOLDOWN > 0 then
                pcall(function() prompt.Enabled = false end)
                task.delay(TRIGGER_COOLDOWN, function()
                    if prompt and prompt.Parent then
                        pcall(function() prompt.Enabled = true end)
                    end
                end)
            end
            restorePrompt(prompt)
        end)

        hiddenConn = PPS.PromptHidden:Connect(function(prompt)
            if shouldSkipPrompt(prompt) then return end
            restorePrompt(prompt)
        end)
    end

    local function disableInstantInteract()
        if shownConn   then shownConn:Disconnect();   shownConn   = nil end
        if trigConn    then trigConn:Disconnect();     trigConn    = nil end
        if hiddenConn  then hiddenConn:Disconnect();   hiddenConn  = nil end
        for p, _ in pairs(promptDurations) do
            restorePrompt(p)
        end
    end

    if instantOn then enableInstantInteract() end

    tab:Toggle({
        Title    = "Instant Interact",
        Value    = instantOn,
        Callback = function(state)
            instantOn = (state == true)
            C.State.Toggles.InstantInteract = instantOn
            if instantOn then
                enableInstantInteract()
            else
                disableInstantInteract()
            end
        end
    })

    tab:Section({ Title = "Godmode" })

    local function getDamageRemote()
        local folder = RS:FindFirstChild("RemoteEvents") or RS:FindFirstChild("Events") or RS
        if not folder then return nil end
        return folder:FindFirstChild("DamagePlayer") or folder:FindFirstChild("Damage")
    end

    local GOD_INTERVAL = 0.5

    local godNegOn = C.State.Toggles.GodmodeNegative or false
    local godPosOn = C.State.Toggles.GodmodePositive or false
    local negConn  = nil
    local posConn  = nil
    local negAcc   = 0
    local posAcc   = 0

    local function stopGodNegative()
        godNegOn = false
        C.State.Toggles.GodmodeNegative = false
        if negConn then negConn:Disconnect(); negConn = nil end
        negAcc = 0
    end

    local function stopGodPositive()
        godPosOn = false
        C.State.Toggles.GodmodePositive = false
        if posConn then posConn:Disconnect(); posConn = nil end
        posAcc = 0
    end

    local function startGodNegative()
        if godNegOn then return end
        local ev = getDamageRemote()
        if not (ev and ev:IsA("RemoteEvent")) then return end
        if godPosOn then stopGodPositive() end

        godNegOn = true
        C.State.Toggles.GodmodeNegative = true
        negAcc = 0

        local function tick()
            pcall(function() ev:FireServer(-math.huge) end)
        end

        tick()

        if negConn then negConn:Disconnect(); negConn = nil end

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
        if godNegOn then stopGodNegative() end

        godPosOn = true
        C.State.Toggles.GodmodePositive = true
        posAcc = 0

        local function tick()
            pcall(function() ev:FireServer(math.huge) end)
        end

        tick()

        if posConn then posConn:Disconnect(); posConn = nil end

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
        Title    = "Godmode (Negative Damage)",
        Value    = godNegOn,
        Callback = function(on)
            if on then startGodNegative() else stopGodNegative() end
        end
    })

    tab:Toggle({
        Title    = "Godmode (Positive Heal)",
        Value    = godPosOn,
        Callback = function(on)
            if on then startGodPositive() else stopGodPositive() end
        end
    })

    lp.CharacterAdded:Connect(function()
        task.defer(function()
            applyMovementConfig()

            if infJumpOn then enableInfiniteJump() end

            if forceFlyOn then
                startForceFly()
            elseif flyEnabled then
                startFly()
            end

            if noclipOn then applyNoclipToCharacter(lp.Character) end

            if godNegOn then
                startGodNegative()
            elseif godPosOn then
                startGodPositive()
            end

            if instantOn and not shownConn then
                enableInstantInteract()
            elseif (not instantOn) and shownConn then
                disableInstantInteract()
            end
        end)
    end)

    task.defer(function()
        applyMovementConfig()

        if infJumpOn then enableInfiniteJump() end

        if forceFlyOn then
            startForceFly()
        elseif flyEnabled then
            startFly()
        end

        if noclipOn then applyNoclipToCharacter(lp.Character) end

        if godNegOn then
            startGodNegative()
        elseif godPosOn then
            startGodPositive()
        end

        if instantOn and not shownConn then
            enableInstantInteract()
        elseif (not instantOn) and shownConn then
            disableInstantInteract()
        end
    end)

    if not C.State.__PlayerMaintainConn then
        local acc = 0
        C.State.__PlayerMaintainConn = Run.Heartbeat:Connect(function(dt)
            acc += dt
            if acc < 0.25 then return end
            acc = 0

            local ch  = lp.Character
            local hum = ch and ch:FindFirstChildOfClass("Humanoid")

            if hum then
                local ws = tonumber(C.Config.WalkSpeed)  or DEFAULT_SPEED
                local jp = tonumber(C.Config.JumpPower) or DEFAULT_JUMPPOWER

                if math.abs(hum.WalkSpeed - ws) > 1e-2 then
                    hum.WalkSpeed = ws
                end

                if (not hum.UseJumpPower) or math.abs(hum.JumpPower - jp) > 1e-2 then
                    hum.UseJumpPower = true
                    hum.JumpPower    = jp
                end
            end

            if noclipOn and ch then applyNoclipToCharacter(ch) end

            if infJumpOn and not infJumpCon then enableInfiniteJump() end

            if flyEnabled and not FLYING then
                startMobileFly()
            elseif (not flyEnabled) and FLYING then
                stopMobileFly()
            end

            if forceFlyOn and not forceFlyConn then
                startForceFly()
            elseif (not forceFlyOn) and forceFlyConn then
                stopForceFly()
            end

            if godNegOn and not negConn then
                startGodNegative()
            elseif (not godNegOn) and negConn then
                stopGodNegative()
            end

            if godPosOn and not posConn then
                startGodPositive()
            elseif (not godPosOn) and posConn then
                stopGodPositive()
            end

            if instantOn and not shownConn then
                enableInstantInteract()
            elseif (not instantOn) and shownConn then
                disableInstantInteract()
            end
        end)
    end
end
