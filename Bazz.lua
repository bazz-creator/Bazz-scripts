getgenv().SecureMode = true

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")
local LocalPlayer = Players.LocalPlayer

local CONFIG = {
    DELAY = 0.1,
    GREEN_MAX_Y = -50,
    AUTO_SELL = true,
    AUTO_RESTART = true,
    SAVE_POSITION = true,
    SEARCH_RADIUS = 500,
    BOMB_NAMES = {"Bomb", "TNT", "Dynamite", "Explosive"}
}

local LOGS = {}
local MAX_LOGS = 50

local function logMessage(msg)
    local timestamp = os.date("%H:%M:%S")
    local formatted = string.format("[%s] %s", timestamp, msg)
    table.insert(LOGS, formatted)
    if #LOGS > MAX_LOGS then table.remove(LOGS, 1) end
    print(formatted)
    return table.concat(LOGS, "\n")
end

local State = {
    IsRunning = false,
    CurrentY = 0,
    TargetY = 0,
    SavedPosition = nil,
    BombsLeft = "Неизвестно",
    Status = "Ожидание"
}

local RayfieldSuccess, Rayfield = pcall(function()
    return loadstring(game:HttpGet('https://raw.githubusercontent.com/shlexware/Rayfield/main/source'))()
end)

if not RayfieldSuccess or not Rayfield then
    warn("[BAZZ] Ошибка загрузки Rayfield UI. Проверьте интернет или ссылку.")
    return
end

local Window = Rayfield:CreateWindow({
    Name = "BAZZ — ECLIPSE RIFT v8",
    LoadingTitle = "Загрузка...",
    LoadingSubtitle = "by Bazz",
    ConfigurationSaving = { Enabled = true, FolderName = "BazzConfig", FileName = "EclipseRift" },
    KeySystem = false
})

local MainTab = Window:CreateTab("Главная", 4483362458)
local SettingsTab = Window:CreateTab("Настройки", 4483362458)
local StatsTab = Window:CreateTab("Статистика", 4483362458)
local LogTab = Window:CreateTab("Логи", 4483362458)

local LogParagraph = LogTab:CreateParagraph({
    Title = "Системные логи",
    Content = "Ожидание запуска..."
})

local function updateLogUI()
    LogParagraph:Set({ Title = "Системные логи", Content = table.concat(LOGS, "\n") })
end

local function findNearestBlock()
    local closestBlock = nil
    local minDistance = CONFIG.SEARCH_RADIUS
    local char = LocalPlayer.Character
    if not char or not char:FindFirstChild("HumanoidRootPart") then return nil end
    local rootPos = char.HumanoidRootPart.Position
    local blocksFolder = Workspace:FindFirstChild("Blocks") or Workspace:FindFirstChild("Ores") or Workspace
    for _, block in ipairs(blocksFolder:GetChildren()) do
        if block:IsA("BasePart") and block.Name ~= "Baseplate" then
            local dist = (block.Position - rootPos).Magnitude
            if dist < minDistance then
                minDistance = dist
                closestBlock = block
            end
        end
    end
    return closestBlock
end

local function checkBombs()
    local char = LocalPlayer.Character
    local backpack = LocalPlayer:FindFirstChild("Backpack")
    if not char or not backpack then return false end
    local hasBomb = false
    for _, name in ipairs(CONFIG.BOMB_NAMES) do
        if char:FindFirstChild(name) or backpack:FindFirstChild(name) then
            hasBomb = true
            State.BombsLeft = name
            break
        end
    end
    if not hasBomb then
        State.BombsLeft = "Нет бомб!"
        logMessage("Внимание: Бомбы закончились!")
        return false
    end
    return true
end

local function attemptAutoSell()
    if not CONFIG.AUTO_SELL then return end
    logMessage("Попытка авто-продажи...")
    task.wait(0.5)
end

local function saveCurrentPosition()
    if not CONFIG.SAVE_POSITION then return end
    local char = LocalPlayer.Character
    if char and char:FindFirstChild("HumanoidRootPart") then
        State.SavedPosition = char.HumanoidRootPart.CFrame
        logMessage("Позиция сохранена.")
    end
end

local function restorePosition()
    if State.SavedPosition and CONFIG.SAVE_POSITION then
        local char = LocalPlayer.Character
        if char and char:FindFirstChild("HumanoidRootPart") then
            char.HumanoidRootPart.CFrame = State.SavedPosition
            logMessage("Позиция восстановлена.")
        end
    end
end

