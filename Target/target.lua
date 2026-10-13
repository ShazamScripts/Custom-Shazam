local targetbotMacro = nil
-- Alvo persistente: evita alternancia por pequenas variacoes de HP.
local lockedTargetId = nil
local SWITCH_HP_ADVANTAGE = 0 -- troca por qualquer HP menor; empate preserva o alvo atual
local config = nil
local lastAction = 0
local cavebotAllowance = 0
local lureEnabled = true
local dangerValue = 0
local looterStatus = ""

-- ui
local configWidget = UI.Config()
local ui = UI.createWidget("TargetBotPanel")

ui.list = ui.listPanel.list -- shortcut
TargetBot.targetList = ui.list
TargetBot.Looting.setup()

ui.status.left:setText("Status:")
ui.status.right:setText("Off")
ui.target.left:setText("Target:")
ui.target.right:setText("-")
ui.config.left:setText("Config:")
ui.config.right:setText("-")
ui.danger.left:setText("Danger:")
ui.danger.right:setText("0")

ui.editor.debug.onClick = function()
  local on = ui.editor.debug:isOn()
  ui.editor.debug:setOn(not on)
  if on then
    for _, spec in ipairs(getSpectators()) do
      spec:clearText()
    end
  end
end

local oldTibia = g_game.getClientVersion() < 960

-- PERF: nao redesenhar labels quando o texto permanece igual.
local lastTargetUi = {}
local function updateTargetLabel(widget, key, value)
  local text = tostring(value)
  if lastTargetUi[key] ~= text then
    lastTargetUi[key] = text
    widget:setText(text)
  end
end

-- Ignore list: one monster name per line; persisted across restarts.
storage.shazamTargetIgnore = storage.shazamTargetIgnore or ""
local ignoreNames = {}
local function rebuildIgnoreNames()
  ignoreNames = {}
  for name in tostring(storage.shazamTargetIgnore):gmatch("[^\r\n,;]+") do
    name = name:match("^%s*(.-)%s*$"):lower()
    if name ~= "" then ignoreNames[name] = true end
  end
end
rebuildIgnoreNames()

-- Botao Ignore no mesmo local do Infinity: abaixo da lista de monstros.
-- Evita interromper o carregamento de todo o TargetBot caso o OTUI antigo
-- ainda esteja em cache ou o widget Ignore nao esteja disponivel.
local ignoreButton = ui.ignoreButton or ui:recursiveGetChildById("ignoreButton")
if ignoreButton then
ignoreButton.onClick = function()
  UI.MultilineEditorWindow(
    storage.shazamTargetIgnore or "",
    {
      title = "Ignore creatures",
      description = "Digite um nome de criatura por linha para ignorar no TargetBot."
    },
    function(newText)
      if newText == nil then return end
      storage.shazamTargetIgnore = newText
      rebuildIgnoreNames()
      lockedTargetId = nil
      if type(saveConfig) == "function" then pcall(saveConfig) end
    end
  )
end
end

