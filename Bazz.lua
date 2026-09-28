-- ==========================================
-- BAZZ — ECLIPSE RIFT (RAYFIELD GUI)
-- Drill Array + Core Charge | Auto Farm | Слоями вниз
-- + Watchdog (авто-восстановление) + Учёт радиуса
-- KEY: soprano2026
-- ==========================================
print("🚀 BAZZ")

-- =====================
-- НАСТРОЙКИ
-- =====================
local CONFIG = {
    TP_SETTLE = 0.1,
    DELAY     = 0.15,
    REST_WAIT = 30,
    TIMEOUT_SEC = 60,
    WORLD_RESET_DELAY = 3,
    GREEN_MAX_Y = -60,
    RADIUS_GREEN_X = 1,
    RADIUS_GREEN_Z = 1,
    RADIUS_YELLOW_X = 3,
    RADIUS_YELLOW_Z = 3,
    FORCE_BOMB = "auto",
    AUTO_FARM = false,
}

local ORE_ID   = "Eclipse Onyx Gem"
local ORE_NAME = "Eclipse Onyx"

-- =====================
-- МОДУЛИ
-- =====================
local RS = game:GetService("ReplicatedStorage")
local Network = RS:WaitForChild("Network")
local Save = require(RS.Library.Client.Save)
local Blocks = require(RS.Library.Types.Blocks)
local BWC = require(RS.Library.Client.ToolCmds.BlockWorldClient)
local Consume = Network:WaitForChild("Consumables_Consume")

-- =====================
-- БОМБЫ
-- =====================
local BOMB_UIDS = { green = nil, yellow = nil }

local function findBombUIDs()
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
    local d = Save.Get()
    if not d or not d.Inventory or not d.Inventory.Misc then return 0 end
    local n = 0
    for _, x in pairs(d.Inventory.Misc) do
        if tostring(x.id) == ORE_ID then n = n + (x._am or 1) end
    end
    return n
end

repeat task.wait(0.1) until Save.Get() and Save.Get().Inventory and Save.Get().Inventory.Consumable

local START_GREEN, START_YELLOW = countBombs("green"), countBombs("yellow")
local START_ORE, START_TIME = countOre(), tick()

-- =====================
-- RAYFIELD GUI (с ключом)
-- =====================
local Rayfield = loadstring(game:HttpGet('https://sirius.menu/rayfield'))()

local Window = Rayfield:CreateWindow({
    Name = "Bazz",
    LoadingTitle = "Bazz",
    LoadingSubtitle = "Eclipse Rift Auto Farm",
    ConfigurationSaving = {
        Enabled = true,
        FolderName = "Bazz",
        FileName = "Config"
    },
    KeySystem = true,
    KeySettings = {
        Title = "Bazz — Key",
        Subtitle = "Введи ключ доступа",
        Note = "Ключ у Bazz",
        FileName = "BazzKey",
        SaveKey = true,
        GrabKeyFromSite = false,
        Key = {"soprano2026"}
    },
    Keybind = "K"
})

-- =====================
-- ВКЛАДКА MAIN
-- =====================
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
            if getgenv().MagnusResume then
                getgenv().MagnusResume()
            elseif getgenv().MagnusStart then
                getgenv().MagnusStart()
            end
            Rayfield:Notify({Title="Старт", Content="Фарм запущен", Duration=3})
        else
            if getgenv().MagnusStop then
                getgenv().MagnusStop()
            end
            Rayfield:Notify({Title="Стоп", Content="Фарм остановлен", Duration=3})
        end
        print("Auto Farm:", v)
    end,
})

MainTab:CreateSection("Режим бомб")

MainTab:CreateToggle({
    Name = "Force Green (Drill Array)",
    CurrentValue = false,
    Flag = "ForceGreen",
    Callback = function(v)
        if v then
            CONFIG.FORCE_BOMB = "green"
            Rayfield:Notify({Title="Режим", Content="Всегда зелёные", Duration=3})
        else
            CONFIG.FORCE_BOMB = "auto"
        end
    end,
})

