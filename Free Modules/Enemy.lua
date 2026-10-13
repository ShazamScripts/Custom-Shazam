-- ============================================================================
-- ENEMY (portado do sistema anterior, sem sistema anterior)
-- Ataca automaticamente jogadores inimigos que aparecem na tela.
--
-- Interface padronizada: Macro + Config na mesma linha (igual ao Fugas).
--  * Clique no botao "Enemy" para ligar/desligar;
--  * Clique em "Config" (ou botao direito na linha) para abrir a Friend List;
--  * Quem estiver na Friend List NUNCA e atacado.
--
-- Tambem nao ataca: membros da sua party (escudo) e da sua guild (emblema),
-- nem jogadores em PZ / alvos que o servidor marcou como "nao pode atacar".
-- ============================================================================
setDefaultTab("Main")

_G.configData = _G.configData or {}
local configData = _G.configData
configData["enemy"] = {}

-- ---------------------------------------------------------------------------
-- Storage (mesma chave do sistema anterior, entao configs antigas continuam valendo)
-- ---------------------------------------------------------------------------
if type(storage["attackEnemy"]) ~= "table" then
  storage["attackEnemy"] = {}
end
local config = storage["attackEnemy"]

if config["macroActive"] == nil then config["macroActive"] = false end
if type(config["friendList"]) ~= "table" then config["friendList"] = {} end

local function persist()
  if type(ShazamPersistNow) == "function" then
    ShazamPersistNow()
  elseif type(saveConfig) == "function" then
    saveConfig()
  end
end

-- Guard da Shazam (se nao existir, tudo segue funcionando)
local function guardOk()
  if type(ShazamGuard) == "table" and type(ShazamGuard.check) == "function" then
    return ShazamGuard.check()
  end
  return true
end

-- ---------------------------------------------------------------------------
-- Friend List
-- ---------------------------------------------------------------------------
local function normalize(name)
  local clean = tostring(name or ""):lower():gsub("^%s+", ""):gsub("%s+$", "")
  return clean
end

local friendSet = {}
local function rebuildFriendSet()
  friendSet = {}
  for _, friendName in ipairs(config["friendList"]) do
    friendSet[normalize(friendName)] = true
  end
end
rebuildFriendSet()

local function isFriend(name)
  if type(name) ~= "string" and name and type(name.getName) == "function" then
    name = name:getName()
  end
  return friendSet[normalize(name)] == true
end

-- ---------------------------------------------------------------------------
-- Regras de "pode atacar?"
-- ---------------------------------------------------------------------------
-- Mensagens do servidor que significam "esse alvo nao pode ser atacado".
local blockedMessages = {
  "You may not attack a person in a protection zone.",
  "You may not attack this player.",
  "This action is not permitted in a safe zone.",
  "Voc\234 n\227o pode atacar este jogador.",
  "Voc\234 n\227o pode atacar uma pessoa em zona de prote\231\227o.",
}
for index, text in ipairs(blockedMessages) do
  blockedMessages[index] = text:trim():lower()
end

-- Quando a posicao do player muda, ele pode ter saido da PZ: limpa a whitelist.
onCreaturePositionChange(function(creature, newPos, oldPos)
  if not config["macroActive"] then return end
  if not guardOk() then return end
  if not newPos or not oldPos then return end

  local posKey = newPos["x"] .. "," .. newPos["y"] .. "," .. newPos["z"]
  if creature["lastPos"] ~= posKey then
    creature["lastPos"] = posKey
    creature["whiteList"] = nil
  end
end)

-- Se o servidor disse "nao pode atacar" e o alvo ficou parado, para de tentar.
onTextMessage(function(mode, text)
  if not config["macroActive"] then return end
  if not guardOk() then return end
  text = text:trim():lower()

  for _, blocked in ipairs(blockedMessages) do
    if text:find(blocked, 1, true) then
      local target = g_game.getAttackingCreature()
      if target then
        local targetPos = target:getPosition()
        if targetPos == nil then return end
        schedule(500, function()
          local newPos = target:getPosition()
          if newPos and table["equal"](newPos, targetPos) then
            target["whiteList"] = true
          end
        end)
      end
      break
    end
  end
end)

local function isAttackable(creature)
  if not creature or not creature:getPosition() then return false end

  local tile = creature:getTile()
  if not tile or not tile:hasBlockingCreature() then return false end

  local safeFight = g_game.isSafeFight()
  local skull = creature:getSkull()
  if safeFight and skull == 0 then return false end

  if not creature:isPlayer() or creature == player then return false end

  local healthPercent = creature:getHealthPercent()
  if not healthPercent or healthPercent <= 0 then return false end

  if isFriend(creature:getName()) then return false end
  if creature:getEmblem() == 1 then return false end   -- membro da sua guild
  if creature:getShield() >= 3 then return false end   -- membro da sua party

  return creature["whiteList"] == nil
end

-- ---------------------------------------------------------------------------
-- Interface: linha com [Enemy] [Config]
-- ---------------------------------------------------------------------------
local enemyRow = setupUI([[
Panel
  height: 17

  BotSwitch
    id: macro
    anchors.top: parent.top
    anchors.left: parent.left
    text-align: center
    width: 130
    !text: tr("Enemy")

  Button
    id: config
    anchors.top: prev.top
    anchors.bottom: prev.bottom
    anchors.left: prev.right
    anchors.right: parent.right
    text: Config
]])

