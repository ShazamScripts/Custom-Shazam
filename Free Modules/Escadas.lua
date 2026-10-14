-- ============================================================================
-- AUTO-ESCADAS / PORTAS
-- Script independente, sem nenhuma dependência de sistema anterior, chronic ou qualquer
-- outro loader externo. Usa apenas as funções nativas do client/bot (setupUI,
-- storage, g_map, player, macro, findPath, autoWalk, etc).
-- O botão "Config", ao lado do switch do macro, segue o mesmo padrão usado
-- na macro de Buffs (Panel com BotSwitch + Button lado a lado).
-- ============================================================================

lblInfo= UI.Label("---- MOBILITY ----")
lblInfo:setColor("yellow")

-- ---------------------------------------------------------------------------
-- Atalhos de módulos nativos
-- ---------------------------------------------------------------------------
local addEvent           = modules["_G"]["addEvent"];
local scheduleEvent      = modules["_G"]["scheduleEvent"];
local isMobile           = modules["_G"]["g_app"]["isMobile"]();
local isKeyPressed       = modules["corelib"]["g_keyboard"]["isKeyPressed"];
local displayGameMessage = modules["game_textmessage"]["displayGameMessage"];

-- ---------------------------------------------------------------------------
-- Storage / configuração persistente (substitui o antigo sistema anterior.configData)
-- ---------------------------------------------------------------------------
storage["checkBoxs"]    = storage["checkBoxs"]    or {};
storage["scrollBars"]   = storage["scrollBars"]   or {};
storage["stairsConfig"] = storage["stairsConfig"] or {};
storage["stairsConfig"]["actionKey"] = storage["stairsConfig"]["actionKey"] or (isMobile and "F1" or "Space");
if (storage["stairsConfig"]["enabled"] == nil) then
    storage["stairsConfig"]["enabled"] = true;
end

-- IDs padrão (usados apenas na primeira execução, depois o usuário edita
-- pela interface de Config e o valor escolhido fica salvo no storage)
local defaultStairsIds = {
    1666, 6207, 1948, 435, 7771, 5542, 8657, 6264, 1646, 1648,
    1678, 5291, 1680, 6905, 6262, 1664, 13296, 1067, 13861, 11931,
    1949, 6896, 6205, 13926, 1947, 12097, 615, 1678, 8367,
};

local defaultExcludeIds = {
    12099, 17393,
};

local function toItemList(ids)
    local list = {};
    for _, id in ipairs(ids) do
        table["insert"](list, { id = id });
    end
    return list;
end

storage["stairsIds"]  = storage["stairsIds"]  or toItemList(defaultStairsIds);
storage["excludeIds"] = storage["excludeIds"] or toItemList(defaultExcludeIds);
-- IDs de buracos/SQMs onde, segurando SPACE em cima deles, deve spammar "skip".
storage["skipHoleIds"] = storage["skipHoleIds"] or {};

-- Tabelas de lookup rápido (id -> true), reconstruídas sempre que a lista muda
local stairsIds  = {};
local excludeIds = {};
local skipHoleIds = {};

local function updateIds()
    stairsIds  = {};
    excludeIds = {};
    skipHoleIds = {};

    for _, value in ipairs(storage["stairsIds"]) do
        stairsIds[value["id"]] = true;
    end

    for _, value in ipairs(storage["excludeIds"]) do
        excludeIds[value["id"]] = true;
    end

    for _, value in ipairs(storage["skipHoleIds"]) do
        skipHoleIds[value["id"]] = true;
    end
end

-- ---------------------------------------------------------------------------
-- Estado interno do scanner
-- ---------------------------------------------------------------------------
local range = {};
for x = -15, 15 do
    for y = -15, 15 do
        table["insert"](range, { x = x, y = y });
    end
end

local delayTime;
local actualPos;
local actualTile;
local displayTime;
local scanIndex = 1;
local ignoreCreatures = false;
local everyPath;
local lastWalkPosition = nil;

