-- ═══════════════════════════════════════════════════════════════════════════
-- UNIVERSAL HBE + REACH DETECTOR v10.17
-- SUS / 99% / Total counters with 5s cooldown
-- ALERTS FOR EVERYONE (Self + Others) with 15s cooldown per player
-- ═══════════════════════════════════════════════════════════════════════════

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")
local StarterGui = game:GetService("StarterGui")

local LocalPlayer = Players.LocalPlayer

local CHECK_INTERVAL = 2

-- Thresholds
local HEAD_MIN = 2.15
local ROOT_MIN = 2.25
local ARM_MIN  = 1.60
local LEG_MIN  = 1.60
local REACH_MIN = 3.5

local playerRows = {}
local lastCheck = 0
local MainFrame = nil
local ReopenBtn = nil
local isClosed = false
local ballConnection = nil

-- Counters
local suspiciousCount = {}
local ninetyNineCount = {}
local totalHBECount = {}

-- Cooldowns
local lastSusTime = {}
local last99Time = {}
local lastAlertTime = {}   -- Per player alert cooldown

local COOLDOWN = 5      -- Counter cooldown
local ALERT_COOLDOWN = 15  -- Alert cooldown per player

-- ==================== GUI ====================
local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name = "HBEDetectorV10_17"
ScreenGui.ResetOnSpawn = false
ScreenGui.IgnoreGuiInset = true
ScreenGui.Parent = LocalPlayer:WaitForChild("PlayerGui")

MainFrame = Instance.new("Frame", ScreenGui)
MainFrame.Size = UDim2.new(0, 186, 0, 276)
MainFrame.Position = UDim2.new(0.5, -93, 0.5, -138)
MainFrame.BackgroundColor3 = Color3.fromRGB(18, 18, 28)
MainFrame.BackgroundTransparency = 0.05
Instance.new("UICorner", MainFrame).CornerRadius = UDim.new(0, 14)

local TitleBar = Instance.new("Frame", MainFrame)
TitleBar.Size = UDim2.new(1, 0, 0, 40)
TitleBar.BackgroundColor3 = Color3.fromRGB(0, 160, 255)
TitleBar.BackgroundTransparency = 0.25
Instance.new("UICorner", TitleBar).CornerRadius = UDim.new(0, 14)

local Title = Instance.new("TextLabel", TitleBar)
Title.Size = UDim2.new(1, -70, 1, 0)
Title.BackgroundTransparency = 1
Title.Text = "HBE Detector"
Title.TextColor3 = Color3.new(1,1,1)
Title.Font = Enum.Font.GothamBold
Title.TextSize = 14

local InfoLabel = Instance.new("TextLabel", MainFrame)
InfoLabel.Size = UDim2.new(1, -20, 0, 16)
InfoLabel.Position = UDim2.new(0, 10, 0, 42)
InfoLabel.BackgroundTransparency = 1
InfoLabel.Text = "POSSIBLE = suspicious | keeps triggering = likely cheating"
InfoLabel.TextColor3 = Color3.fromRGB(160, 160, 180)
InfoLabel.Font = Enum.Font.Gotham
InfoLabel.TextSize = 9
InfoLabel.TextXAlignment = Enum.TextXAlignment.Center

local CloseBtn = Instance.new("TextButton", TitleBar)
CloseBtn.Size = UDim2.new(0, 28, 0, 28)
CloseBtn.Position = UDim2.new(1, -34, 0.5, -14)
CloseBtn.BackgroundTransparency = 1
CloseBtn.Text = "✕"
CloseBtn.TextColor3 = Color3.fromRGB(255, 90, 90)
CloseBtn.Font = Enum.Font.GothamBold
CloseBtn.TextSize = 18

local Scrolling = Instance.new("ScrollingFrame", MainFrame)
Scrolling.Size = UDim2.new(1, -16, 1, -70)
Scrolling.Position = UDim2.new(0, 8, 0, 62)
Scrolling.BackgroundTransparency = 1
Scrolling.ScrollBarThickness = 4
Scrolling.AutomaticCanvasSize = Enum.AutomaticSize.Y

local ListLayout = Instance.new("UIListLayout", Scrolling)
ListLayout.Padding = UDim.new(0, 6)

-- Draggable + Close/Reopen (same as before)
local dragging = false
local dragStart, startPos

TitleBar.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
        dragging = true
        dragStart = input.Position
        startPos = MainFrame.Position
    end