-- Janela da Friend List (fica escondida ate clicar em Config)
local enemyWindow = setupUI([[
MainWindow
  text: Enemy - Friend List
  size: 260 330

  Label
    id: infoLabel
    anchors.top: parent.top
    anchors.left: parent.left
    anchors.right: parent.right
    text-align: center
    text: Quem estiver aqui nunca sera atacado

  TextEdit
    id: nameEdit
    anchors.top: infoLabel.bottom
    anchors.left: parent.left
    anchors.right: parent.right
    margin-top: 6

  Button
    id: addButton
    anchors.top: nameEdit.bottom
    anchors.left: parent.left
    margin-top: 4
    width: 110
    text: Adicionar

  Button
    id: removeButton
    anchors.top: nameEdit.bottom
    anchors.right: parent.right
    margin-top: 4
    width: 110
    text: Remover

  TextList
    id: friendList
    anchors.top: addButton.bottom
    anchors.left: parent.left
    anchors.right: friendListScrollBar.left
    anchors.bottom: closeButton.top
    margin-top: 6
    margin-bottom: 6
    padding: 1
    vertical-scrollbar: friendListScrollBar

  VerticalScrollBar
    id: friendListScrollBar
    anchors.top: friendList.top
    anchors.bottom: friendList.bottom
    anchors.right: parent.right
    step: 14
    pixels-scroll: true

  Button
    id: closeButton
    anchors.bottom: parent.bottom
    anchors.right: parent.right
    text: Fechar
    width: 70
]], g_ui.getRootWidget())

enemyWindow:hide()

local function refreshFriendList()
  enemyWindow.friendList:destroyChildren()
  for _, friendName in ipairs(config["friendList"]) do
    local entry = setupUI([[
Label
  height: 16
  text-offset: 3 0
  focusable: true
  background-color: alpha
  $focus:
    background-color: #00000055
]], enemyWindow.friendList)
    entry:setText(friendName)
  end
end

local function addFriend()
  local name = enemyWindow.nameEdit:getText():trim()
  if name == "" then return end

  if isFriend(name) then
    enemyWindow.nameEdit:clearText()
    return
  end

  table.insert(config["friendList"], name)
  rebuildFriendSet()
  refreshFriendList()
  enemyWindow.nameEdit:clearText()
  persist()
end

local function removeFriend()
  local selected = enemyWindow.friendList:getFocusedChild()
  if not selected then return end

  local key = normalize(selected:getText())
  for index = #config["friendList"], 1, -1 do
    if normalize(config["friendList"][index]) == key then
      table.remove(config["friendList"], index)
    end
  end
  rebuildFriendSet()
  refreshFriendList()
  persist()
end

enemyWindow.addButton.onClick = addFriend
enemyWindow.removeButton.onClick = removeFriend
enemyWindow.closeButton.onClick = function() enemyWindow:hide() end

-- Enter dentro do campo de texto tambem adiciona
enemyWindow.nameEdit.onKeyDown = function(widget, keyCode)
  if keyCode == KeyEnter or keyCode == KeyReturn then
    addFriend()
    return true
  end
  return false
end

local function toggleWindow()
  if enemyWindow:isVisible() then
    enemyWindow:hide()
  else
    enemyWindow:show()
    enemyWindow:raise()
    enemyWindow:focus()
  end
end

enemyRow.config.onClick = toggleWindow
enemyRow.onMouseRelease = function(self, mousePos, mouseButton)
  if mouseButton == 2 then
    enemyWindow:show()
    enemyWindow:raise()
    enemyWindow:focus()
  end
end

refreshFriendList()

enemyRow.macro:setOn(config["macroActive"])
enemyRow.macro.onClick = function()
  config["macroActive"] = not config["macroActive"]
  enemyRow.macro:setOn(config["macroActive"])
  persist()
end

-- ---------------------------------------------------------------------------
-- Macro principal: escolhe e ataca o inimigo com menos vida na tela
-- ---------------------------------------------------------------------------
local canShoot = function(creature)
  if creature["canShoot"] then
    return creature:canShoot()
  end
  return true
end

macro(100, function()
  if not config["macroActive"] then return end
  if type(keepTarget) == "table" and keepTarget["isStacking"] then return end
  if type(isInPz) == "function" and isInPz() then return end

  local target = g_game.getAttackingCreature()

  -- Candidato atual = o alvo que ja esta sendo atacado (se for valido)
  local best = {}
  if target ~= nil and isAttackable(target) then
    best = {
      spec = target,
      hp = target:getHealthPercent(),
      id = target:getId(),
      isGuildEnemy = target:getEmblem() == 2,
    }
  end

  local partyListChanged = false

  for _, spec in ipairs(getSpectators()) do
    -- Qualquer player identificado como membro da PT entra automaticamente
    -- na Friend List e fica salvo para nao ser atacado pelo Enemy.
    if spec ~= nil and spec:isPlayer() and spec ~= player and spec:getShield() >= 3 then
      local partyName = spec:getName()
      if partyName and partyName ~= "" and not isFriend(partyName) then
        table.insert(config["friendList"], partyName)
        friendSet[normalize(partyName)] = true
        partyListChanged = true
      end
    end

    if spec ~= nil and isAttackable(spec) then
      local emblem = spec:getEmblem()
      -- Se ja estou em cima de um inimigo de guild, so troco por outro de guild
      if (not best["isGuildEnemy"] or emblem == 2) and canShoot(spec) then
        local specHp = spec:getHealthPercent()
        local specId = spec:getId()

        if not best["hp"]
          or best["hp"] > specHp + 5
          or (best["hp"] == specHp and best["id"] < specId and target == nil) then
          best = {
            spec = spec,
            hp = specHp,
            id = specId,
            isGuildEnemy = emblem == 2,
          }
        end
      end
    end
  end

  if partyListChanged then
    refreshFriendList()
    persist()
  end

  if best["spec"] and target ~= best["spec"] then
    g_game.attack(best["spec"])
    return delay(math.random(150, 300))
  end
end)

configData["enemy"]["macro"] = enemyRow.macro
