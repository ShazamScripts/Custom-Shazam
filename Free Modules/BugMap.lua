-- ============================================================================
-- BUG MAP COMPLETO (portado do sistema anterior, sem sistema anterior)
-- Teclas padrao: W, A, S, D (segure para andar em "dash" pelo mapa)
--
-- Recursos (iguais ao sistema anterior):
--  * verifyTiles: se tem parede/obstaculo antes da escada, nao tenta passar;
--  * diagonais (duas teclas ao mesmo tempo);
--  * Kunai: antes de andar, joga a Kunai ate N tiles a frente (so se o
--    checkbox "Kunai Dash & Jump" da aba User estiver marcado e o icone
--    "Dash Sunshin" estiver ligado);
--  * mobile (keypad virtual).
-- ============================================================================
setDefaultTab("Main")

_G.configData = _G.configData or {}
local configData = _G.configData
configData["bugMap"] = {}

local g_keyboard = modules["corelib"]["g_keyboard"]

storage["scrollBars"] = storage["scrollBars"] or {}
storage["checkBoxs"] = storage["checkBoxs"] or {}

local holding_keys = {}
local pressed_data = {}

local isKeyHold = function(key)
  if (g_keyboard["isKeyPressed"](key) and table["size"](holding_keys) > 0) then
    return true
  end
  return false
end

local isMobile = modules["_G"]["g_app"]["isMobile"]()

local bugMap = {}

-- Estado do Kunai: segue o icone "Dash Sunshin" (e lembra o estado salvo).
bugMap["status"] = (storage["_icons"] and storage["_icons"]["bugMapKunai"]
  and storage["_icons"]["bugMapKunai"]["enabled"] == true) or false

if (not g_game["getWorldName"]():lower():find("db")) then
  bugMap["icon"] = addIcon("bugMapKunai", {text = "Dash Sunshin", item = {id = tonumber(storage["kunaiId"]) or 7382}}, function(icon, isOn)
    bugMap["status"] = isOn
  end)
end

-- ---------------------------------------------------------------------------
-- IDs de escadas / portas / buracos: vem do Escadas.lua (mesma lista que voce
-- edita no Config do Auto-Escadas). Se mudar la, muda aqui sozinho.
-- ---------------------------------------------------------------------------
local stairIdLookup, excludeIdLookup = {}, {}
local nextIdRefresh = 0

local function refreshStairIds()
  if (now < nextIdRefresh) then return end
  nextIdRefresh = now + 1000
  stairIdLookup, excludeIdLookup = {}, {}
  for _, value in ipairs(storage["stairsIds"] or {}) do
    if (type(value) == "table" and value["id"]) then stairIdLookup[value["id"]] = true end
  end
  for _, value in ipairs(storage["excludeIds"] or {}) do
    if (type(value) == "table" and value["id"]) then excludeIdLookup[value["id"]] = true end
  end
end

local isStair = function(self, ignoreCreatures)
  if (not self) then return end
  local tilePos = self:getPosition()
  if (not tilePos) then return end

  refreshStairIds()

  -- 1) pelo ID (lista do Escadas). ID excluido vence sempre.
  local foundById = false
  for _, item in ipairs(self:getItems()) do
    local itemId = item:getId()
    if (excludeIdLookup[itemId]) then return false end
    if (stairIdLookup[itemId]) then foundById = true end
  end
  if (foundById) then return true end

  -- 2) fallback antigo: cor do minimapa de escada
  local color = g_map["getMinimapColor"](tilePos)
  return color >= 210 and color <= 213 and not self:isPathable() and self:isWalkable(ignoreCreatures)
end

bugMap["correctDirection"] = function()
  local dir = player:getDirection()
  return dir <= 3 and dir or dir < 6 and 1 or 3
end

bugMap["nextPosition"] = {
  {x = 0, y = -1},
  {x = 1, y = 0},
  {x = 0, y = 1},
  {x = -1, y = 0},
  {x = 1, y = -1},
  {x = 1, y = 1},
  {x = -1, y = 1},
  {x = -1, y = -1}
}

bugMap["getNextDirection"] = function(pos, dir)
  local offSet = bugMap["nextPosition"][dir + 1]
  pos["x"] = pos["x"] + offSet["x"]
  pos["y"] = pos["y"] + offSet["y"]
  return pos
end

bugMap["positions"] = {
  [0] = {x = 0, y = -5},
  [1] = {x = 5, y = 0},
  [2] = {x = 0, y = 5},
  [3] = {x = -5, y = 0}
}

bugMap["getIteration"] = function(dir)
  local base = bugMap["positions"][dir]
  local x, y = base["x"], base["y"]
  return {startIter = x < 0 and x or 0, endIter = x > 0 and x or 0},
         {startIter = y < 0 and y or 0, endIter = y > 0 and y or 0}
end

bugMap["getDistance"] = function(p1, p2)
  local distx = math["abs"](p1["x"] - p2["x"])
  local disty = math["abs"](p1["y"] - p2["y"])
  return math["sqrt"](distx * distx + disty * disty)
end