-- main loop, controlled by config
targetbotMacro = macro(100, function()
  local pos = player:getPosition()
  local specs = g_map.getSpectatorsInRange(pos, false, 6, 6) -- 12x12 area
  local creatures = 0
  for _, spec in ipairs(specs) do
    if spec:isMonster() then
      creatures = creatures + 1
      if creatures > 10 then break end
    end
  end
  if creatures > 10 then -- if there are too many monsters around, limit area
    creatures = g_map.getSpectatorsInRange(pos, false, 3, 3) -- 6x6 area
  else
    creatures = specs
  end
  local debugEnabled = ui.editor.debug:isOn()
  local highestPriority = 0
  local currentParams = nil
  local lowestHp = 101
  local currentHp = 101
  local dangerLevel = 0
  local targets = 0
  local highestPriorityParams = nil
  for i, creature in ipairs(creatures) do
    local hppc = creature:getHealthPercent()
    -- PERF: nao calcular caminho para players, NPCs ou criaturas mortas.
    if hppc and hppc > 0 and creature:isMonster() and not ignoreNames[creature:getName():lower():match("^%s*(.-)%s*$")] and (oldTibia or creature:getType() < 3) then
      local path = findPath(pos, creature:getPosition(), 7, {ignoreLastCreature=true, ignoreNonPathable=true, ignoreCost=true, ignoreCreatures=true})
      if path then
        local params = TargetBot.Creature.calculateParams(creature, path) -- return {craeture, config, danger, priority}
        dangerLevel = dangerLevel + params.danger
        if params.priority > 0 then
          targets = targets + 1
          -- Prioridade por HP; distancia so determina se e alcancavel.
          -- A prioridade da configuracao continua validando os monstros.
          if params.creature:getId() == lockedTargetId then
            currentParams = params
            currentHp = hppc
          end
          if hppc < lowestHp then
            lowestHp = hppc
            highestPriorityParams = params
          end
          if debugEnabled then
            creature:setText(params.config.name .. "\n" .. params.priority)
          end
        end
      end
    end
  end

  -- Sempre prioriza o menor HP; em empate, mantem o alvo atual.
  if currentParams and (not highestPriorityParams or
      currentHp <= lowestHp) then
    highestPriorityParams = currentParams
  end
  lockedTargetId = highestPriorityParams and highestPriorityParams.creature:getId() or nil

  -- reset walking
  TargetBot.walkTo(nil)

  -- looting
  local looting = TargetBot.Looting.process(targets, dangerLevel)
  local lootingStatus = TargetBot.Looting.getStatus()
  looterStatus = lootingStatus
  dangerValue = dangerLevel

  updateTargetLabel(ui.danger.right, "danger", dangerLevel)
  if highestPriorityParams and not isInPz() then
    updateTargetLabel(ui.target.right, "target", highestPriorityParams.creature:getName())
    updateTargetLabel(ui.config.right, "config", highestPriorityParams.config.name)
    TargetBot.Creature.attack(highestPriorityParams, targets, looting)    
    if lootingStatus:len() > 0 then
      TargetBot.setStatus("Attack & " .. lootingStatus)
    elseif cavebotAllowance > now then
      TargetBot.setStatus("Luring using CaveBot")
    else
      TargetBot.setStatus("Attacking")
      if not lureEnabled then
        TargetBot.setStatus("Attacking (luring off)")      
      end
    end
    TargetBot.walk()
    lastAction = now
    return
  end

  updateTargetLabel(ui.target.right, "target", "-")
  updateTargetLabel(ui.config.right, "config", "-")
  if looting then
    TargetBot.walk()
    lastAction = now
  end
  if lootingStatus:len() > 0 then
    TargetBot.setStatus(lootingStatus)
  else
    TargetBot.setStatus("Waiting")
  end
end)

-- config, its callback is called immediately, data can be nil
config = Config.setup("Target Configs", configWidget, "json", function(name, enabled, data)
  if not data then
    ui.status.right:setText("Off")
    return targetbotMacro.setOff() 
  end
  lockedTargetId = nil
  TargetBot.Creature.resetConfigs()
  for _, value in ipairs(data["targeting"] or {}) do
    TargetBot.Creature.addConfig(value)
  end
  TargetBot.Looting.update(data["looting"] or {})

  -- add configs
  if enabled then
    ui.status.right:setText("On")
  else
    ui.status.right:setText("Off")
  end

  targetbotMacro.setOn(enabled)
  targetbotMacro.delay = nil
  lureEnabled = true
end)

-- setup ui
ui.editor.buttons.add.onClick = function()
  TargetBot.Creature.edit(nil, function(newConfig)
    TargetBot.Creature.addConfig(newConfig, true)
    TargetBot.save()
  end)
end

ui.editor.buttons.edit.onClick = function()
  local entry = ui.list:getFocusedChild()
  if not entry then return end
  TargetBot.Creature.edit(entry.value, function(newConfig)
    entry:setText(newConfig.name)
    entry.value = newConfig
    TargetBot.Creature.resetConfigsCache()
    TargetBot.save()
  end)
end

ui.editor.buttons.remove.onClick = function()
  local entry = ui.list:getFocusedChild()
  if not entry then return end
  entry:destroy()
  TargetBot.Creature.resetConfigsCache()
  TargetBot.save()
end

-- public function, you can use them in your scripts
TargetBot.isActive = function() -- return true if attacking or looting takes place
  return lastAction + 300 > now
