-- ==========================================
-- BAZZ — ECLIPSE RIFT (RAYFIELD GUI)
-- + АВТО-ВХОД + Убраны ложные проверки для iPhone
-- БЕЗ КЛЮЧА
-- ==========================================
print("🚀 BAZZ")

local CONFIG = {
    TP_SETTLE = 0.1,
    DELAY     = 0.15,
    REST_WAIT = 10,
    TIMEOUT_SEC = 120,
    WORLD_RESET_DELAY = 8,
    WORLD_LOAD_MAX = 40,
    GREEN_MAX_Y = -60,
    RADIUS_GREEN_X = 1,
    RADIUS_GREEN_Z = 1,
    RADIUS_YELLOW_X = 3,
    RADIUS_YELLOW_Z = 3,
    FORCE_BOMB = "auto",
    AUTO_FARM = true,
}

local ORE_ID   = "Eclipse Onyx Gem"
local ORE_NAME = "Eclipse Onyx"

local RS = game:GetService("ReplicatedStorage")
local Network = nil
pcall(function() Network = RS:WaitForChild("Network", 10) end)

local Save = require(RS.Library.Client.Save)
local Blocks = require(RS.Library.Types.Blocks)
local BWC = require(RS.Library.Client.ToolCmds.BlockWorldClient)

local Consume = nil
if Network then
    pcall(function() Consume = Network:WaitForChild("Consumables_Consume", 10) end)
end

local EnterInstance = nil
if Network then
    pcall(function()
        EnterInstance = Network:WaitForChild("Instancing_PlayerEnterInstance", 10)
    end)
end

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
    CurrentValue = true,
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
MainTab:CreateButton({Name="⛏ Войти в шахту", Callback=function()
    if getgenv().BazzEnterMine then
        getgenv().BazzEnterMine()
        Rayfield:Notify({Title="Вход", Content="Вызов входа...", Duration=3})
    end
end})

local SettingsTab = Window:CreateTab("Settings", 4483362458)
SettingsTab:CreateSection("Порог высоты")
SettingsTab:CreateSlider({Name="GREEN_MAX_Y", Range={-200,0}, Increment=1, Suffix="Y", CurrentValue=-60, Flag="GreenMaxY", Callback=function(v) CONFIG.GREEN_MAX_Y=v end})
SettingsTab:CreateSection("Задержки")
SettingsTab:CreateSlider({Name="DELAY", Range={0.05,1}, Increment=0.05, Suffix="с", CurrentValue=0.15, Flag="Delay", Callback=function(v) CONFIG.DELAY=v end})
SettingsTab:CreateSlider({Name="TP_SETTLE", Range={0.05,1}, Increment=0.05, Suffix="с", CurrentValue=0.1, Flag="TPSettle", Callback=function(v) CONFIG.TP_SETTLE=v end})
SettingsTab:CreateSlider({Name="REST_WAIT", Range={5,300}, Increment=5, Suffix="с", CurrentValue=10, Flag="RestWait", Callback=function(v) CONFIG.REST_WAIT=v end})

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

local LP = game.Players.LocalPlayer
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
    local cf = Blocks.BlockCFrame(origin, Vector3int16.new(x, y, z))
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
    if not EnterInstance then
        warn("⚠ Instancing_PlayerEnterInstance не найден")
        return false
    end
    local ok, result = pcall(function()
        return EnterInstance:InvokeServer("SpaceMiningEvent")
    end)
    if ok and result then
        print("⛏ Вход выполнен:", result)
        return true
    end
    warn("⚠ Ошибка входа:", result)
    return false
end

getgenv().BazzEnterMine = enterMine

