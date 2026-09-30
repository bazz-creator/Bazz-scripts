-- ==========================================
-- BAZZ — ECLIPSE RIFT (FINAL v7)
-- + Anti-AFK + WORLD_SPOTS + рестарт по Y
-- + waitForNewBlocks + полная проверка карты
-- БЕЗ АВТОЗАПУСКА, БЕЗ КЛЮЧА
-- ==========================================
print("🚀 BAZZ FINAL v7")

local CONFIG = {
    TP_SETTLE = 0.02,
    DELAY     = 0.03,
    REST_WAIT = 10,
    TIMEOUT_SEC = 120,
    WORLD_RESET_DELAY = 5,
    WORLD_LOAD_MAX = 40,
    GREEN_MAX_Y = -60,
    RADIUS_GREEN_X = 2,
    RADIUS_GREEN_Z = 2,
    RADIUS_YELLOW_X = 2,
    RADIUS_YELLOW_Z = 2,
    FORCE_BOMB = "auto",
    AUTO_FARM = false,
    ZONE_NAME = "__Zone_8",
    TELEPORT_CHECK_FROM_Y = -120,
    TELEPORT_DETECT_ABOVE_Y = -10,
}

local ORE_ID   = "Eclipse Onyx Gem"
local ORE_NAME = "Eclipse Onyx"

local WORLD_SPOTS = {
    [8737899170]      = {pos = Vector3.new(179.04, 16.24, -142.15)},
    [16498369169]     = {pos = Vector3.new(-9954.08, 16.54, -287.74)},
    [17503543197]     = {pos = Vector3.new(-10256.35, 4.17, -7300.98)},
    [140403681187145] = {pos = Vector3.new(-15848.54, 39.92, -193.16)},
}

local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")
local VirtualUser = game:GetService("VirtualUser")
local LocalPlayer = Players.LocalPlayer

local Network = nil
pcall(function() Network = RS:WaitForChild("Network", 10) end)

local Save, Blocks, BWC
pcall(function() Save = require(RS.Library.Client.Save) end)
pcall(function() Blocks = require(RS.Library.Types.Blocks) end)
pcall(function() BWC = require(RS.Library.Client.ToolCmds.BlockWorldClient) end)

local Consume = nil
if Network then
    pcall(function() Consume = Network:WaitForChild("Consumables_Consume", 10) end)
end

local Instancing = nil
local TeleportsInstance = nil
if Network then
    pcall(function()
        Instancing = Network:WaitForChild("Instancing_PlayerEnterInstance", 10)
    end)
    pcall(function()
        TeleportsInstance = Network:WaitForChild("Teleports_RequestInstanceTeleport", 10)
    end)
end

-- ANTI-AFK
task.spawn(function()
    LocalPlayer.Idled:Connect(function()
        pcall(function()
            local char = LocalPlayer.Character
            if char then
                local hum = char:FindFirstChildOfClass("Humanoid")
                if hum then hum.Jump = true end
            end
            VirtualUser:CaptureController()
            VirtualUser:ClickButton1(Vector2.new(0, 0))
        end)
    end)

    while true do
        task.wait(30)
        pcall(function()
            local char = LocalPlayer.Character
            if char then
                local hum = char:FindFirstChildOfClass("Humanoid")
                if hum then hum.Jump = true end
            end
        end)
    end
end)

local BOMB_UIDS = { green = nil, yellow = nil }

local function findBombUIDs()
    if not Save then return false end
    local d = Save.Get()
    if not d or not d.Inventory or not d.Inventory.Consumable then return false end
    BOMB_UIDS.green, BOMB_UIDS.yellow = nil, nil
    for uid, c in pairs(d.Inventory.Consumable) do
        local id = tostring(c.id)
        if id == "Drill Array" then BOMB_UIDS.green = uid
        elseif id == "Core Charge" then BOMB_UIDS.yellow = uid end
    end
    return BOMB_UIDS.green ~= nil or BOMB_UIDS.yellow ~= nil
end