MainTab:CreateToggle({
    Name = "Force Yellow (Core Charge)",
    CurrentValue = false,
    Flag = "ForceYellow",
    Callback = function(v)
        if v then
            CONFIG.FORCE_BOMB = "yellow"
            Rayfield:Notify({Title="Режим", Content="Всегда жёлтые", Duration=3})
        else
            CONFIG.FORCE_BOMB = "auto"
        end
    end,
})

MainTab:CreateSection("Управление")

MainTab:CreateButton({
    Name = "🔄 Сброс позиции (с начала)",
    Callback = function()
        getgenv().MagnusResetPos()
        Rayfield:Notify({Title="Сброс", Content="Позиция сброшена", Duration=3})
    end,
})

-- =====================
-- ВКЛАДКА SETTINGS
-- =====================
local SettingsTab = Window:CreateTab("Settings", 4483362458)

SettingsTab:CreateSection("Порог высоты")

SettingsTab:CreateSlider({
    Name = "GREEN_MAX_Y",
    Range = {-200, 0},
    Increment = 1,
    Suffix = "Y",
    CurrentValue = -60,
    Flag = "GreenMaxY",
    Callback = function(v) CONFIG.GREEN_MAX_Y = v end,
})

SettingsTab:CreateSection("Задержки")

SettingsTab:CreateSlider({
    Name = "DELAY (после броска)",
    Range = {0.05, 1}, Increment = 0.05, Suffix = "с",
    CurrentValue = 0.15, Flag = "Delay",
    Callback = function(v) CONFIG.DELAY = v end,
})

SettingsTab:CreateSlider({
    Name = "TP_SETTLE (после телепорта)",
    Range = {0.05, 1}, Increment = 0.05, Suffix = "с",
    CurrentValue = 0.1, Flag = "TPSettle",
    Callback = function(v) CONFIG.TP_SETTLE = v end,
})

SettingsTab:CreateSlider({
    Name = "REST_WAIT (пауза между циклами)",
    Range = {5, 300}, Increment = 5, Suffix = "с",
    CurrentValue = 30, Flag = "RestWait",
    Callback = function(v) CONFIG.REST_WAIT = v end,
})

SettingsTab:CreateSlider({
    Name = "WORLD_RESET_DELAY (пауза после рестарта)",
    Range = {1, 30}, Increment = 1, Suffix = "с",
    CurrentValue = 3, Flag = "WorldResetDelay",
    Callback = function(v) CONFIG.WORLD_RESET_DELAY = v end,
})

SettingsTab:CreateSlider({
    Name = "TIMEOUT (макс. сек без прогресса)",
    Range = {10, 300}, Increment = 5, Suffix = "с",
    CurrentValue = 60, Flag = "TimeoutSec",
    Callback = function(v) CONFIG.TIMEOUT_SEC = v end,
})

SettingsTab:CreateSection("Радиус — ЗЕЛЁНЫЕ (Drill Array)")

SettingsTab:CreateSlider({
    Name = "Green Width X", Range = {1, 10}, Increment = 1, Suffix = " блоков",
    CurrentValue = 1, Flag = "RadiusGreenX",
    Callback = function(v) CONFIG.RADIUS_GREEN_X = v end,
})

SettingsTab:CreateSlider({
    Name = "Green Length Z", Range = {1, 10}, Increment = 1, Suffix = " блоков",
    CurrentValue = 1, Flag = "RadiusGreenZ",
    Callback = function(v) CONFIG.RADIUS_GREEN_Z = v end,
})

SettingsTab:CreateSection("Радиус — ЖЁЛТЫЕ (Core Charge)")

SettingsTab:CreateSlider({
    Name = "Yellow Width X", Range = {1, 10}, Increment = 1, Suffix = " блоков",
    CurrentValue = 3, Flag = "RadiusYellowX",
    Callback = function(v) CONFIG.RADIUS_YELLOW_X = v end,
})

SettingsTab:CreateSlider({
    Name = "Yellow Length Z", Range = {1, 10}, Increment = 1, Suffix = " блоков",
    CurrentValue = 3, Flag = "RadiusYellowZ",
    Callback = function(v) CONFIG.RADIUS_YELLOW_Z = v end,
})