-- Retorna true se o primeiro "evento" a frente (ate 5 tiles) e uma ESCADA/PORTA
-- que esta BLOQUEANDO o caminho (pode usar) e false se for um OBSTACULO comum
-- (nao anda). Tambem devolve a posicao e a distancia da escada.
bugMap["verifyTiles"] = function(dir)
  local xr, yr = bugMap["getIteration"](dir)

  local nearest = {}
  local playerPos = player:getPosition()
  local playerTile = player:getTile()
  for dx = xr["startIter"], xr["endIter"] do
    for dy = yr["startIter"], yr["endIter"] do
      local newPos = {x = playerPos["x"] + dx, y = playerPos["y"] + dy, z = playerPos["z"]}
      local tile = g_map["getTile"](newPos)
      if (tile and tile ~= playerTile) then
        local distance = bugMap["getDistance"](newPos, playerPos)
        if (not nearest["distance"] or distance < nearest["distance"]) then
          if (isStair(tile) and (not tile:isPathable() or not tile:isWalkable())) then
            nearest["pos"] = newPos
            nearest["isWalkable"] = true
            nearest["distance"] = distance
          elseif (not tile:isWalkable()) then
            nearest["pos"] = nil
            nearest["isWalkable"] = false
            nearest["distance"] = distance
          end
        end
      end
    end
  end

  return nearest["isWalkable"], nearest["pos"], nearest["distance"]
end

bugMap["stairCooldown"] = 0

bugMap["handleUse"] = function(x, y, dir)
  if (bugMap["correctDirection"]() ~= dir) then
    g_game["turn"](dir)
  end

  if (x == 0 or y == 0) then
    local isStairAhead, stairPos = bugMap["verifyTiles"](dir)
    if (isStairAhead) then
      -- Escada/porta bloqueando o dash: em vez de desviar, usa ela direto
      -- (sem andar ate la). Espera um pouco entre usos para nao subir e
      -- descer em loop quando a saida cai perto de outra escada.
      if (now < bugMap["stairCooldown"]) then return end
      local stairTile = g_map["getTile"](stairPos)
      if (not stairTile) then return end
      local useThing = stairTile:getTopUseThing() or stairTile:getTopThing()
      if (not useThing) then return end
      bugMap["stairCooldown"] = now + 400
      return g_game["use"](useThing)
    end
  elseif (x ~= 0 and y ~= 0) then
    x = x > 0 and 4 or -4
    y = y > 0 and 4 or -4
  end

  local playerPos = player:getPosition()

  -- Kunai (sunshin): joga a kunai alguns tiles a frente antes de andar.
  local kunaiId = tonumber(storage["kunaiId"])
  -- So joga kunai com a caixinha "Kunai Dash & Jump" (aba USER) marcada.
  if (storage["checkBoxs"]["useKunai"] == true and kunaiId and not isInPz() and bugMap["status"]) then
    local newX = x
    local newY = y
    local newDistance = storage["scrollBars"]["distanceKunai"] or 6
    if (x == 0 and y ~= 0) then
      newY = newDistance * (y < 0 and -1 or 1)
    elseif (y == 0 and x ~= 0) then
      newX = newDistance * (x < 0 and -1 or 1)
    end
    local kunaiPos = {x = playerPos["x"] + newX, y = playerPos["y"] + newY, z = playerPos["z"]}
    local kunaiTile = g_map["getTile"](kunaiPos)
    if (kunaiTile) then
      local topThing = kunaiTile:getTopUseThing()
      if (topThing and kunaiTile:isWalkable(true) and kunaiTile:isPathable() and kunaiTile:canShoot(newDistance)) then
        g_game["stop"]()
        useWith(kunaiId, topThing)
      end
    end
  end

  playerPos = player:getPosition()

  local walkPos = {x = playerPos["x"] + x, y = playerPos["y"] + y, z = playerPos["z"]}

  -- "Anda no papel" ate 7 passos em direcao ao destino e usa o ultimo tile.
  local stopAt = 7
  local path = findPath(playerPos, walkPos, 15, {precision = 3})
  if (path ~= nil) then
    for index, value in ipairs(path) do
      if (index > stopAt) then break end
      if (value > 3) then  -- 3 = West (diagonais gastam mais passos)
        stopAt = stopAt - 2
      end
      playerPos = bugMap["getNextDirection"](playerPos, value)
    end
  end

  if (path == nil) then
    playerPos = walkPos
  end

  local tile = g_map["getTile"](playerPos)
  if (tile == nil) then return end

  local topThing = (tile:getTopUseThing() or tile:getTopThing())
  if (topThing == nil) then return end
  if (topThing:isMultiUse()) then
    return g_game["useWith"](topThing, player)
  end
  g_game["use"](topThing)
end

onPlayerPositionChange(function(newPos, oldPos)
  if (newPos and oldPos and newPos["z"] ~= oldPos["z"]) then
    bugMap["stairCooldown"] = now + 600
  end
end)

bugMap["basis"] = {
  Up = {dir = 0, sum = {x = 0, y = -6}},
  Left = {dir = 3, sum = {x = -6, y = 0}},
  Down = {dir = 2, sum = {x = 0, y = 6}},
  Right = {dir = 1, sum = {x = 6, y = 0}},
}