local function farmLoop()
    logMessage("Запуск цикла фарма...")
    State.Status = "Фарм"
    while State.IsRunning do
        if not checkBombs() then
            State.IsRunning = false
            State.Status = "Остановлено (нет бомб)"
            break
        end
        local targetBlock = findNearestBlock()
        if targetBlock then
            logMessage("Найден блок: " .. targetBlock.Name)
            task.wait(CONFIG.DELAY)
            task.wait(1)
        else
            logMessage("Блоки не найдены в радиусе. Ожидание...")
            task.wait(2)
        end
        local char = LocalPlayer.Character
        if char and char:FindFirstChild("HumanoidRootPart") then
            State.CurrentY = math.floor(char.HumanoidRootPart.Position.Y)
            if State.CurrentY > CONFIG.GREEN_MAX_Y + 100 then
                logMessage("Обнаружен телепорт наверх! Рестарт...")
                saveCurrentPosition()
                attemptAutoSell()
                if CONFIG.AUTO_RESTART then
                    State.IsRunning = false
                    task.wait(2)
                end
            end
        end
        task.wait(CONFIG.DELAY)
    end
    logMessage("Цикл фарма остановлен.")
    State.Status = "Остановлено"
end

MainTab:CreateToggle({
    Name = "Запустить фарм",
    CurrentValue = false,
    Flag = "StartFarm",
    Callback = function(value)
        State.IsRunning = value
        if value then
            task.spawn(farmLoop)
        end
    end
})

MainTab:CreateButton({
    Name = "Остановить (Стоп)",
    Callback = function()
        State.IsRunning = false
        logMessage("Принудительная остановка.")
    end
})

MainTab:CreateButton({
    Name = "Сохранить позицию",
    Callback = function() saveCurrentPosition() end
})

MainTab:CreateButton({
    Name = "Восстановить позицию",
    Callback = function() restorePosition() end
})

SettingsTab:CreateSection("Порог высоты")
SettingsTab:CreateSlider({
    Name = "GREEN_MAX_Y",
    Range = {-200, 0},
    Increment = 1,
    Suffix = "Y",
    CurrentValue = CONFIG.GREEN_MAX_Y,
    Flag = "GreenMaxY",
    Callback = function(value)
        CONFIG.GREEN_MAX_Y = value
        logMessage("GREEN_MAX_Y изменен на: " .. value)
    end
})

SettingsTab:CreateSection("Задержки")
SettingsTab:CreateSlider({
    Name = "DELAY",
    Range = {0.01, 1},
    Increment = 0.01,
    Suffix = "c",
    CurrentValue = CONFIG.DELAY,
    Flag = "Delay",
    Callback = function(value)
        CONFIG.DELAY = value
        logMessage("DELAY изменен на: " .. value)
    end
})

SettingsTab:CreateToggle({
    Name = "Авто-продажа",
    CurrentValue = CONFIG.AUTO_SELL,
    Flag = "AutoSell",
    Callback = function(value)
        CONFIG.AUTO_SELL = value
        logMessage("Авто-продажа: " .. (value and "ВКЛ" or "ВЫКЛ"))
    end
})

SettingsTab:CreateToggle({
    Name = "Сохранять позицию",
    CurrentValue = CONFIG.SAVE_POSITION,
    Flag = "SavePos",
    Callback = function(value)
        CONFIG.SAVE_POSITION = value
        logMessage("Сохранение позиции: " .. (value and "ВКЛ" or "ВЫКЛ"))
    end
})

local StatsParagraph = StatsTab:CreateParagraph({
    Title = "Текущий статус",
    Content = "Статус: Ожидание\nТекущий Y: 0\nЦелевой Y: 0\nБомбы: Неизвестно"
})

task.spawn(function()
    while true do
        task.wait(1)
        if StatsParagraph then
            StatsParagraph:Set({
                Title = "Текущий статус",
                Content = string.format(
                    "Статус: %s\nТекущий Y: %d\nЦелевой Y: %d\nБомбы: %s\n\nЛогов в буфере: %d",
                    State.Status, State.CurrentY, State.TargetY, State.BombsLeft, #LOGS
                )
            })
        end
    end
end)

task.spawn(function()
    while true do
        task.wait(2)
        updateLogUI()
    end
end)

logMessage("Скрипт BAZZ v8 успешно загружен!")
State.Status = "Готов"

Rayfield:Notify({
    Title = "BAZZ v8",
    Content = "Скрипт успешно загружен.",
    Duration = 5,
    Image = 4483362458
})