-- =====================
-- ВКЛАДКА STATS
-- =====================
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

-- =====================
-- ФАРМ
-- =====================
local LP = game.Players.LocalPlayer
local world, region, origin

getgenv().MagnusRunning = false
getgenv().MagnusThread = nil
getgenv().WatchdogThread = nil
getgenv().curX = nil
getgenv().curY = nil
getgenv().curZ = nil
getgenv().lastWorld = nil
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
    local cf = Blocks.BlockCFrame(origin, Vector3int16.new(x, y, z))
    tp(cf.Position + Vector3.new(0, 3, 0))
end

local function useBomb(key)
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
    if key == "green" then
        return CONFIG.RADIUS_GREEN_X, CONFIG.RADIUS_GREEN_Z
    else
        return CONFIG.RADIUS_YELLOW_X, CONFIG.RADIUS_YELLOW_Z
    end
end

local function farmOnce()
    getgenv().statusText = "поиск мира..."
    world = nil
    local att = 0
    repeat task.wait(0.2); world = BWC.GetLocal(); att = att + 1 until world or att > 60
    if not world then
        getgenv().statusText = "мир не загрузился"
        Rayfield:Notify({Title="Ошибка", Content="Мир не загрузился", Duration=5})
        return false
    end

    if not findBombUIDs() then
        getgenv().statusText = "бомбы не найдены"
        Rayfield:Notify({Title="Ошибка", Content="Бомбы не найдены", Duration=5})
        return false
    end

    region, origin = world:GetRegion(), world:GetOrigin()

    local savedWorld = world
    if not getgenv().curY or getgenv().lastWorld ~= savedWorld then
        getgenv().statusText = "новый мир — ждём "..CONFIG.WORLD_RESET_DELAY.."с"
        task.wait(CONFIG.WORLD_RESET_DELAY)
        getgenv().curY = region.Max.Y
        getgenv().curX = region.Min.X
        getgenv().curZ = region.Min.Z
        getgenv().lastWorld = savedWorld
        print("🔄 Новый мир — начинаю с Y="..getgenv().curY)
        getgenv().statusText = "новый мир, Y="..getgenv().curY
    end

    local lastProgress = tick()

    while getgenv().curY >= region.Min.Y do
        if not getgenv().MagnusRunning then return true end

        if BWC.GetLocal() ~= savedWorld then
            print("🔁 Мир сменился — выхожу из farmOnce")
            getgenv().curX, getgenv().curY, getgenv().curZ = nil, nil, nil
            getgenv().lastWorld = nil
            getgenv().statusText = "мир сменился, перезапуск"
            return true
        end

        getgenv().curX = getgenv().curX or region.Min.X
        local xStep = 1

        while getgenv().curX <= region.Max.X do
            if not getgenv().MagnusRunning then return true end
            if BWC.GetLocal() ~= savedWorld then
                getgenv().curX, getgenv().curY, getgenv().curZ = nil, nil, nil
                getgenv().lastWorld = nil
                getgenv().statusText = "мир сменился, перезапуск"
                return true
            end

            getgenv().curZ = region.Min.Z
            local zStep = 1

            while getgenv().curZ <= region.Max.Z do
                if not getgenv().MagnusRunning then return true end
                if BWC.GetLocal() ~= savedWorld then
                    getgenv().curX, getgenv().curY, getgenv().curZ = nil, nil, nil
                    getgenv().lastWorld = nil
                    getgenv().statusText = "мир сменился, перезапуск"
                    return true
                end

                if tick() - lastProgress > CONFIG.TIMEOUT_SEC then
                    print("⏰ Таймаут "..CONFIG.TIMEOUT_SEC.." сек — выхожу")
                    getgenv().statusText = "таймаут, выхожу"
                    return true
                end

                local hasBlock = world:GetBlock(Vector3int16.new(getgenv().curX, getgenv().curY, getgenv().curZ))
                if hasBlock then
                    local key = getBombKey(getgenv().curY)
                    local rX, rZ = getRadius(key)

                    getgenv().statusText = string.format("фарм Y=%d X=%d Z=%d", getgenv().curY, getgenv().curX, getgenv().curZ)

                    if not getHRP() then task.wait(0.1) end
                    tpGrid(getgenv().curX, getgenv().curY, getgenv().curZ)
                    task.wait(CONFIG.TP_SETTLE)
                    useBomb(key)
                    task.wait(CONFIG.DELAY)

                    zStep = math.max(rX, rZ)
                    getgenv().curZ = getgenv().curZ + zStep
                    lastProgress = tick()
                else
                    getgenv().curZ = getgenv().curZ + 1
                end
            end

            xStep = zStep
            getgenv().curX = getgenv().curX + xStep
        end

        getgenv().curY = getgenv().curY - 1
        getgenv().curX = region.Min.X
        getgenv().curZ = region.Min.Z
        print("⛏ Слой: Y="..getgenv().curY)
        getgenv().statusText = "слой Y="..getgenv().curY
        lastProgress = tick()
    end

    getgenv().curX, getgenv().curY, getgenv().curZ = nil, nil, nil
    getgenv().lastWorld = nil
    getgenv().statusText = "цикл завершён"
    return true
