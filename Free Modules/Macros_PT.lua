-- Macros_PT.lua
-- Aceitar PT, Invitar PT e Buy AOL. Follow RTS foi separado.
--   * Caixinhas (Aceitar PT / Invitar PT / Buy AOL) ficam na aba MAIN.
--   * As macros de PT sao internas e seus controles ficam somente na aba MAIN.
-- A caixinha da Main e a macro da User ficam sempre sincronizadas
-- (ligar/desligar em qualquer um dos dois lados reflete no outro) e o estado
-- e gravado na hora no storage.

-----------------------------------------------------------------------------
-- Helpers globais (equivalentes aos da Macros.lua da Shazam)
-----------------------------------------------------------------------------
local macroDelay = 200
if type(storage["scrollBars"]) == "table" and tonumber(storage["scrollBars"]["macroDelay"]) then
  macroDelay = tonumber(storage["scrollBars"]["macroDelay"])
end

-- Cache curto de spectators (evita varias leituras iguais do mapa no mesmo ciclo)
FREE_GET_SPECTATORS_CACHED = FREE_GET_SPECTATORS_CACHED or function(multifloor, ttl)
  ttl = tonumber(ttl) or 40
  local cache = FREE_SPECTATORS_CACHE
  if type(cache) ~= "table" then
    cache = {}
    FREE_SPECTATORS_CACHE = cache
  end

  local clockNow = tonumber(now) or 0
  local key = multifloor and "multi" or "single"
  if cache[key] and (clockNow - (cache[key].at or 0)) <= ttl then
    return cache[key].list
  end

  local ok, list = pcall(function()
    return getSpectators(multifloor == true)
  end)
  if not ok or type(list) ~= "table" then
    return {}
  end

  cache[key] = {at = clockNow, list = list}
  return list
end

-- Salva o storage logo depois de mexer numa caixinha (agrupa varias mudancas)
local pendingSave = false
local function saveSoon()
  if pendingSave then return end
  pendingSave = true
  schedule(300, function()
    pendingSave = false
    if type(saveConfig) == "function" then
      pcall(saveConfig)
    end
  end)
end

-----------------------------------------------------------------------------
-- ACEITAR PT / INVITAR PT / BUY AOL
-----------------------------------------------------------------------------
if type(storage.ptSystem) ~= "table" then
  storage.ptSystem = {aceitar = false, invitar = false}
end
storage.ptSystem.aceitar = storage.ptSystem.aceitar == true
storage.ptSystem.invitar = storage.ptSystem.invitar == true
storage["buyAol"] = storage["buyAol"] == true

local guildConfig = {
  guildEmblem = 1,
  maxDist = 5,
  multifloor = true,
  ignoreShield = 2
}

-- Verifica o slot do amuleto usando a mesma API do Auto Jam.
local function hasNeck()
  if type(getNeck) == "function" then
    return getNeck() ~= nil
  end
  if type(getInventoryItem) == "function" then
    return getInventoryItem(2) ~= nil
  end
  return true -- evita compras repetidas se nao houver API disponivel
end

-- As macros de PT sao internas: os unicos controles visiveis ficam na aba MAIN.
setDefaultTab("Main")

aceitarPTMacro = macro(macroDelay, function()
  if not storage.ptSystem.aceitar then return end

  local spectators = FREE_GET_SPECTATORS_CACHED(false, 40)
  for _, spec in ipairs(spectators) do
    if spec:isPlayer() and spec:getShield() == 1 then
      g_game.partyJoin(spec:getId())
    end
  end
end)

invitarPTMacro = macro(macroDelay, function()
  if not storage.ptSystem.invitar then return end

  local spectators = FREE_GET_SPECTATORS_CACHED(guildConfig.multifloor, 40)
  for _, spec in ipairs(spectators) do
    if spec:isPlayer()
    and spec ~= g_game.getLocalPlayer()
    and spec:getEmblem() == guildConfig.guildEmblem
    and not spec:isPartyMember()
    and spec:getShield() ~= guildConfig.ignoreShield
    and getDistanceBetween(spec:getPosition(), pos()) <= guildConfig.maxDist then
      g_game.partyInvite(spec:getId())
      break
    end
  end
end)

buyAolMacro = macro(2000, function()
  if storage["buyAol"] and not hasNeck() then
    say("!jam")
  end
end)

-- As macros internas nao recebem nome: assim nenhum botao/macro extra aparece.
-- A ativacao/desativacao e feita exclusivamente pelas caixinhas da Main.

-- onTalk registrado UMA vez so (nao dentro da macro, senao empilha a cada ciclo)
onTalk(function(name, level, mode, text, channelId, pos)
  if not storage.ptSystem.invitar then return end

  local localPlayer = g_game.getLocalPlayer()
  if not localPlayer then return end

  if name == localPlayer:getName() then return end
  if mode ~= 1 then return end

  if text:lower():find("pt") then
    local friend = getPlayerByName(name)
    if friend then
      g_game.partyInvite(friend:getId())
    end
  end
end)

-- As CAIXINHAS ficam na aba MAIN
setDefaultTab("Main")

local aceitarPTCheck = setupUI([[
CheckBox
  id: aceitarPTToggle
  text: "Aceitar PT"
  checked: false
]])

local invitarPTCheck = setupUI([[
CheckBox
  id: invitarPTToggle
  text: "Invitar PT"
  checked: false
]])

local buyAolCheck = setupUI([[
CheckBox
  id: buyAolToggle
  text: "Buy AOL"
  checked: false
]])

UI.Separator()

-- Liga caixinha (Main) <-> macro (User) <-> storage, nos dois sentidos.
local function bindToggle(checkbox, macroObj, getFlag, setFlag)
  local function apply(flag)
    if flag then macroObj.setOn() else macroObj.setOff() end
  end

  local lastMacroState

  checkbox.onCheckChange = function(widget, checked)
    setFlag(checked)
    apply(checked)
    lastMacroState = checked
    saveSoon()
  end

  -- estado inicial vem do storage
  local initial = getFlag()
  apply(initial)
  lastMacroState = initial
  checkbox:setChecked(initial)

  -- Nao existe mais controle visivel dessas macros fora da Main.
end

bindToggle(aceitarPTCheck, aceitarPTMacro,
  function() return storage.ptSystem.aceitar end,
  function(v) storage.ptSystem.aceitar = v end)

bindToggle(invitarPTCheck, invitarPTMacro,
  function() return storage.ptSystem.invitar end,
  function(v) storage.ptSystem.invitar = v end)

bindToggle(buyAolCheck, buyAolMacro,
  function() return storage["buyAol"] end,
  function(v) storage["buyAol"] = v end)

setDefaultTab("Main")


-- Atalhos: registra os controles de PT e Buy AOL.
do
  local g = (type(_G) == "table" and _G) or modules["_G"]
  g.configData = g.configData or {}
  g.configData["aceitarPt"] = {macro = {isOn = function(self) return aceitarPTCheck:isChecked() end, onClick = function(self) aceitarPTCheck:setChecked(not aceitarPTCheck:isChecked()) end}}
  g.configData["invitarPt"] = {macro = {isOn = function(self) return invitarPTCheck:isChecked() end, onClick = function(self) invitarPTCheck:setChecked(not invitarPTCheck:isChecked()) end}}
  g.configData["buyAol"] = {macro = {isOn = function(self) return buyAolCheck:isChecked() end, onClick = function(self) buyAolCheck:setChecked(not buyAolCheck:isChecked()) end}}
end
