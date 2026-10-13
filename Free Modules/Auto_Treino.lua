-- ============================================================
-- AUTO TREINO (OTCv8 / vBot)
-- - POWER DOWN: mantem configuracao de magia + % de mana
-- - CHAKRA REST: sempre ativo junto com Auto Treino
-- - Cooldown do Chakra Rest SO inicia quando a fala laranja
--   do proprio personagem confirma que a magia realmente saiu
-- - Ao ligar: tenta Power Down e Chakra Rest imediatamente
-- - Dance opcional
-- ============================================================

storage.autoTreino = storage.autoTreino or {}
local cfg = storage.autoTreino

if cfg.enabled == nil then cfg.enabled = false end
if cfg.spell == nil then
  local old = cfg.slots and cfg.slots[1]
  cfg.spell = old and old.spell or "power down"
  cfg.mana = old and old.mana or 90
end
cfg.mana = cfg.mana or 90
cfg.buffSpell = cfg.buffSpell or "Chakra Rest"
cfg.buffCd = cfg.buffCd or 60
cfg.danceOn = cfg.danceOn or false
cfg.danceMs = cfg.danceMs or 500
cfg.buffOn = nil

local iconUI = setupUI([[
Panel
  height: 17
  BotSwitch
    id: title
    anchors.top: parent.top
    anchors.left: parent.left
    text-align: center
    width: 130
    text: Auto Treino
  Button
    id: settings
    anchors.top: prev.top
    anchors.left: prev.right
    anchors.right: parent.right
    margin-left: 3
    height: 17
    text: Setup
]])

local ui = setupUI([[
MainWindow
  !text: tr('Auto Treino')
  size: 240 390

  Label
    id: lblSpell
    anchors.top: parent.top
    anchors.left: parent.left
    margin-top: 6
    margin-left: 12
    text: Power Down

  TextEdit
    id: spell
    anchors.top: lblSpell.bottom
    anchors.left: parent.left
    anchors.right: parent.right
    margin-top: 2
    margin-left: 12
    margin-right: 12

  Label
    id: lblMana
    anchors.top: spell.bottom
    anchors.left: parent.left
    margin-top: 6
    margin-left: 12
    text: Usar Power Down com mana >= (%)

  Button
    id: manaMinus
    anchors.top: lblMana.bottom
    anchors.left: parent.left
    margin-top: 2
    margin-left: 12
    width: 28
    height: 22
    text: -

  TextEdit
    id: manaEdit
    anchors.top: manaMinus.top
    anchors.left: manaMinus.right
    margin-left: 4
    width: 60
    height: 22
    text-align: center

  Button
    id: manaPlus
    anchors.top: manaMinus.top
    anchors.left: manaEdit.right
    margin-left: 4
    width: 28
    height: 22
    text: +

  Label
    id: lblBuff
    anchors.top: manaMinus.bottom
    anchors.left: parent.left
    margin-top: 14
    margin-left: 12
    text: Chakra Rest

  TextEdit
    id: buffSpell
    anchors.top: lblBuff.bottom
    anchors.left: parent.left
    anchors.right: parent.right
    margin-top: 2
    margin-left: 12
    margin-right: 12

  Label
    id: lblBuffCd
    anchors.top: buffSpell.bottom
    anchors.left: parent.left
    margin-top: 6
    margin-left: 12
    text: Cooldown Chakra Rest (segundos)

  TextEdit
    id: buffCd
    anchors.top: lblBuffCd.bottom
    anchors.left: parent.left
    anchors.right: parent.right
    margin-top: 2
    margin-left: 12
    margin-right: 12

  Label
    id: lblDance
    anchors.top: buffCd.bottom
    anchors.left: parent.left
    margin-top: 12
    margin-left: 12
    text: Dance (intervalo em ms)

  TextEdit
    id: danceMs
    anchors.top: lblDance.bottom
    anchors.left: parent.left
    anchors.right: parent.right
    margin-top: 2
    margin-left: 12
    margin-right: 12

  BotSwitch
    id: danceSwitch
    anchors.top: danceMs.bottom
    anchors.left: parent.left
    anchors.right: parent.right
    margin-top: 4
    margin-left: 12
    margin-right: 12
    text-align: center
    text: Dance

  Button
    id: closeButton
    anchors.horizontalCenter: parent.horizontalCenter
    anchors.bottom: parent.bottom
    margin-bottom: 5
    width: 80
    text: Fechar
]], g_ui.getRootWidget())