local flags = {
    ignoreNonWalkable = false,
    ignoreNonPathable = true,
    ignoreStairs = true,
};

-- ---------------------------------------------------------------------------
-- Funções auxiliares
-- ---------------------------------------------------------------------------
local function isStair(tile)
    if (tile == nil) then
        return;
    end

    local tilePos = tile:getPosition();
    if (tilePos == nil) then
        return false;
    end

    local foundStair;
    local foundAnyItem;
    local items = tile:getItems();
    for _, item in ipairs(items) do
        local itemId = item:getId();
        if (excludeIds[itemId]) then
            return false;
        end

        if (stairsIds[itemId]) then
            foundStair = true;
        end
        foundAnyItem = true;
    end

    if (foundStair) then
        return true;
    end

    if (not foundAnyItem) then
        return false;
    end

    local minimap_color = g_map["getMinimapColor"](tilePos);
    if (minimap_color >= 210 and minimap_color <= 213) then
        if (tile:isWalkable(true)) then
            local isPathable = tile:isPathable();
            if (not isPathable) then
                return true;
            end

            for x = -1, 1 do
                for y = -1, 1 do
                    if (x ~= 0 or y ~= 0) then
                        local currentPos = { x = tilePos["x"] + x, y = tilePos["y"] + y, z = tilePos["z"] };
                        local currentColor = g_map["getMinimapColor"](currentPos);
                        if (currentColor >= 210 and currentColor <= 213) then
                            return false;
                        end
                    end
                end
            end
            return true;
        end
    end

    return false;
end

local function newFindPath(startPos, destPos, maxDist, params)
    if (not destPos or startPos["z"] ~= destPos["z"]) then return; end
    if (type(maxDist) ~= "number") then
        maxDist = 100;
    end
    if (type(params) ~= "table") then
        params = {};
    end

    local destPosStr = destPos["x"] .. "," .. destPos["y"] .. "," .. destPos["z"];
    if (everyPath == nil) then
        everyPath = findAllPaths(startPos, maxDist, params);
    end
    local paths = everyPath;
    if (paths[destPosStr] == nil) then
        local bestCandidate = nil;
        for x = -1, 1 do
            for y = -1, 1 do
                local dest = (destPos["x"] + x) .. "," .. (destPos["y"] + y) .. "," .. destPos["z"];
                local node = paths[dest];
                if (node and (not bestCandidate or bestCandidate[2] > node[2])) then
                    bestCandidate = node;
                end
            end
        end
        if (bestCandidate) then
            return bestCandidate[2] + 1;
        end
        return nil;
    end

    local candidate = paths[destPosStr];
    return candidate[2];
end

local function getDistance(p1, p2)
    local distx = math["abs"](p1["x"] - p2["x"]);
    local disty = math["abs"](p1["y"] - p2["y"]);
    return math["sqrt"](distx * distx + disty * disty);
end

local function getDistanceFromPlayer(playerPos, position)
    local tileDistance = newFindPath(playerPos, position, 20, flags);
    return tileDistance or -1;
end

local function doHighlightTile(tile, color)
    if (tile == nil) then
        return;
    end

    local item;
    local items = tile:getItems();
    for _, _item in ipairs(items) do
        item = _item;
    end

    if (item ~= nil and item["setMarked"]) then
        item:setMarked(color);
        return;
    end

    local text = "AQUI";
    if (color == nil) then
        text = "";
    end
    tile:setText(text, color);
end

table["sort"](range, function(a, b)
    local origin = { x = 0, y = 0 };
    local axisA = getDistance(origin, a);
    local axisB = getDistance(origin, b);
    return axisA < axisB;
end);