end

local function startFarm()
    if getgenv().MagnusThread then
        if coroutine.status(getgenv().MagnusThread) ~= "dead" then
            return
        end
    end

    getgenv().MagnusThread = task.spawn(function()
        repeat task.wait(0.1) until LP and LP.Character and LP.Character:FindFirstChild("HumanoidRootPart")
        if not game:IsLoaded() then repeat task.wait(0.1) until game:IsLoaded() end

        while getgenv().MagnusRunning do
            if CONFIG.AUTO_FARM then
                if getgenv().WatchdogThread then
                    if coroutine.status(getgenv().WatchdogThread) ~= "dead" then
                        task.cancel(getgenv().WatchdogThread)
                    end
                end

                local startTick = tick()
                local startX, startY, startZ = getgenv().curX, getgenv().curY, getgenv().curZ

                getgenv().WatchdogThread = task.spawn(function()
                    while getgenv().MagnusRunning do
                        task.wait(10)
                        local now = tick()
                        local moved = (getgenv().curX ~= startX) or (getgenv().curY ~= startY) or (getgenv().curZ ~= startZ)
                        if moved then
                            startTick = now
                            startX, startY, startZ = getgenv().curX, getgenv().curY, getgenv().curZ
                        elseif now - startTick > CONFIG.TIMEOUT_SEC then
                            print("🐕 Watchdog: скрипт застрял — сбрасываю позицию")
                            getgenv().curX, getgenv().curY, getgenv().curZ = nil, nil, nil
                            getgenv().lastWorld = nil
                            startTick = now
                            startX, startY, startZ = nil, nil, nil
                        end
                    end
                end)

                local ok = farmOnce()
                if not ok and getgenv().MagnusRunning then task.wait(3) end
            end
            if not getgenv().MagnusRunning then break end
            getgenv().statusText = "пауза "..CONFIG.REST_WAIT.."с"
            task.wait(CONFIG.REST_WAIT)
        end
        print("⏹ Цикл фарма завершён")
    end)
end

local function stopFarm()
    getgenv().MagnusRunning = false
    print("⏹ Остановлено (X="..tostring(getgenv().curX)..", Y="..tostring(getgenv().curY)..", Z="..tostring(getgenv().curZ)..")")
    getgenv().statusText = "остановлено"
end

local function resumeFarm()
    getgenv().MagnusRunning = true
    startFarm()
    print("▶️ Возобновлено (X="..tostring(getgenv().curX)..", Y="..tostring(getgenv().curY)..", Z="..tostring(getgenv().curZ)..")")
    getgenv().statusText = "возобновлено"
end

local function resetPos()
    getgenv().curX, getgenv().curY, getgenv().curZ = nil, nil, nil
    getgenv().lastWorld = nil
    print("🔄 Позиция сброшена")
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
            Rayfield:Notify({Title="Стоп", Content="Фарм остановлен (T)", Duration=3})
        else
            resumeFarm()
            Rayfield:Notify({Title="Старт", Content="Фарм возобновлён (T)", Duration=3})
        end
    end
end)

print("✅ BAZZ загружен. Ключ: soprano2026")