local function farmOnce()
    -- Проверка мира
    world = BWC.GetLocal()

    -- Авто-вход
    if not world then
        getgenv().statusText = "не в шахте — вход..."
        enterMine()

        local deadline = tick() + CONFIG.WORLD_LOAD_MAX
        repeat
            task.wait(0.25)
            world = BWC.GetLocal()
            if world then break end
            getgenv().statusText = "ожидание... "..math.floor(CONFIG.WORLD_LOAD_MAX - (deadline - tick())).."с"
        until tick() >= deadline

        if not world then
            getgenv().statusText = "не удалось войти"
            Rayfield:Notify({Title="Ошибка", Content="Не удалось войти", Duration=8})
            return false
        end
    end

    print("✅ Шахта найдена")

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

    -- Ждём прогрузки текстур (важно для iPhone)
    getgenv().statusText = "прогрузка шахты..."
    task.wait(CONFIG.WORLD_RESET_DELAY)

    -- Проверяем верхний блок
    local cx = region.Min.X + 1
    local cz = region.Min.Z + 1
    local waitStart = tick()
    while tick() - waitStart < CONFIG.WORLD_LOAD_MAX do
        if world:GetBlock(Vector3int16.new(cx, region.Max.Y, cz)) then
            break
        end
        task.wait(0.5)
    end

    task.wait(2)

    -- Инициализация позиции (только если её нет)
    if not getgenv().curY then
        getgenv().curY = region.Max.Y
        getgenv().curX = region.Min.X
        getgenv().curZ = region.Min.Z
        print("🆕 Начинаю с Y="..getgenv().curY)
    else
        print("▶ Продолжаю с Y="..getgenv().curY)
    end

    local lastProgress = tick()

    -- Основной фарм
    while getgenv().curY >= region.Min.Y do
        if not getgenv().MagnusRunning then return false end
        if not BWC.GetLocal() then
            getgenv().statusText = "шахта пропала"
            return false
        end

        if tick() - lastProgress > CONFIG.TIMEOUT_SEC then
            getgenv().statusText = "таймаут"
            return false
        end

        getgenv().curX = getgenv().curX or region.Min.X

        while getgenv().curX <= region.Max.X do
            if not getgenv().MagnusRunning then return false end

            getgenv().curZ = region.Min.Z

            while getgenv().curZ <= region.Max.Z do
                if not getgenv().MagnusRunning then return false end
                if tick() - lastProgress > CONFIG.TIMEOUT_SEC then
                    getgenv().statusText = "таймаут"
                    return false
                end

                local pos = Vector3int16.new(getgenv().curX, getgenv().curY, getgenv().curZ)
                local ok, hasBlock = pcall(function() return world:GetBlock(pos) end)

                if ok and hasBlock then
                    local key = getBombKey(getgenv().curY)
                    local rX, rZ = getRadius(key)

                    getgenv().statusText = string.format("фарм Y=%d X=%d Z=%d", getgenv().curY, getgenv().curX, getgenv().curZ)

                    if not getHRP() then task.wait(0.1) end
                    tpGrid(getgenv().curX, getgenv().curY, getgenv().curZ)
                    task.wait(CONFIG.TP_SETTLE)
                    useBomb(key)
                    task.wait(CONFIG.DELAY)

                    getgenv().curZ = getgenv().curZ + math.max(rX, rZ)
                    lastProgress = tick()
                else
                    getgenv().curZ = getgenv().curZ + 1
                end
            end

            getgenv().curX = getgenv().curX + 1
        end

        getgenv().curY = getgenv().curY - 1
        getgenv().curX = region.Min.X
        getgenv().curZ = region.Min.Z
        getgenv().statusText = "слой Y="..getgenv().curY
        lastProgress = tick()
    end

    -- Шахта пройдена
    getgenv().curX, getgenv().curY, getgenv().curZ = nil, nil, nil
    getgenv().statusText = "цикл завершён"
    return false
end

local function startFarm()
    if getgenv().MagnusThread and coroutine.status(getgenv().MagnusThread) ~= "dead" then return end

    getgenv().MagnusThread = task.spawn(function()
        repeat task.wait(0.1) until LP and LP.Character and LP.Character:FindFirstChild("HumanoidRootPart")
        if not game:IsLoaded() then repeat task.wait(0.1) until game:IsLoaded() end

        while getgenv().MagnusRunning do
            if CONFIG.AUTO_FARM then
                local ok = farmOnce()
                if not ok and getgenv().MagnusRunning then task.wait(3) else task.wait(CONFIG.REST_WAIT) end
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

task.spawn(function()
    repeat task.wait(0.2) until game:IsLoaded()
    repeat task.wait(0.2) until LP.Character and LP.Character:FindFirstChild("HumanoidRootPart")
    task.wait(2)
    CONFIG.AUTO_FARM = true
    resumeFarm()
    Rayfield:Notify({Title="Bazz", Content="Автофарм запущен", Duration=4})
end)

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

print("✅ BAZZ загружен. БЕЗ КЛЮЧА.")