local function verifyTiles()
    local ret = {};
    local checkedTiles = 0;
    if (range[scanIndex] == nil) then
        scanIndex = 1;
        everyPath = nil;

        if (actualTile == nil or ignoreCreatures) then
            ignoreCreatures = not ignoreCreatures;
        end
    end

    flags["ignoreCreatures"] = ignoreCreatures;

    local playerPos = player:getPosition();

    if (actualTile ~= nil and isStair(actualTile)) then
        local tilePos = actualTile:getPosition();
        local currentDistance = getDistanceFromPlayer(playerPos, tilePos);
        if (currentDistance ~= -1 or not flags["ignoreCreatures"]) then
            ret["tile"] = actualTile;
            ret["tilePos"] = tilePos;
            ret["distance"] = currentDistance;
        end
    end

    while (range[scanIndex] ~= nil and checkedTiles < 30) do
        local offs = range[scanIndex];
        local tilePos = { x = playerPos["x"] + offs["x"], y = playerPos["y"] + offs["y"], z = playerPos["z"] };
        local distance = getDistanceFromPlayer(playerPos, tilePos);

        scanIndex = scanIndex + 1;
        checkedTiles = checkedTiles + 1;

        if (distance ~= -1) then
            if (ret["distance"] == nil or ret["distance"] == -1 or distance < ret["distance"]) then
                local tile = g_map["getTile"](tilePos);
                if (tile ~= nil and isStair(tile)) then
                    ret["tile"] = tile;
                    ret["tilePos"] = tilePos;
                    ret["distance"] = distance;
                end
            end
        end
    end

    if (actualTile ~= ret["tile"]) then
        doHighlightTile(actualTile);
    end

    if (ret["tile"] == nil) then
        actualPos = nil;
        actualTile = nil;
    end

    if (ret["tile"] ~= nil) then
        actualTile = ret["tile"];
        actualPos = ret["tilePos"];
    end
end

local function getNearestTile(pos)
    local nearestTile = nil;
    local nearestDist = math["huge"];
    local playerPos = player:getPosition();

    for x = -1, 1 do
        for y = -1, 1 do
            local tmpPos = { x = pos["x"] + x, y = pos["y"] + y, z = pos["z"] };
            local tile = g_map["getTile"](tmpPos);
            if (tile and tile:isWalkable(true) and tile:isPathable()) then
                local d = getDistance(tmpPos, playerPos);
                if (d < nearestDist) then
                    nearestDist = d;
                    nearestTile = tile;
                end
            end
        end
    end

    return nearestTile;
end

local function samePos(a, b)
    return a and b and a["x"] == b["x"] and a["y"] == b["y"] and a["z"] == b["z"];
end

local useWalkCache = { key = nil, path = nil, expires = 0 }
local function doUseWalk(tilePos)
    local currentPos = player:getPosition();
    local key = tilePos.x .. ":" .. tilePos.y .. ":" .. tilePos.z .. ">" .. currentPos.x .. ":" .. currentPos.y .. ":" .. currentPos.z
    local path
    if useWalkCache.key == key and useWalkCache.expires > now then
        path = useWalkCache.path
    else
        path = findPath(tilePos, currentPos, 20);
        useWalkCache.key, useWalkCache.path, useWalkCache.expires = key, path, now + 150
    end
    if (not path) then return; end

    local size = table["size"](path);
    local stopIndex = math["max"](1, size - 5);

    for index = size, stopIndex, -1 do
        local direction = path[index];
        if (direction == 0) then
            currentPos["y"] = currentPos["y"] + 1;
        elseif (direction == 1) then
            currentPos["x"] = currentPos["x"] - 1;
        elseif (direction == 2) then
            currentPos["y"] = currentPos["y"] - 1;
        elseif (direction == 3) then
            currentPos["x"] = currentPos["x"] + 1;
        elseif (direction == 4) then
            currentPos["x"] = currentPos["x"] - 1;
            currentPos["y"] = currentPos["y"] + 1;
        elseif (direction == 5) then
            currentPos["x"] = currentPos["x"] - 1;
            currentPos["y"] = currentPos["y"] - 1;
        elseif (direction == 6) then
            currentPos["x"] = currentPos["x"] + 1;
            currentPos["y"] = currentPos["y"] - 1;
        elseif (direction == 7) then
            currentPos["x"] = currentPos["x"] + 1;
            currentPos["y"] = currentPos["y"] - 1;
        end
    end

    local tile = g_map["getTile"](currentPos);
    local topThing = tile and tile:getTopUseThing();
    if (topThing) then
        if (topThing:isMultiUse()) then
            useWith(topThing, player);
        else
            use(topThing);
        end
        return true;
    end