end

TargetBot.isCaveBotActionAllowed = function()
  return cavebotAllowance > now
end

TargetBot.setStatus = function(text)
  return ui.status.right:setText(text)
end

TargetBot.getStatus = function()
  return ui.status.right:getText()
end

TargetBot.isOn = function()
  return config ~= nil and type(config.isOn) == "function" and config.isOn() or false
end

TargetBot.isOff = function()
  return config == nil or type(config.isOff) ~= "function" or config.isOff()
end

TargetBot.setOn = function(val)
  if val == false then  
    return TargetBot.setOff(true)
  end
  if config and type(config.setOn) == "function" then config.setOn() end
end

TargetBot.setOff = function(val)
  if val == false then  
    return TargetBot.setOn(true)
  end
  if config and type(config.setOff) == "function" then config.setOff() end
end

TargetBot.getCurrentProfile = function()
  return storage._configs["Target Configs"].selected
end

local botConfigName = modules.game_bot.contentsPanel.config:getCurrentOption().text
TargetBot.setCurrentProfile = function(name)
  if not g_resources.fileExists("/bot/"..botConfigName.."/Target Configs/"..name..".json") then
    return warn("there is no targetbot profile with that name!")
  end
  TargetBot.setOff()
  storage._configs["Target Configs"].selected = name
  TargetBot.setOn()
end

TargetBot.delay = function(value)
  targetbotMacro.delay = now + value
end

TargetBot.save = function()
  local data = {targeting={}, looting={}}
  for _, entry in ipairs(ui.list:getChildren()) do
    table.insert(data.targeting, entry.value)
  end
  TargetBot.Looting.save(data.looting)
  config.save(data)
end

TargetBot.allowCaveBot = function(time)
  cavebotAllowance = now + time
end

TargetBot.disableLuring = function()
  lureEnabled = false
end

TargetBot.enableLuring = function()
  lureEnabled = true
end

TargetBot.Danger = function()
  return dangerValue
end

TargetBot.lootStatus = function()
  return looterStatus
end


-- attacks
local lastSpell = 0
local lastAttackSpell = 0

TargetBot.saySpell = function(text, delay)
  if type(text) ~= 'string' or text:len() < 1 then return end
  if not delay then delay = 500 end
  if g_game.getProtocolVersion() < 1090 then
    lastAttackSpell = now -- pause attack spells, healing spells are more important
  end
  if lastSpell + delay < now then
    say(text)
    lastSpell = now
    return true
  end
  return false
end

TargetBot.sayAttackSpell = function(text, delay)
  if type(text) ~= 'string' or text:len() < 1 then return end
  if not delay then delay = 2000 end
  if lastAttackSpell + delay < now then
    say(text)
    lastAttackSpell = now
    return true
  end
  return false
end

local lastItemUse = 0
local lastRuneAttack = 0

TargetBot.useItem = function(item, subType, target, delay)
  if not delay then delay = 200 end
  if lastItemUse + delay < now then
    local thing = g_things.getThingType(item)
    if not thing or not thing:isFluidContainer() then
      subType = g_game.getClientVersion() >= 860 and 0 or 1
    end
    if g_game.getClientVersion() < 780 then
      local tmpItem = g_game.findPlayerItem(item, subType)
      if not tmpItem then return end
      g_game.useWith(tmpItem, target, subType) -- using item from bp
    else
      g_game.useInventoryItemWith(item, target, subType) -- hotkey
    end
    lastItemUse = now
  end
end

TargetBot.useAttackItem = function(item, subType, target, delay)
  if not delay then delay = 2000 end
  if lastRuneAttack + delay < now then
    local thing = g_things.getThingType(item)
    if not thing or not thing:isFluidContainer() then
      subType = g_game.getClientVersion() >= 860 and 0 or 1
    end
    if g_game.getClientVersion() < 780 then
      local tmpItem = g_game.findPlayerItem(item, subType)
      if not tmpItem then return end
      g_game.useWith(tmpItem, target, subType) -- using item from bp  
    else
      g_game.useInventoryItemWith(item, target, subType) -- hotkey
    end
    lastRuneAttack = now
  end
end

TargetBot.canLure = function()
  return lureEnabled
end