end)

UserInputService.InputChanged:Connect(function(input)
    if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
        local delta = input.Position - dragStart
        MainFrame.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X, startPos.Y.Scale, startPos.Y.Offset + delta.Y)
    end
end)

UserInputService.InputEnded:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
        dragging = false
    end
end)

CloseBtn.MouseButton1Click:Connect(function()
    isClosed = true
    MainFrame.Visible = false
    if not ReopenBtn then
        ReopenBtn = Instance.new("TextButton", ScreenGui)
        ReopenBtn.Size = UDim2.new(0, 160, 0, 42)
        ReopenBtn.Position = UDim2.new(0, 20, 0.45, 0)
        ReopenBtn.BackgroundColor3 = Color3.fromRGB(0, 160, 255)
        ReopenBtn.BackgroundTransparency = 0.2
        ReopenBtn.Text = "Open HBE Detector"
        ReopenBtn.TextColor3 = Color3.new(1,1,1)
        ReopenBtn.Font = Enum.Font.GothamBold
        ReopenBtn.TextSize = 13
        Instance.new("UICorner", ReopenBtn).CornerRadius = UDim.new(0, 10)

        ReopenBtn.MouseButton1Click:Connect(function()
            isClosed = false
            MainFrame.Visible = true
            ReopenBtn:Destroy()
            ReopenBtn = nil
        end)
    end
end)

local function createRow(player)
    if playerRows[player] then return end
    local row = Instance.new("Frame")
    row.Size = UDim2.new(1, 0, 0, 52)
    row.BackgroundColor3 = Color3.fromRGB(30, 30, 45)
    row.BackgroundTransparency = 0.2
    Instance.new("UICorner", row).CornerRadius = UDim.new(0, 10)
    row.Parent = Scrolling

    local nameLabel = Instance.new("TextLabel", row)
    nameLabel.Size = UDim2.new(0.6, 0, 0, 26)
    nameLabel.Position = UDim2.new(0, 10, 0, 4)
    nameLabel.BackgroundTransparency = 1
    nameLabel.Text = player == LocalPlayer and "You" or player.Name
    nameLabel.TextColor3 = Color3.new(1,1,1)
    nameLabel.Font = Enum.Font.GothamSemibold
    nameLabel.TextSize = 13.5
    nameLabel.TextXAlignment = Enum.TextXAlignment.Left

    local statusLabel = Instance.new("TextLabel", row)
    statusLabel.Size = UDim2.new(0.38, 0, 0, 26)
    statusLabel.Position = UDim2.new(0.60, 0, 0, 4)
    statusLabel.BackgroundTransparency = 1
    statusLabel.Text = "Checking..."
    statusLabel.TextColor3 = Color3.fromRGB(180, 180, 180)
    statusLabel.Font = Enum.Font.Gotham
    statusLabel.TextSize = 11.5
    statusLabel.TextWrapped = true

    local counterLabel = Instance.new("TextLabel", row)
    counterLabel.Size = UDim2.new(1, -20, 0, 16)
    counterLabel.Position = UDim2.new(0, 10, 0, 32)
    counterLabel.BackgroundTransparency = 1
    counterLabel.Text = "SUS:0 | 99%:0 | Total:0"
    counterLabel.TextColor3 = Color3.fromRGB(140, 140, 160)
    counterLabel.Font = Enum.Font.Gotham
    counterLabel.TextSize = 10
    counterLabel.TextXAlignment = Enum.TextXAlignment.Left

    playerRows[player] = {status = statusLabel, counter = counterLabel}
end

local function updateCounters(player, is99)
    local now = tick()
    local lastTimeTable = is99 and last99Time or lastSusTime
    if now - (lastTimeTable[player] or 0) < COOLDOWN then return end

    lastTimeTable[player] = now

    if is99 then
        ninetyNineCount[player] = (ninetyNineCount[player] or 0) + 1
    else
        suspiciousCount[player] = (suspiciousCount[player] or 0) + 1
    end
    totalHBECount[player] = (totalHBECount[player] or 0) + 1

    if playerRows[player] then
        local s = suspiciousCount[player] or 0
        local n = ninetyNineCount[player] or 0
        local t = totalHBECount[player] or 0
        playerRows[player].counter.Text = "SUS:" .. s .. " | 99%:" .. n .. " | Total:" .. t
    end
end