end

onPlayerPositionChange(function(newPos, oldPos)
    if (actualTile ~= nil and delayTime ~= nil) then
        delayTime = nil;
    end

    scanIndex = 1;
    everyPath = nil;
    ignoreCreatures = nil;
end)

-- ---------------------------------------------------------------------------
-- Interface: linha principal (BotSwitch + Button "Config"), no mesmo padrão
-- usado na macro de Buffs.
-- ---------------------------------------------------------------------------
local botWidget = setupUI("Panel\n  height: 17\n\n  BotSwitch\n    id: switch\n    anchors.top: parent.top\n    anchors.left: parent.left\n    text-align: center\n    width: 130\n    !text: tr(\"Auto-Escadas\")\n\n  Button\n    id: config\n    anchors.top: prev.top\n    anchors.bottom: prev.bottom\n    anchors.left: prev.right\n    anchors.right: parent.right\n    text: Config\n")

-- ---------------------------------------------------------------------------
-- Interface: painel de Config (oculto por padrão) com os IDs de
-- escadas/portas e os IDs excluídos (deletados).
-- ---------------------------------------------------------------------------
local configOpen = false;
local configWidgets = {};

local function trackConfigWidget(widget)
    table["insert"](configWidgets, widget);
    widget:setVisible(false);
    return widget;
end

local function setConfigVisible(visible)
    configOpen = visible;
    for _, widget in ipairs(configWidgets) do
        widget:setVisible(visible);
    end
end

trackConfigWidget(UI["Separator"]());
trackConfigWidget(UI["Label"]("IDs das Escadas/Portas"));

local stairsIdContainer = trackConfigWidget(UI["Container"](function(widget, items)
    storage["stairsIds"] = items;
    updateIds();
end, true));
stairsIdContainer:setItems(storage["stairsIds"]);
stairsIdContainer:setHeight(35);

trackConfigWidget(UI["Separator"]());
trackConfigWidget(UI["Label"]("IDs Excluídos (deletados)"));

local excludeIdsContainer = trackConfigWidget(UI["Container"](function(widget, items)
    storage["excludeIds"] = items;
    updateIds();
end, true));
excludeIdsContainer:setItems(storage["excludeIds"]);
excludeIdsContainer:setHeight(35);

trackConfigWidget(UI["Separator"]());
trackConfigWidget(UI["Label"]("IDs dos Buracos - Skip no SPACE"));

local skipHoleIdsContainer = trackConfigWidget(UI["Container"](function(widget, items)
    storage["skipHoleIds"] = items;
    updateIds();
end, true));
skipHoleIdsContainer:setItems(storage["skipHoleIds"]);
skipHoleIdsContainer:setHeight(35);

trackConfigWidget(UI["Separator"]());

updateIds();

-- ---------------------------------------------------------------------------
-- Ligações do switch e do botão config (igual à macro de Buffs)
-- ---------------------------------------------------------------------------
botWidget.switch.onClick = function()
    local status = not botWidget.switch:isOn();
    storage["stairsConfig"]["enabled"] = status;
    botWidget.switch:setOn(status);
end

botWidget.config.onClick = function()
    setConfigVisible(not configOpen);
end

if (storage["stairsConfig"]["enabled"]) then
    botWidget.switch:setOn(true);
end

-- ---------------------------------------------------------------------------
-- Macro principal
-- ---------------------------------------------------------------------------
local nextSkipSpam = 0;

