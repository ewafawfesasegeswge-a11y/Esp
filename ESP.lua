--// ESP_UI.lua — Zenith Visuals tab + Advanced ESP (Boxes, Tracers, Names, Health, Skeletons, Chams, TeamCheck)
-- Requires your hub to set:  getgenv().Window = Window

---------------------------------------------------------------------
-- Basic services / guards
---------------------------------------------------------------------
local Players = game:GetService('Players')
local RunService = game:GetService('RunService')
local LocalPlayer = Players.LocalPlayer
local Camera = workspace.CurrentCamera

local Window = rawget(getgenv(), 'Window')
if not Window then
    warn(
        '[ESP_UI] Hub Window not found. Make sure your hub sets:  getgenv().Window = Window'
    )
    return
end

-- Drawing availability (so we can still show Chams even if Drawing isn't supported)
local HAS_DRAWING = false
pcall(function()
    HAS_DRAWING = (Drawing and typeof(Drawing.new) == 'function')
end)

---------------------------------------------------------------------
-- UI: Visuals tab
---------------------------------------------------------------------
local VisualsTab = Window:AddTab('Visuals', 'eye')
local LeftBox = VisualsTab:AddLeftGroupbox('ESP Settings')
local RightBox = VisualsTab:AddRightGroupbox('ESP Colors')

-- Capture handles (so we’re not forced to use global Toggles/Options)
local H = { Toggles = {}, Options = {} }

local function addToggle(key, text, default)
    local t = LeftBox:AddToggle(key, { Text = text, Default = default })
    H.Toggles[key] = t
    return t
end
local function addSlider(key, text, min, max, default)
    local s = LeftBox:AddSlider(
        key,
        { Text = text, Min = min, Max = max, Default = default, Rounding = 0 }
    )
    H.Options[key] = s
    return s
end
local function addColor(key, text, color)
    local picker = RightBox:AddLabel(text)
        :AddColorPicker(key, { Default = color })
    H.Options[key] = picker
    return picker
end

-- Toggles
addToggle('ESP_Enabled', 'Enable ESP', false)
addToggle('ESP_Boxes', 'Boxes', true)
addToggle('ESP_Tracers', 'Tracers', true)
addToggle('ESP_Names', 'Names', true)
addToggle('ESP_Health', 'Health Bars', true)
addToggle('ESP_Skeletons', 'Skeletons', true)
addToggle('ESP_Chams', 'Chams', true)
addToggle('ESP_TeamCheck', 'Team Check', false)

-- Sliders
addSlider('ESP_Distance', 'Max Distance', 100, 5000, 1500)
addSlider('ESP_TextSize', 'Text Size', 10, 24, 14)
addSlider('ESP_Thickness', 'Line Thickness', 1, 5, 2)

-- Colors
addColor('ESP_BoxColor', 'Box Color', Color3.fromRGB(0, 255, 0))
addColor('ESP_TracerColor', 'Tracer Color', Color3.fromRGB(255, 255, 255))
addColor('ESP_SkeletonColor', 'Skeleton Color', Color3.fromRGB(255, 0, 0))
addColor('ESP_HealthColor', 'Health Color', Color3.fromRGB(0, 255, 0))
addColor('ESP_NameColor', 'Name Color', Color3.fromRGB(255, 255, 255))
addColor('ESP_ChamEnemy', 'Enemy Chams', Color3.fromRGB(255, 0, 0))
addColor('ESP_ChamTeam', 'Team Chams', Color3.fromRGB(0, 0, 255))

-- Helpers to read values
local function T(name, fallback)
    local obj = (
        H.Toggles[name]
        or (rawget(_G, 'Toggles') and _G.Toggles[name])
        or (rawget(getfenv(), 'Toggles') and getfenv().Toggles[name])
    )
    local ok, v = pcall(function()
        return obj and obj.Value
    end)
    return ok and v or fallback
end
local function O(name, fallback)
    local obj = (
        H.Options[name]
        or (rawget(_G, 'Options') and _G.Options[name])
        or (rawget(getfenv(), 'Options') and getfenv().Options[name])
    )
    local ok, v = pcall(function()
        return obj and obj.Value
    end)
    return ok and v or fallback
end

---------------------------------------------------------------------
-- ESP storage & helpers
---------------------------------------------------------------------
local ESPObjects = {}
local bonesTemplate = {
    { 'Head', 'UpperTorso' },
    { 'UpperTorso', 'LowerTorso' },
    { 'UpperTorso', 'LeftUpperArm' },
    { 'LeftUpperArm', 'LeftLowerArm' },
    { 'LeftLowerArm', 'LeftHand' },
    { 'UpperTorso', 'RightUpperArm' },
    { 'RightUpperArm', 'RightLowerArm' },
    { 'RightLowerArm', 'RightHand' },
    { 'LowerTorso', 'LeftUpperLeg' },
    { 'LeftUpperLeg', 'LeftLowerLeg' },
    { 'LeftLowerLeg', 'LeftFoot' },
    { 'LowerTorso', 'RightUpperLeg' },
    { 'RightUpperLeg', 'RightLowerLeg' },
    { 'RightLowerLeg', 'RightFoot' },
}

local function removeDrawing(d)
    if not d then
        return
    end
    local t = typeof(d)
    if t == 'Instance' then
        d:Destroy()
    else
        pcall(function()
            d:Remove()
        end)
    end
end

local function clearFor(plr)
    local pack = ESPObjects[plr]
    if not pack then
        return
    end
    for _, v in pairs(pack) do
        if type(v) == 'table' and v.__isSkeleton then
            for _, line in ipairs(v.lines) do
                removeDrawing(line)
            end
            v.lines = {}
        else
            removeDrawing(v)
        end
    end
    ESPObjects[plr] = nil
end

local function ensurePack(plr)
    local pack = ESPObjects[plr]
    if pack then
        return pack
    end
    pack = {}
    ESPObjects[plr] = pack
    return pack
end

local function createOrRefresh(plr)
    local pack = ensurePack(plr)

    -- Boxes
    if HAS_DRAWING and T('ESP_Boxes', true) then
        if not pack.Box then
            pack.Box = Drawing.new('Square')
            pack.Box.Filled = false
        end
    elseif pack.Box then
        removeDrawing(pack.Box)
        pack.Box = nil
    end

    -- Tracer
    if HAS_DRAWING and T('ESP_Tracers', true) then
        if not pack.Tracer then
            pack.Tracer = Drawing.new('Line')
        end
    elseif pack.Tracer then
        removeDrawing(pack.Tracer)
        pack.Tracer = nil
    end

    -- Name
    if HAS_DRAWING and T('ESP_Names', true) then
        if not pack.Name then
            pack.Name = Drawing.new('Text')
            pack.Name.Center = true
            pack.Name.Outline = true
        end
    elseif pack.Name then
        removeDrawing(pack.Name)
        pack.Name = nil
    end

    -- Health bar
    if HAS_DRAWING and T('ESP_Health', true) then
        if not pack.HealthOutline then
            pack.HealthOutline = Drawing.new('Line')
        end
        if not pack.Healthbar then
            pack.Healthbar = Drawing.new('Line')
        end
    else
        if pack.HealthOutline then
            removeDrawing(pack.HealthOutline)
            pack.HealthOutline = nil
        end
        if pack.Healthbar then
            removeDrawing(pack.Healthbar)
            pack.Healthbar = nil
        end
    end

    -- Skeleton
    if HAS_DRAWING and T('ESP_Skeletons', true) then
        if not pack.Skeleton or not pack.Skeleton.lines then
            pack.Skeleton =
                { __isSkeleton = true, lines = {}, bones = bonesTemplate }
            for _ = 1, #bonesTemplate do
                table.insert(pack.Skeleton.lines, Drawing.new('Line'))
            end
        end
    elseif pack.Skeleton then
        for _, line in ipairs(pack.Skeleton.lines) do
            removeDrawing(line)
        end
        pack.Skeleton = nil
    end

    -- Chams (Highlight instance)
    if T('ESP_Chams', true) and plr.Character then
        if not pack.Chams or pack.Chams.Parent ~= plr.Character then
            if pack.Chams then
                removeDrawing(pack.Chams)
            end
            local h = Instance.new('Highlight')
            h.Adornee = plr.Character
            h.FillTransparency = 0.5
            h.OutlineTransparency = 0
            h.Parent = plr.Character
            pack.Chams = h
        end
    elseif pack.Chams then
        removeDrawing(pack.Chams)
        pack.Chams = nil
    end
end

---------------------------------------------------------------------
-- Main render loop
---------------------------------------------------------------------
RunService.RenderStepped:Connect(function()
    if not T('ESP_Enabled', false) then
        for plr in pairs(ESPObjects) do
            clearFor(plr)
        end
        return
    end

    for _, plr in ipairs(Players:GetPlayers()) do
        repeat
            if plr == LocalPlayer then
                break
            end
            local char = plr.Character
            if not char then
                clearFor(plr)
                break
            end
            local hum = char:FindFirstChildOfClass('Humanoid')
            local hrp = char:FindFirstChild('HumanoidRootPart')
            if not hum or not hrp or hum.Health <= 0 then
                clearFor(plr)
                break
            end

            if T('ESP_TeamCheck', false) and plr.Team == LocalPlayer.Team then
                clearFor(plr)
                break
            end

            local maxDist = O('ESP_Distance', 1500)
            local dist = (hrp.Position - Camera.CFrame.Position).Magnitude
            if dist > maxDist then
                clearFor(plr)
                break
            end

            createOrRefresh(plr)
            local pack = ESPObjects[plr]
            local root2d, onScreen = Camera:WorldToViewportPoint(hrp.Position)
            if not onScreen then
                clearFor(plr)
                break
            end

            local thickness = O('ESP_Thickness', 2)
            local textSize = O('ESP_TextSize', 14)

            -- BOX
            if pack.Box then
                local head = char:FindFirstChild('Head')
                if head then
                    local head2d = Camera:WorldToViewportPoint(
                        head.Position + Vector3.new(0, 0.5, 0)
                    )
                    local scale = (
                        Vector2.new(root2d.X, root2d.Y)
                        - Vector2.new(head2d.X, head2d.Y)
                    ).Magnitude
                    local w, h = scale * 1.5, scale * 2
                    pack.Box.Size = Vector2.new(w, h)
                    pack.Box.Position =
                        Vector2.new(root2d.X - w / 2, root2d.Y - h / 2)
                    pack.Box.Thickness = thickness
                    pack.Box.Color =
                        O('ESP_BoxColor', Color3.fromRGB(0, 255, 0))
                    pack.Box.Visible = true
                else
                    pack.Box.Visible = false
                end
            end

            -- TRACER
            if pack.Tracer then
                pack.Tracer.From = Vector2.new(
                    Camera.ViewportSize.X / 2,
                    Camera.ViewportSize.Y
                )
                pack.Tracer.To = Vector2.new(root2d.X, root2d.Y)
                pack.Tracer.Thickness = thickness
                pack.Tracer.Color = O('ESP_TracerColor', Color3.new(1, 1, 1))
                pack.Tracer.Visible = true
            end

            -- NAME
            if pack.Name then
                pack.Name.Text = string.format(
                    '%s [%d]  (%dm)',
                    plr.Name,
                    math.floor(hum.Health),
                    math.floor(dist)
                )
                pack.Name.Size = textSize
                pack.Name.Color = O('ESP_NameColor', Color3.new(1, 1, 1))
                pack.Name.Position = Vector2.new(root2d.X, root2d.Y - 30)
                pack.Name.Visible = true
            end

            -- HEALTHBAR
            if pack.Healthbar and pack.HealthOutline then
                local hp = hum.Health / math.max(hum.MaxHealth, 1)
                local hgt = 40
                local x = root2d.X - 50
                pack.HealthOutline.From = Vector2.new(x, root2d.Y - 20)
                pack.HealthOutline.To = Vector2.new(x, root2d.Y + 20)
                pack.HealthOutline.Thickness = math.max(1, thickness + 1)
                pack.HealthOutline.Color = Color3.new(0, 0, 0)
                pack.HealthOutline.Visible = true

                pack.Healthbar.From = Vector2.new(x, root2d.Y + 20)
                pack.Healthbar.To = Vector2.new(x, root2d.Y + 20 - (hgt * hp))
                pack.Healthbar.Thickness = thickness
                pack.Healthbar.Color =
                    O('ESP_HealthColor', Color3.fromRGB(0, 255, 0))
                pack.Healthbar.Visible = true
            end

            -- SKELETON
            if pack.Skeleton then
                local col = O('ESP_SkeletonColor', Color3.fromRGB(255, 0, 0))
                for i, bone in ipairs(pack.Skeleton.bones) do
                    local p1, p2 =
                        char:FindFirstChild(bone[1]),
                        char:FindFirstChild(bone[2])
                    local line = pack.Skeleton.lines[i]
                    if p1 and p2 and line then
                        local a, v1 = Camera:WorldToViewportPoint(p1.Position)
                        local b, v2 = Camera:WorldToViewportPoint(p2.Position)
                        if v1 and v2 then
                            line.From = Vector2.new(a.X, a.Y)
                            line.To = Vector2.new(b.X, b.Y)
                            line.Thickness = thickness
                            line.Color = col
                            line.Visible = true
                        else
                            line.Visible = false
                        end
                    elseif line then
                        line.Visible = false
                    end
                end
            end

            -- CHAMS
            if pack.Chams then
                if
                    T('ESP_TeamCheck', false)
                    and plr.Team == LocalPlayer.Team
                then
                    pack.Chams.FillColor =
                        O('ESP_ChamTeam', Color3.fromRGB(0, 0, 255))
                else
                    pack.Chams.FillColor =
                        O('ESP_ChamEnemy', Color3.fromRGB(255, 0, 0))
                end
            end
        until true
    end
end)

-- Clean up when players leave / respawn
Players.PlayerRemoving:Connect(function(plr)
    clearFor(plr)
end)
Players.PlayerAdded:Connect(function(plr)
    plr.CharacterAdded:Connect(function()
        clearFor(plr)
    end)
end)

-- If Drawing is missing, at least inform the user
if not HAS_DRAWING then
    warn(
        '[ESP_UI] Drawing API not available in this executor. Boxes/Tracers/Names/Health/Skeletons will be disabled. Chams still works.'
    )
end