local function sendAlert(playerName, is99)
    local now = tick()
    if now - (lastAlertTime[playerName] or 0) < ALERT_COOLDOWN then return end
    lastAlertTime[playerName] = now

    local title = is99 and "🚨 99% HBE/BOX REACH" or "⚠️ POSSIBLE HBE DETECTED"
    local text = playerName .. " is using HBE!"

    StarterGui:SetCore("SendNotification", {
        Title = title,
        Text = text,
        Duration = 6,
    })
end

local function checkPlayer(player)
    local char = player.Character
    if not char then return "No Char", false end

    local head = char:FindFirstChild("Head")
    local root = char:FindFirstChild("HumanoidRootPart") or char:FindFirstChild("Torso")

    if head and (head.Size.X > HEAD_MIN or head.Size.Z > HEAD_MIN) then
        return "Head (" .. math.round(head.Size.X * 10)/10 .. ")", true
    end
    if root and (root.Size.X > ROOT_MIN or root.Size.Z > ROOT_MIN) then
        return "Root (" .. math.round(root.Size.X * 10)/10 .. ")", true
    end

    for _, name in ipairs({"Left Arm","Right Arm","LeftUpperArm","RightUpperArm","LeftLowerArm","RightLowerArm"}) do
        local p = char:FindFirstChild(name)
        if p and (p.Size.X > ARM_MIN or p.Size.Z > ARM_MIN) then
            return "Arm (" .. math.round(p.Size.X * 10)/10 .. ")", true
        end
    end

    for _, name in ipairs({"Left Leg","Right Leg","LeftUpperLeg","RightUpperLeg","LeftLowerLeg","RightLowerLeg"}) do
        local p = char:FindFirstChild(name)
        if p and (p.Size.X > LEG_MIN or p.Size.Z > LEG_MIN) then
            return "Leg (" .. math.round(p.Size.X * 10)/10 .. ")", true
        end
    end

    for _, part in ipairs(char:GetDescendants()) do
        if part:IsA("BasePart") and part ~= head and part ~= root then
            if part.Size.X > REACH_MIN or part.Size.Z > REACH_MIN then
                return "99% HBE/BOX REACH", true
            end
        end
    end

    return "Normal", false
end

-- Ball Reach
local function monitorBall()
    if ballConnection then return end

    local ball = nil
    for _, obj in ipairs(Workspace:GetDescendants()) do
        local name = obj.Name:lower()
        if obj:IsA("BasePart") and (name:find("ball") or name:find("football")) then
            ball = obj
            break
        end
    end

    if not ball then return end

    ballConnection = ball.Touched:Connect(function(hit)
        local character = hit.Parent
        local player = Players:GetPlayerFromCharacter(character)
        if not player or not playerRows[player] then return end

        local root = character:FindFirstChild("HumanoidRootPart") or character:FindFirstChild("Torso")
        if not root then return end

        local distance = (root.Position - ball.Position).Magnitude

        if distance > 6.7 then
            playerRows[player].status.Text = "99% HBE/BOX REACH"
            playerRows[player].status.TextColor3 = Color3.fromRGB(255, 80, 80)
            updateCounters(player, true)
            sendAlert(player.Name, true)
        elseif distance > 5.0 then
            playerRows[player].status.Text = "POSSIBLE HBE/BOX REACH"
            playerRows[player].status.TextColor3 = Color3.fromRGB(255, 140, 0)
            updateCounters(player, false)
            sendAlert(player.Name, false)
        end
    end)
end

-- Main Loop
RunService.Heartbeat:Connect(function()
    local now = tick()
    if now - lastCheck < CHECK_INTERVAL then return end
    lastCheck = now

    for _, plr in ipairs(Players:GetPlayers()) do
        if not playerRows[plr] then
            createRow(plr)
        end
    end

    for player, data in pairs(playerRows) do
        if player.Parent then
            local status, detected = checkPlayer(player)
            data.status.Text = status

            if player == LocalPlayer then
                data.status.Text = "You (" .. status .. ")"
            end

            if detected then
                local is99 = status:find("99%") ~= nil
                updateCounters(player, is99)
                sendAlert(player.Name, is99)
            end
        end
    end

    monitorBall()
end)

for _, plr in ipairs(Players:GetPlayers()) do
    createRow(plr)
end

print("✅ HBE Detector v10.17 loaded - Server-wide alerts + cooldowns")
