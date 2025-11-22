-- visuals.lua

return function(C, R, UI)
    C  = C  or _G.C
    UI = UI or _G.UI

    assert(C and UI and UI.Tabs and UI.Tabs.Visuals, "visuals.lua: Visuals tab missing")

    local Services   = C.Services or {}
    local Players    = Services.Players or game:GetService("Players")
    local lp         = C.LocalPlayer or Players.LocalPlayer
    local VisualsTab = UI.Tabs.Visuals

    -- State
    C.State         = C.State or {}
    C.State.Toggles = C.State.Toggles or {}
    local toggles   = C.State.Toggles

    local PLAYER_HL_NAME = "__PlayerTrackerHL__"

    local runningPlayers   = false
    local playerAddedConn  = nil
    local playerRemovingConn = nil
    local charAddedConns   = {}

    -- Helpers
    local function ensureHighlight(character)
        if not character then return nil end
        local hl = character:FindFirstChild(PLAYER_HL_NAME)
        if not hl or not hl:IsA("Highlight") then
            hl = Instance.new("Highlight")
            hl.Name = PLAYER_HL_NAME
            hl.Adornee = character
            hl.FillTransparency    = 1       -- no fill, outline only
            hl.OutlineTransparency = 0       -- fully visible outline
            hl.OutlineColor        = Color3.fromRGB(255, 255, 0)
            hl.DepthMode           = Enum.HighlightDepthMode.AlwaysOnTop
            hl.Parent              = character
        end
        hl.Enabled = true
        return hl
    end

    local function clearHighlight(character)
        if not character then return end
        local hl = character:FindFirstChild(PLAYER_HL_NAME)
        if hl and hl:IsA("Highlight") then
            hl:Destroy()
        end
    end

    local function attachToCharacter(plr, character)
        if not character or plr == lp then return end
        ensureHighlight(character)
    end

    local function trackPlayer(plr)
        if plr == lp then return end

        -- Attach to existing character
        if plr.Character then
            attachToCharacter(plr, plr.Character)
        end

        -- CharacterAdded connection
        if charAddedConns[plr] then
            charAddedConns[plr]:Disconnect()
        end
        charAddedConns[plr] = plr.CharacterAdded:Connect(function(ch)
            attachToCharacter(plr, ch)
        end)
    end

    local function untrackPlayer(plr)
        if charAddedConns[plr] then
            charAddedConns[plr]:Disconnect()
            charAddedConns[plr] = nil
        end
        if plr.Character then
            clearHighlight(plr.Character)
        end
    end

    local function startPlayerTracker()
        if runningPlayers then return end
        runningPlayers = true

        -- existing players
        for _, plr in ipairs(Players:GetPlayers()) do
            trackPlayer(plr)
        end

        -- player added
        if playerAddedConn then
            playerAddedConn:Disconnect()
        end
        playerAddedConn = Players.PlayerAdded:Connect(function(plr)
            if runningPlayers then
                trackPlayer(plr)
            end
        end)

        -- player removing
        if playerRemovingConn then
            playerRemovingConn:Disconnect()
        end
        playerRemovingConn = Players.PlayerRemoving:Connect(function(plr)
            untrackPlayer(plr)
        end)
    end

    local function stopPlayerTracker()
        if not runningPlayers then return end
        runningPlayers = false

        if playerAddedConn then
            playerAddedConn:Disconnect()
            playerAddedConn = nil
        end
        if playerRemovingConn then
            playerRemovingConn:Disconnect()
            playerRemovingConn = nil
        end

        for plr, conn in pairs(charAddedConns) do
            if conn then conn:Disconnect() end
            charAddedConns[plr] = nil
        end

        -- remove all highlights
        for _, plr in ipairs(Players:GetPlayers()) do
            if plr ~= lp and plr.Character then
                clearHighlight(plr.Character)
            end
        end
    end

    -- UI
    VisualsTab:Section({
        Title = "Player Visuals",
        Icon  = "user",
    })

    VisualsTab:Toggle({
        Title   = "Highlight Other Players",
        Value   = (toggles.PlayerTracker ~= false),
        Callback = function(on)
            on = (on == true)
            toggles.PlayerTracker = on
            if on then
                startPlayerTracker()
            else
                stopPlayerTracker()
            end
        end
    })

    -- Auto-enable if previously on or unset
    if toggles.PlayerTracker ~= false then
        startPlayerTracker()
    end
end