local function countBombs(t)
    if not Save then return 0 end
    local d = Save.Get()
    if not d or not d.Inventory or not d.Inventory.Consumable then return 0 end
    local id = (t == "green") and "Drill Array" or "Core Charge"
    local n = 0
    for _, c in pairs(d.Inventory.Consumable) do
        if tostring(c.id) == id then n = n + (c._am or c.amount or c.count or 1) end
    end
    return n
end

local function countOre()
    if not Save then return 0 end
    local d = Save.Get()
    if not d or not d.Inventory or not d.Inventory.Misc then return 0 end
    local n = 0
    for _, x in pairs(d.Inventory.Misc) do
        if tostring(x.id) == ORE_ID then n = n + (x._am or 1) end
    end
    return n
end

repeat task.wait(0.1) until Save and Save.Get() and Save.Get().Inventory and Save.Get().Inventory.Consumable

local START_GREEN, START_YELLOW = countBombs("green"), countBombs("yellow")
local START_ORE, START_TIME = countOre(), tick()

local Rayfield = loadstring(game:HttpGet('https://sirius.menu/rayfield'))()

local Window = Rayfield:CreateWindow({
    Name = "Bazz",
    LoadingTitle = "Bazz",
    LoadingSubtitle = "Eclipse Rift Auto Farm",
    ConfigurationSaving = { Enabled = true, FolderName = "Bazz", FileName = "Config" },
    Keybind = "K"
})

local MainTab = Window:CreateTab("Main", 4483362458)
MainTab:CreateSection("Фарм")

MainTab:CreateToggle({
    Name = "Auto Farm",
    CurrentValue = false,
    Flag = "AutoFarm",
    Callback = function(v)
        CONFIG.AUTO_FARM = v
        if v then
            getgenv().MagnusRunning = true
            if getgenv().MagnusResume then getgenv().MagnusResume()
            elseif getgenv().MagnusStart then getgenv().MagnusStart() end
            Rayfield:Notify({Title="Старт", Content="Фарм запущен", Duration=3})
        else
            if getgenv().MagnusStop then getgenv().MagnusStop() end
            Rayfield:Notify({Title="Стоп", Content="Фарм остановлен", Duration=3})
        end
    end,
})

MainTab:CreateSection("Режим бомб")
MainTab:CreateToggle({Name="Force Green (Drill Array)", CurrentValue=false, Flag="ForceGreen",
    Callback=function(v) if v then CONFIG.FORCE_BOMB="green" else CONFIG.FORCE_BOMB="auto" end end})
MainTab:CreateToggle({Name="Force Yellow (Core Charge)", CurrentValue=false, Flag="ForceYellow",
    Callback=function(v) if v then CONFIG.FORCE_BOMB="yellow" else CONFIG.FORCE_BOMB="auto" end end})

MainTab:CreateSection("Управление")
MainTab:CreateButton({Name="🔄 Сброс позиции", Callback=function()
    getgenv().MagnusResetPos()
    Rayfield:Notify({Title="Сброс", Content="Позиция сброшена", Duration=3})
end})
MainTab:CreateButton({Name="⛏ Войти в #8 (2 шага)", Callback=function()
    if getgenv().BazzEnterMine then
        getgenv().BazzEnterMine()
        Rayfield:Notify({Title="Вход", Content="Ивент → #8", Duration=3})
    end
end})

local SettingsTab = Window:CreateTab("Settings", 4483362458)
SettingsTab:CreateSection("Порог высоты")
SettingsTab:CreateSlider({Name="GREEN_MAX_Y", Range={-200,0}, Increment=1, Suffix="Y", CurrentValue=-60, Flag="GreenMaxY", Callback=function(v) CONFIG.GREEN_MAX_Y=v end})
SettingsTab:CreateSection("Задержки")
SettingsTab:CreateSlider({Name="DELAY", Range={0.01,1}, Increment=0.01, Suffix="с", CurrentValue=0.03, Flag="Delay", Callback=function(v) CONFIG.DELAY=v end})
SettingsTab:CreateSlider({Name="TP_SETTLE", Range={0.01,1}, Increment=0.01, Suffix="с", CurrentValue=0.02, Flag="TPSettle", Callback=function(v) CONFIG.TP_SETTLE=v end})
SettingsTab:CreateSlider({Name="REST_WAIT", Range={5,300}, Increment=5, Suffix="с", CurrentValue=10, Flag="RestWait", Callback=function(v) CONFIG.REST_WAIT=v end})

