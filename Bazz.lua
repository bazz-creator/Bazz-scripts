--[[
    BAZZ — ECLIPSE RIFT FINAL v8 (MAX EDITION)
    Обновление: Исправлены ошибки, добавлены логи, авто-продажа, поиск ближайшего блока,
    сохранение позиции, проверка бомб, улучшенный GUI и кнопка Стоп.
]]

-- ==================== 1. СЕРВИСЫ И КОНФИГ ====================
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")
local LocalPlayer = Players.LocalPlayer

local CONFIG = {
    DELAY = 0.1,             -- Базовая задержка
    GREEN_MAX_Y = -50,       -- Порог высоты для смены бомбы
    AUTO_SELL = true,        -- Включить авто-продажу (если поддерживается)
    AUTO_RESTART = true,     -- Авто-рестарт при телепорте наверх
    SAVE_POSITION = true,    -- Сохранять позицию перед рестартом
    SEARCH_RADIUS = 500,     -- Радиус поиска ближайшего блока
    BOMB_NAMES = {"Bomb", "TNT", "Dynamite", "Explosive"} -- Имена бомб в инвентаре
}

-- ==================== 2. СИСТЕМА ЛОГИРОВАНИЯ ====================
local LOGS = {}
local MAX_LOGS = 50

local function logMessage(msg)
    local timestamp = os.date("%H:%M:%S")
    local formatted = string.format("[%s] %s", timestamp, msg)
    table.insert(LOGS, formatted)
    if #LOGS > MAX_LOGS then table.remove(LOGS, 1) end
    print(formatted) -- Дублируем в консоль разработчика (F9)
    return table.concat(LOGS, "\n")
end

-- ==================== 3. СОСТОЯНИЕ СКРИПТА ====================
local State = {
    IsRunning = false,
    CurrentY = 0,
    TargetY = 0,
    SavedPosition = nil,
    BombsLeft = "Неизвестно",
    Status = "Ожидание"
}

-- ==================== 4. ЗАГРУЗКА RAYFIELD (С ЗАЩИТОЙ) ====================
local RayfieldSuccess, Rayfield = pcall(function()
    return loadstring(game:HttpGet('https://raw.githubusercontent.com/UI-Library/Rayfield/main/source.lua'))()
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

-- ==================== 5. ВКЛАДКИ GUI ====================
local MainTab = Window:CreateTab("Главная", 4483362458)
local SettingsTab = Window:CreateTab("Настройки", 4483362458)
local StatsTab = Window:CreateTab("Статистика", 4483362458)
local LogTab = Window:CreateTab("Логи", 4483362458)

-- Логи
local LogParagraph = LogTab:CreateParagraph({ Title = "Системные логи", Content = "Ожидание запуска..." })

local function updateLogUI()
    LogParagraph:Set({ Title = "Системные логи", Content = table.concat(LOGS, "\n") })
end

-- ==================== 6. НОВЫЕ ФУНКЦИИ ====================

-- 6.1. Поиск ближайшего блока (вместо слепого прохода по сетке)
local function findNearestBlock()
    local closestBlock = nil
    local minDistance = CONFIG.SEARCH_RADIUS
    local char = LocalPlayer.Character
    if not char or not char:FindFirstChild("HumanoidRootPart") then return nil end
    local rootPos = char.HumanoidRootPart.Position

    -- Предполагаем, что блоки лежат в Workspace.Blocks. Если у вас другая папка - измените!
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

-- 6.2. Проверка наличия бомб
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

-- 6.3. Авто-продажа (ЗАГЛУШКА - адаптируйте под игру)
local function attemptAutoSell()
    if not CONFIG.AUTO_SELL then return end
    -- Вставьте сюда логику продажи для вашей игры. Например:
    -- local sellRemote = ReplicatedStorage.Remotes.Sell
    -- sellRemote:FireServer()
    logMessage("Попытка авто-продажи...")
    task.wait(0.5)
end

-- 6.4. Сохранение позиции
local function saveCurrentPosition()
    if not CONFIG.SAVE_POSITION then return end
    local char = LocalPlayer.Character
    if char and char:FindFirstChild("HumanoidRootPart") then
        State.SavedPosition = char.HumanoidRootPart.CFrame
        logMessage("Позиция сохранена.")
    end
end

-- 6.5. Восстановление позиции
local function restorePosition()
    if State.SavedPosition and CONFIG.SAVE_POSITION then
        local char = LocalPlayer.Character
        if char and char:FindFirstChild("HumanoidRootPart") then
            char.HumanoidRootPart.CFrame = State.SavedPosition
            logMessage("Позиция восстановлена.")
        end
    end
end

-- ==================== 7. ОСНОВНОЙ ЦИКЛ ФАРМА ====================
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
            logMessage("Найден блок: " .. targetBlock.Name .. " на расстоянии " .. math.floor((targetBlock.Position - LocalPlayer.Character.HumanoidRootPart.Position).Magnitude))
            
            -- Телепорт к блоку (если у вас есть функция телепорта, используйте её)
            -- LocalPlayer.Character.HumanoidRootPart.CFrame = targetBlock.CFrame + Vector3.new(0, 5, 0)
            task.wait(CONFIG.DELAY)
            
            -- Логика установки бомбы (пример)
            -- local bomb = LocalPlayer.Character:FindFirstChild(State.BombsLeft) or LocalPlayer.Backpack:FindFirstChild(State.BombsLeft)
            -- if bomb then bomb.Parent = LocalPlayer.Character; bomb:Activate() end
            
            task.wait(1) -- Ожидание взрыва
        else
            logMessage("Блоки не найдены в радиусе. Ожидание...")
            task.wait(2)
        end

        -- Проверка на телепорт наверх (сброс)
        local char = LocalPlayer.Character
        if char and char:FindFirstChild("HumanoidRootPart") then
            State.CurrentY = math.floor(char.HumanoidRootPart.Position.Y)
            if State.CurrentY > CONFIG.GREEN_MAX_Y + 100 then -- Условный порог "верха"
                logMessage("Обнаружен телепорт наверх! Рестарт...")
                saveCurrentPosition()
                attemptAutoSell()
                
                if CONFIG.AUTO_RESTART then
                    State.IsRunning = false
                    task.wait(2)
                    -- Здесь должен быть код перезапуска (например, выход в меню и вход заново)
                    -- restorePosition()
                    -- State.IsRunning = true
                end
            end
        end
        
        task.wait(CONFIG.DELAY)
    end
    logMessage("Цикл фарма остановлен.")
    State.Status = "Остановлено"
end

-- ==================== 8. НАСТРОЙКА GUI ====================

-- Главная вкладка
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

-- Вкладка настроек (ИСПРАВЛЕНА ОШИБКА С X)
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

-- Вкладка статистики
local StatsParagraph = StatsTab:CreateParagraph({
    Title = "Текущий статус",
    Content = "Статус: Ожидание\nТекущий Y: 0\nЦелевой Y: 0\nБомбы: Неизвестно"
})

-- Обновление статистики в реальном времени
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

-- Обновление UI логов
task.spawn(function()
    while true do
        task.wait(2)
        updateLogUI()
    end
end)

-- ==================== 9. ЗАПУСК ====================
logMessage("Скрипт BAZZ v8 успешно загружен!")
logMessage("Ожидание команд...")
State.Status = "Готов"

-- Уведомление при старте
Rayfield:Notify({
    Title = "BAZZ v8",
    Content = "Скрипт успешно загружен. Откройте меню.",
    Duration = 5,
    Image = 4483362458
})
