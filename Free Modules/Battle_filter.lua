-- ============================================================================
-- BATTLE FILTER (Versão Pura & Independente)
-- ============================================================================
local FREE_VERSION = false
local battleFilter = {}
local Guard = ShazamGuard
local pcall, type, print, tostring, tonumber = pcall, type, print, tostring, tonumber
local gameRef = g_game
local gameBattle = modules["_G"]["modules"]["game_battle"]

local checkBoxWidget = "CheckBox\n  id: checkBox\n"
storage["checkBoxs"] = storage["checkBoxs"] or {}

local addCheckBox = function(id, name, callback)
    local checkBox = setupUI(checkBoxWidget)
    checkBox:setText(name)
    checkBox["onCheckChange"] = function(widget, checked)
        storage["checkBoxs"][id] = checked
        if (callback) then callback(widget, checked) end
    end
    schedule(0, function()
        checkBox:setChecked(storage["checkBoxs"][id])
        checkBox:onCheckChange(storage["checkBoxs"][id])
    end)
    return checkBox
end

battleFilter["checkBox"] = addCheckBox("battleFilter", "Filtrar Battle", function(widget, checked)
    if (battleFilter["main"]) then battleFilter["main"]() end
    for key, widget in pairs(battleFilter) do
        if (type(widget) ~= "userdata" or key == "checkBox") then goto continue end
        if (checked) then widget:show() else widget:hide() end
        ::continue::
    end
end)

storage["battleFilter"] = storage["battleFilter"] or {
    hideFriends = false,
    hidePlayers = false,
    hideMonsters = false,
    hideSkulls = false,
    hideNPCs = false
}

battleFilter["config"] = storage["battleFilter"]
local config = battleFilter["config"]

battleFilter["checkBoxPanel"] = setupUI("Panel\n  id: mainPanel\n  size: 120 20\n  image-source: /images/ui/panel_flat\n  image-border: 6\n  \n  BattlePlayers\n    id: hidePlayers\n    !tooltip: tr('Hide players')\n    anchors.top: parent.top\n    anchors.left: parent.left\n\n  BattleNPCs\n    id: hideNPCs\n    !tooltip: tr('Hide Npcs')\n    anchors.top: parent.top\n    anchors.left: prev.right\n\n  BattleMonsters\n    id: hideMonsters\n    !tooltip: tr('Hide monsters')\n    anchors.top: parent.top\n    anchors.left: prev.right\n\n  BattleSkulls\n    id: hideSkulls\n    !tooltip: tr('Hide non-skull players')\n    anchors.top: parent.top\n    anchors.left: prev.right\n\n  BattleParty\n    id: hideFriends\n    !tooltip: tr('Hide party members')\n    anchors.top: parent.top\n    anchors.left: prev.right\n")

local mainPanel = battleFilter["checkBoxPanel"]
local battlePanel = g_ui["getRootWidget"]():recursiveGetChildById("battlePanel")
battleFilter["childs"] = {}
if battlePanel then
    for index, child in ipairs(battlePanel:getChildren()) do
        table["insert"](battleFilter["childs"], child)
    end
end

local enableButton = g_ui["getRootWidget"]():recursiveGetChildById("enableButton")
local isBotOn = function()
    if not enableButton then return true end
    return enableButton:getText() == "On"
end

-- ---------------------------------------------------------------------------
-- Filtro do Battle com protecao:
--  * chaves proprias (__shazam_*), sem dividir estado com outras customs;
--  * se a Shazam nao esta rodando (outra custom aberta / bot desligado) o filtro
--    vira "passa direto" e se remove sozinho;
--  * qualquer erro cai no filtro original do client (antes o Battle inteiro
--    quebrava e o TargetBot das outras customs nao enxergava nenhum monstro).
-- ---------------------------------------------------------------------------
local previousFilter = gameBattle["__shazam_filter"]
local previousOriginal = gameBattle["__shazam_filter_original"]
if previousFilter and previousOriginal and gameBattle["doCreatureFitFilters"] == previousFilter then
    gameBattle["doCreatureFitFilters"] = previousOriginal
end

local originalFilter = gameBattle["doCreatureFitFilters"]

local function customFilter(creature)
    if (type(creature) ~= "userdata") then return false end

    local creatureId = creature:getId()
    if (not tonumber(creatureId)) then return false end

    local localPlayer = gameRef.getLocalPlayer()
    if (not localPlayer) then return originalFilter(creature) end

    local playerPos = localPlayer:getPosition()
    local creaturePos = creature:getPosition()
    if (playerPos == nil or creaturePos == nil or playerPos["z"] ~= creaturePos["z"]) then return false end
    if (creature:isLocalPlayer()) then return false end

    local creatureHp = creature:getHealthPercent()
    if (not creatureHp or creatureHp <= 0) then return false end
    if (config["hidePlayers"] and creature:isPlayer()) then return false end
    if (config["hideMonsters"] and creature:isMonster()) then return false end
    if (config["hideNPCs"] and creature:isNpc()) then return false end
    if (config["hideSkulls"] and creature:isPlayer() and creature:getSkull() == 0) then return false end
    if (config["hideFriends"] and (creature:getShield() >= 3 or creature:getEmblem() == 1 or creature:getEmblem() == 4)) then return false end

    return true
end

battleFilter["doFilter"] = function(creature)
    if (not Guard.check()) then return originalFilter(creature) end
    if (not isBotOn()) then return originalFilter(creature) end

    local ok, result = pcall(customFilter, creature)
    if (not ok) then return originalFilter(creature) end
    return result
end

battleFilter["main"] = function()
    local wanted = storage["checkBoxs"]["battleFilter"] and Guard.alive()
    local current = gameBattle["doCreatureFitFilters"]
    if (wanted) then
        if (current ~= battleFilter["doFilter"]) then
            gameBattle["doCreatureFitFilters"] = battleFilter["doFilter"]
        end
    elseif (current == battleFilter["doFilter"]) then
        gameBattle["doCreatureFitFilters"] = originalFilter
    end
end

gameBattle["__shazam_filter"] = battleFilter["doFilter"]
gameBattle["__shazam_filter_original"] = originalFilter

Guard.onCleanup(function()
    if (gameBattle["doCreatureFitFilters"] == battleFilter["doFilter"]) then
        gameBattle["doCreatureFitFilters"] = originalFilter
    end
    gameBattle["__shazam_filter"] = nil
    gameBattle["__shazam_filter_original"] = nil
end)

local hideButtons = {mainPanel["hidePlayers"], mainPanel["hideNPCs"], mainPanel["hideMonsters"], mainPanel["hideSkulls"], mainPanel["hideFriends"]}
for _, button in ipairs(hideButtons) do
    local buttonId = button:getId()
    button["onCheckChange"] = function(widget, checked)
        config[buttonId] = checked
        battleFilter["main"]()
    end
    button:setChecked(config[buttonId])
    button:setMarginLeft(8)
end

-- Os checkboxes ja chamam main() ao mudar; a macro so serve de rede de seguranca.
macro(1000, battleFilter["main"])