SettingsTab:CreateSection("Радиус — ЗЕЛЁНЫЕ")
SettingsTab:CreateSlider({Name="Green Width X", Range={1,10}, Increment=1, Suffix=" блоков", CurrentValue=2, Flag="RadiusGreenX", Callback=function(v) CONFIG.RADIUS_GREEN_X=v end})
SettingsTab:CreateSlider({Name="Green Length Z", Range={1,10}, Increment=1, Suffix=" блоков", CurrentValue=2, Flag="RadiusGreenZ", Callback=function(v) CONFIG.RADIUS_GREEN_Z=v end})

SettingsTab:CreateSection("Радиус — ЖЁЛТЫЕ")
SettingsTab:CreateSlider({Name="Yellow Width X", Range={1,10}, Increment=1, Suffix=" блоков", CurrentValue=2, Flag="RadiusYellowX", Callback=function(v) CONFIG.RADIUS_YELLOW_X=v end})
SettingsTab:CreateSlider({Name="Yellow Length Z", Range={1,10}, Increment=1, Suffix=" блоков", CurrentValue=2, Flag="RadiusYellowZ", Callback=function(v) CONFIG.RADIUS_YELLOW_Z=v end})

local StatsTab = Window:CreateTab("Stats", 4483362458)
StatsTab:CreateSection("Статистика")
local statsLabel = StatsTab:CreateLabel("Загрузка...")
local afkLabel = StatsTab:CreateLabel("АФК: 00:00:00")
local posLabel = StatsTab:CreateLabel("Позиция: —")
local statusLabel = StatsTab:CreateLabel("Статус: ожидание")

local function fmt(s)
    return string.format("%02d:%02d:%02d", math.floor(s/3600), math.floor((s%3600)/60), math.floor(s%60))
end

task.spawn(function()
    while true do
        local g = countBombs("green")
        local y = countBombs("yellow")
        local o = countOre()
        local elapsed = tick() - START_TIME
        local text = string.format(
            "🟢 Drill Array: %d (потрачено: %d)\n🟡 Core Charge: %d (потрачено: %d)\n💎 %s: %d (нафармлено: %d)",
            g, math.max(0, START_GREEN - g),
            y, math.max(0, START_YELLOW - y),
            ORE_NAME, o, math.max(0, o - START_ORE)
        )
        pcall(function() statsLabel:Set(text) end)
        pcall(function() afkLabel:Set("💤 АФК: "..fmt(elapsed)) end)
        pcall(function()
            posLabel:Set(string.format("📍 X=%s Y=%s Z=%s",
                tostring(getgenv().curX), tostring(getgenv().curY), tostring(getgenv().curZ)))
        end)
        pcall(function() statusLabel:Set("📌 "..tostring(getgenv().statusText or "ожидание")) end)
        task.wait(2)
    end
end)

local LP = LocalPlayer
local world, region, origin

getgenv().MagnusRunning = false
getgenv().MagnusThread = nil
getgenv().curX = nil
getgenv().curY = nil
getgenv().curZ = nil
getgenv().statusText = "ожидание"

local function getHRP()
    local c = LP.Character
    return c and c:FindFirstChild("HumanoidRootPart")
end

local function tp(pos)
    local hrp = getHRP()
    if not hrp then return end
    hrp.Velocity, hrp.RotVelocity = Vector3.zero, Vector3.zero
    hrp.CFrame = CFrame.new(pos)
end

local function tpGrid(x, y, z)
    if not origin or not Blocks then return end
    local cf = Blocks.BlockCFrame(origin, Vector3int16.new(x, y, z))
    if not cf then return end
    tp(cf.Position + Vector3.new(0, 3, 0))
end

local function useBomb(key)
    if not Consume then return end
    local uid = BOMB_UIDS[key]
    if not uid then return end
    pcall(function() Consume:InvokeServer(uid, 1) end)
end