ui:hide()

local function setMana(value)
  value = math.max(0, math.min(100, math.floor(value)))
  cfg.mana = value
  ui.manaEdit:setText(tostring(value))
end

ui.spell:setText(cfg.spell)
ui.manaEdit:setText(tostring(cfg.mana))
ui.buffSpell:setText(cfg.buffSpell)
ui.buffCd:setText(tostring(cfg.buffCd))
ui.danceMs:setText(tostring(cfg.danceMs))
ui.danceSwitch:setOn(cfg.danceOn)
iconUI.title:setOn(cfg.enabled)

ui.spell.onTextChange = function(widget, text) cfg.spell = text end
ui.manaMinus.onClick = function() setMana(cfg.mana - 1) end
ui.manaPlus.onClick = function() setMana(cfg.mana + 1) end
ui.manaEdit.onTextChange = function(widget, text)
  local n=tonumber(text)
  if not n then return end
  if n > 100 or n < 0 then setMana(n) else cfg.mana=math.floor(n) end
end
ui.buffSpell.onTextChange = function(widget,text) cfg.buffSpell=text end
ui.buffCd.onTextChange = function(widget,text)
  local n=tonumber(text)
  if n and n>=0 then cfg.buffCd=n end
end
ui.danceMs.onTextChange = function(widget,text)
  local n=tonumber(text)
  if n and n>=100 then cfg.danceMs=n end
end
ui.danceSwitch.onClick=function(widget)
  cfg.danceOn=not cfg.danceOn
  widget:setOn(cfg.danceOn)
end
iconUI.settings.onClick=function()
  if ui:isVisible() then ui:hide() else ui:show(); ui:raise(); ui:focus() end
end
ui.closeButton.onClick=function() ui:hide() end

local nextRest=0
local restPendingUntil=0
local nextPower=0
local nextDance=0
local danceDir=0

local function norm(s)
  return tostring(s or ""):lower():trim()
end

local function tryRest()
  if not cfg.enabled or cfg.buffSpell:len()==0 then return end
  if now < nextRest or now < restPendingUntil then return end
  say(cfg.buffSpell)
  -- trava curta de tentativa; NAO e o cooldown
  restPendingUntil=now+1200
end

-- Confirma pela fala laranja do proprio personagem.
-- So aqui comeca o cooldown real.
onTalk(function(name, level, mode, text, channelId, pos)
  if not cfg.enabled or not player then return end
  if norm(name) ~= norm(player:getName()) then return end
  if norm(text) ~= norm(cfg.buffSpell) then return end
  nextRest=now+(cfg.buffCd*1000)
  restPendingUntil=0
end)

local function startNow()
  nextPower=0
  nextRest=0
  restPendingUntil=0

  -- Ao ligar, Power Down primeiro.
  if cfg.spell:len()>0 then
    say(cfg.spell)
    nextPower=now+1000
  end

  -- E Chakra Rest logo depois.
  schedule(250,function()
    if cfg.enabled then tryRest() end
  end)
end

iconUI.title.onClick=function(widget)
  cfg.enabled=not cfg.enabled
  widget:setOn(cfg.enabled)
  if cfg.enabled then
    startNow()
  else
    restPendingUntil=0
  end
end

macro(100,function()
  if not cfg.enabled then return end

  if cfg.danceOn and now>=nextDance then
    danceDir=(danceDir+1)%4
    g_game.turn(danceDir)
    nextDance=now+cfg.danceMs
  end

  -- Power Down continua com a mesma logica por % de mana.
  if cfg.spell:len()>0 and manapercent()>=cfg.mana and now>=nextPower then
    say(cfg.spell)
    nextPower=now+1000
    return
  end

  -- Chakra Rest tenta ate confirmar; depois respeita o cooldown inteiro.
  tryRest()
end)