configData["bugMap"]["extra"] = {
  Up = "W",
  Down = "S",
  Right = "D",
  Left = "A",
}

local getWalkKeys = function()
  local ret = {}
  for key, value in pairs(configData["bugMap"]["extra"]) do
    local base = bugMap["basis"][key]
    table["insert"](ret, {dir = base["dir"], sum = base["sum"], key = value})
  end
  return ret
end

-- Keypad do mobile
local DIRS = {}
if (isMobile) then
  bugMap["pointer"] = g_ui["getRootWidget"]():recursiveGetChildById("keypad")

  local North = {highest = {x = -16, y = 29}, lowest = {x = -75, y = -30}, info = {dir = 0, sum = {x = 0, y = -5}}}
  local East = {highest = {x = 29, y = 75}, lowest = {x = -30, y = 15}, info = {dir = 1, sum = {x = 5, y = 0}}}
  local South = {highest = {x = 75, y = 29}, lowest = {x = 16, y = -30}, info = {dir = 2, sum = {x = 0, y = 5}}}
  local West_ = {highest = {x = 29, y = -15}, lowest = {x = -30, y = -75}, info = {dir = 3, sum = {x = -5, y = 0}}}
  local SouthWest = {highest = {x = 69, y = -28}, lowest = {x = 28, y = -69}, info = {sum = {x = -3, y = 3}}}
  local NorthWest = {highest = {x = -28, y = -29}, lowest = {x = -69, y = -69}, info = {sum = {x = -3, y = -3}}}
  local SouthEast = {highest = {x = 70, y = 70}, lowest = {x = 30, y = 30}, info = {sum = {x = 3, y = 3}}}
  local NorthEast = {highest = {x = -29, y = 68}, lowest = {x = -69, y = 29}, info = {sum = {x = 3, y = -3}}}
  DIRS = {North, East, South, West_, NorthEast, SouthEast, SouthWest, NorthWest}
end

bugMap["getPressedKeys"] = function()
  local pressedKeys = {}

  if (isMobile) then
    local marginTop, marginLeft = bugMap["pointer"]:getMarginTop(), bugMap["pointer"]:getMarginLeft()
    for _, value in ipairs(DIRS) do
      if ((marginTop >= value["lowest"]["x"] and marginTop <= value["highest"]["x"]) and
          (marginLeft >= value["lowest"]["y"] and marginLeft <= value["highest"]["y"])) then
        table["insert"](pressedKeys, value["info"])
      end
    end
  else
    for _, value in ipairs(getWalkKeys()) do
      if (isKeyHold(value["key"])) then
        table["insert"](pressedKeys, value)
      end
    end
  end

  return pressedKeys
end

bugMap["macro"] = macro(50, "Bug Map", function(self)
  if (g_keyboard["isCtrlPressed"]()) then return end

  local pressedKeys = bugMap["getPressedKeys"]()
  if (#pressedKeys == 0) then return end

  local sumPos = {x = 0, y = 0}

  for _, value in ipairs(pressedKeys) do
    local val = value["sum"]
    -- Ignora uma segunda tecla no mesmo eixo (ex.: W + S ao mesmo tempo).
    if (not ((sumPos["x"] ~= 0 and val["x"] ~= 0) or (sumPos["y"] ~= 0 and val["y"] ~= 0))) then
      sumPos["x"] = sumPos["x"] + val["x"]
      sumPos["y"] = sumPos["y"] + val["y"]
    end
  end

  local firstDir = pressedKeys[1]["dir"] or bugMap["correctDirection"]()
  bugMap["handleUse"](sumPos["x"], sumPos["y"], firstDir)
end)

-- ---------------------------------------------------------------------------
-- Rastreio das teclas seguradas (leve: nao faz nada se nenhuma tecla ativa)
-- ---------------------------------------------------------------------------
local function isTableEmpty(t)
  for _ in pairs(t) do return false end
  return true
end

local function isWalkKey(key)
  return table["find"](configData["bugMap"]["extra"], key) ~= nil
end

macro(50, function()
  if (isTableEmpty(pressed_data)) then
    if (not isTableEmpty(holding_keys)) then holding_keys = {} end
    return
  end

  -- Uma unica passagem em vez de duas coletas com alocacao de tabelas.
  local holding = {}
  for key, time in pairs(pressed_data) do
    if not g_keyboard["isKeyPressed"](key) or not isWalkKey(key) then
      pressed_data[key] = nil
    elseif now - time >= 100 then
      holding[key] = time
    end
  end
  holding_keys = holding
end)

local function normalizeKey(key)
  if (type(key) == "string" and key:sub(1, 5) == "Shift") then
    key = key:split("+")[2] or key
  end
  return key
end

onKeyDown(function(key)
  if not bugMap["macro"] or bugMap["macro"]:isOff() then return end
  key = normalizeKey(key)
  pressed_data[key] = now
end)

onKeyUp(function(key)
  if not bugMap["macro"] or bugMap["macro"]:isOff() then return end
  key = normalizeKey(key)
  pressed_data[key] = nil
end)

configData["bugMap"]["macro"] = bugMap["macro"]