local function getBombKey(y)
    if CONFIG.FORCE_BOMB == "green" then return "green" end
    if CONFIG.FORCE_BOMB == "yellow" then return "yellow" end
    return y >= CONFIG.GREEN_MAX_Y and "green" or "yellow"
end

local function getRadius(key)
    if key == "green" then return CONFIG.RADIUS_GREEN_X, CONFIG.RADIUS_GREEN_Z
    else return CONFIG.RADIUS_YELLOW_X, CONFIG.RADIUS_YELLOW_Z end
end

local function enterMine()
    if BWC.GetLocal() then
        print("Уже в шахте")
        return true
    end

    local spot = WORLD_SPOTS[game.PlaceId]
    if spot then
        print("Телепорт на точку входа в ивент")
        tp(spot.pos)
        task.wait(3)
    end

    if Instancing then
        pcall(function()
            Instancing:InvokeServer("SpaceMiningEvent")
        end)
        print("Шаг 1: вход в ивент")
        task.wait(12)
    end

    if TeleportsInstance then
        local ok, result = pcall(function()
            return TeleportsInstance:InvokeServer(CONFIG.ZONE_NAME)
        end)
        print("Шаг 2: телепорт в "..CONFIG.ZONE_NAME.." →", result)
        task.wait(8)
    end

    return true
end

getgenv().BazzEnterMine = enterMine

local wentBelowCheckY = false

local function wasTeleportedToTop()
    local hrp = getHRP()
    if not hrp then return false end
    local posY = hrp.Position.Y

    if not wentBelowCheckY then
        if posY < CONFIG.TELEPORT_CHECK_FROM_Y then
            wentBelowCheckY = true
        end
        return false
    end

    if posY > CONFIG.TELEPORT_DETECT_ABOVE_Y then
        return true
    end
    return false
end

local function waitForNewBlocks()
    local attempts = 0
    repeat
        task.wait(0.5)
        local currentWorld = BWC.GetLocal()
        if currentWorld then
            local wRegion = currentWorld:GetRegion()
            local wStartX = wRegion.Min.X + 1
            local wStartZ = wRegion.Min.Z + 1
            for checkY = wRegion.Max.Y, wRegion.Min.Y, -1 do
                if currentWorld:GetBlock(Vector3int16.new(wStartX, checkY, wStartZ)) then
                    return true
                end
            end
        end
        attempts = attempts + 1
    until attempts > 240
    return false
end