local function isStandingOnSkipHole()
    local playerPos = player and player:getPosition();
    if (not playerPos) then return false; end
    local tile = g_map["getTile"](playerPos);
    if (not tile) then return false; end

    for _, item in ipairs(tile:getItems()) do
        if (skipHoleIds[item:getId()]) then
            return true;
        end
    end
    return false;
end

local mainMacro = macro(50, function()
    if (not botWidget.switch:isOn()) then return end

    -- Buraco/SQM configurado: enquanto estiver EM CIMA dele e segurando SPACE,
    -- envia "skip" repetidamente. Soltou SPACE ou saiu do SQM = para na hora.
    if (isKeyPressed("Space") and isStandingOnSkipHole()) then
        if (nextSkipSpam or 0) <= now then
            nextSkipSpam = now + 50;
            say("skip");
        end
        return;
    end

    if (isKeyPressed(storage["stairsConfig"]["actionKey"])) then
        if (actualTile ~= nil) then
            displayTime = nil;
            local playerPos = player:getPosition();
            local tilePos = actualTile:getPosition();
            if (tilePos ~= nil and tilePos["z"] == playerPos["z"]) then
                player:lockWalk(50);
                doHighlightTile(actualTile, "green");
                local neighborTile = getNearestTile(tilePos);
                local useThing = neighborTile and neighborTile:getTopThing();
                local distance = getDistanceBetween(tilePos, playerPos);

                if (not isMobile and useThing and distance > 2 and storage["checkBoxs"]["useKunai"] and storage["kunaiId"] and neighborTile:canShoot(6)) then
                    g_game["stop"]();
                    potExhaust = now + 100;
                    return useWith(storage["kunaiId"], useThing);
                end

                if (distance == 1 and actualTile:isWalkable() and (delayTime or 0) < now) then
                    delayTime = now + 200;
                    if (not samePos(lastWalkPosition, tilePos) and autoWalk(tilePos, 1)) then
                        lastWalkPosition = { x = tilePos["x"], y = tilePos["y"], z = tilePos["z"] };
                    else
                        lastWalkPosition = nil;
                    end
                end

                if (distance <= 1) then
                    local isWalkable = actualTile:isWalkable(true);
                    if (isWalkable and actualTile:isPathable()) then
                        potExhaust = now + 100;
                    end

                    if (not isWalkable) then
                        if ((delayTime or 0) >= now) then
                            return;
                        end
                        delayTime = now + 300;
                        potExhaust = now + 300;
                    end

                    return g_game["use"](actualTile:getTopUseThing());
                end

                if (doUseWalk(tilePos)) then return; end
            end
        end

        if (displayTime == nil) then
            displayTime = now + 300;
        elseif (displayTime < now) then
            displayTime = now + 3000;
            displayGameMessage("Sem escadas/portais/portas por perto.");
        end
    end

    if (actualTile ~= nil) then
        doHighlightTile(actualTile, "red");
    end
end)

-- Varredura de escadas: o Queue_call so executa 1 tarefa a cada 50 ms, entao
-- rodar esta macro a 1 ms (como era) so gastava CPU. Sem a tecla de acao
-- pressionada, varre mais devagar (100 ms).
local nextIdleScan = 0
macro(50, function()
    if (not botWidget.switch:isOn()) then return end

    if (not isKeyPressed(storage["stairsConfig"]["actionKey"])) then
        if (nextIdleScan > now) then return end
        nextIdleScan = now + 150
    end

    if (putOnQueue == nil) then
        return addEvent(verifyTiles);
    end

    putOnQueue(verifyTiles);
end)


-- Atalhos: registra esta macro para aparecer na janela Atalhos (aba User).
do
  local g = (type(_G) == "table" and _G) or modules["_G"]
  g.configData = g.configData or {}
  g.configData["autoEscadas"] = {macro = botWidget.switch}
end