local function farmOnce()
    world = BWC.GetLocal()

    if not world then
        getgenv().statusText = "вход в ивент → #8..."
        enterMine()

        local deadline = tick() + 60
        repeat
            task.wait(0.3)
            world = BWC.GetLocal()
            if world then break end
            getgenv().statusText = "ожидание #8... "..math.floor(60 - (deadline - tick())).."с"
        until tick() >= deadline

        if not world then
            getgenv().statusText = "не удалось войти"
            Rayfield:Notify({Title="Ошибка", Content="Не удалось войти в #8", Duration=10})
            return false
        end
    end

    print("Шахта найдена")

    if not findBombUIDs() then
        getgenv().statusText = "бомбы не найдены"
        return false
    end

    region = world:GetRegion()
    origin = world:GetOrigin()

    if not region or not origin then
        getgenv().statusText = "нет данных шахты"
        return false
    end

    wentBelowCheckY = false

    if not waitForNewBlocks() then
        getgenv().statusText = "блоки не появились"
        return false
    end

    if not getgenv().curY or not getgenv().curX or not getgenv().curZ then
        getgenv().curY = region.Max.Y
        getgenv().curX = region.Min.X
        getgenv().curZ = region.Min.Z
    end

    getgenv().curX = tonumber(getgenv().curX) or region.Min.X
    getgenv().curY = tonumber(getgenv().curY) or region.Max.Y
    getgenv().curZ = tonumber(getgenv().curZ) or region.Min.Z

    local lastProgress = tick()

    while getgenv().curY >= region.Min.Y do
        if not getgenv().MagnusRunning then return false end

        if wasTeleportedToTop() then
            print("РЕСТАРТ! Вышел из farmOnce")
            getgenv().statusText = "рестарт локации"
            return true
        end

        local w = BWC.GetLocal()
        if not w then
            getgenv().statusText = "шахта пропала"
            return false
        end

        if tick() - lastProgress > CONFIG.TIMEOUT_SEC then
            getgenv().statusText = "таймаут"
            return false
        end

        getgenv().curX = getgenv().curX or region.Min.X
        local xStep = 1

        while getgenv().curX <= region.Max.X do
            if not getgenv().MagnusRunning then return false end

            getgenv().curZ = region.Min.Z
            local zStep = 1

            while getgenv().curZ <= region.Max.Z do
                if not getgenv().MagnusRunning then return false end
                if tick() - lastProgress > CONFIG.TIMEOUT_SEC then
                    getgenv().statusText = "таймаут"
                    return false
                end

                if wasTeleportedToTop() then
                    print("РЕСТАРТ во время прохода!")
                    return true
                end

                local pos = Vector3int16.new(getgenv().curX, getgenv().curY, getgenv().curZ)
                local ok, hasBlock = pcall(function() return world:GetBlock(pos) end)

                if ok and hasBlock then
                    local key = getBombKey(getgenv().curY)
                    local rX, rZ = getRadius(key)
                    getgenv().statusText = string.format("фарм Y=%d X=%d Z=%d", getgenv().curY, getgenv().curX, getgenv().curZ)

                    if not getHRP() then task.wait(0.02) end
                    tpGrid(getgenv().curX, getgenv().curY, getgenv().curZ)
                    task.wait(CONFIG.TP_SETTLE)
                    useBomb(key)
                    task.wait(CONFIG.DELAY)

                    zStep = rZ
                    getgenv().curZ = getgenv().curZ + zStep
                    lastProgress = tick()

                    if key == "green" then xStep = rX end
                else
                    getgenv().curZ = getgenv().curZ + 1
                end
            end

            getgenv().curX = getgenv().curX + xStep
        end

        getgenv().curY = getgenv().curY - 1
        getgenv().curX = region.Min.X
        getgenv().curZ = region.Min.Z
        getgenv().statusText = "слой Y="..getgenv().curY
        lastProgress = tick()
    end

    getgenv().curX, getgenv().curY, getgenv().curZ = nil, nil, nil
    getgenv().statusText = "цикл завершён"
    return true
end

local function startFarm()
    if getgenv().MagnusThread and coroutine.status(getgenv().MagnusThread) ~= "dead" then return end

    getgenv().MagnusThread = task.spawn(function()
        repeat task.wait(0.1) until LP and LP.Character and LP.Character:FindFirstChild("HumanoidRootPart")
        if not game:IsLoaded() then repeat task.wait(0.1) until game:IsLoaded() end

        while getgenv().MagnusRunning do
            if CONFIG.AUTO_FARM then
                local ok, err = pcall(farmOnce)
                if not ok then
                    warn("Ошибка в farmOnce:", err)
                    task.wait(2)
                end
                if getgenv().MagnusRunning then task.wait(CONFIG.REST_WAIT) end
            else
                task.wait(1)
            end
        end
    end)
end

local function stopFarm()
    getgenv().MagnusRunning = false
    getgenv().statusText = "остановлено"
end

local function resumeFarm()
    getgenv().MagnusRunning = true
    startFarm()
    getgenv().statusText = "возобновлено"
end

local function resetPos()
    getgenv().curX, getgenv().curY, getgenv().curZ = nil, nil, nil
    getgenv().statusText = "сброс позиции"
end

getgenv().MagnusStart = startFarm
getgenv().MagnusStop = stopFarm
getgenv().MagnusResume = resumeFarm
getgenv().MagnusResetPos = resetPos

game:GetService("UserInputService").InputBegan:Connect(function(i, g)
    if not g and i.KeyCode == Enum.KeyCode.T then
        if getgenv().MagnusRunning then
            stopFarm()
            Rayfield:Notify({Title="Стоп", Content="Остановлено", Duration=3})
        else
            resumeFarm()
            Rayfield:Notify({Title="Старт", Content="Возобновлено", Duration=3})
        end
    end
end)

print("BAZZ FINAL v7 загружен. Anti-AFK + WORLD_SPOTS + рестарт по Y. Нажми 'Auto Farm'.")
