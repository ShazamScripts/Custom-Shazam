setDefaultTab("User")
UI["Label"]("CONFIG"):setColor("white")

local horizontalScrollBar = "Panel\n  height: 15\n\n  Label\n    id: text\n    anchors.left: parent.left\n    anchors.right: parent.right\n    anchors.top: parent.top\n    text-align: center\n\n  HorizontalScrollBar\n    id: scroll\n    anchors.left: parent.left\n    anchors.right: parent.right\n    anchors.top: prev.top\n    minimum: 0\n    maximum: 10\n    step: 1\n"
storage["scrollBars"] = storage["scrollBars"] or {}

addScrollBar = function(id, title, min, max, defaultValue)
    local widget = setupUI(horizontalScrollBar)
    widget["scroll"]:setRange(min, max)
    if (max - min > 1000) then
        widget["scroll"]:setStep(100)
    elseif (max - min > 100) then
        widget["scroll"]:setStep(10)
    end
    widget["scroll"]:setValue(storage["scrollBars"][id] or defaultValue)
    widget["scroll"]["onValueChange"] = function(scroll, value)
        storage["scrollBars"][id] = value
        widget["scroll"]:setText(title .. ": " .. value)
    end
    widget["scroll"]["onValueChange"](widget["scroll"], widget["scroll"]:getValue())
    return widget
end

local checkBoxWidget = "CheckBox\n  id: checkBox\n"
storage["checkBoxs"] = storage["checkBoxs"] or {}
addCheckBox = function(id, name, callback)
    local checkBox = setupUI(checkBoxWidget)
    checkBox:setText(name)
    -- Sincroniza o visual da caixinha com o que esta salvo (antes ela ficava
    -- desmarcada na tela mesmo com o valor ligado no storage).
    checkBox:setChecked(storage["checkBoxs"][id] == true)
    checkBox["onCheckChange"] = function(widget, checked)
        storage["checkBoxs"][id] = checked
        if (callback) then callback(widget, checked) end
    end
    schedule(0, function() checkBox:onCheckChange(storage["checkBoxs"][id] == true) end)
    return checkBox
end

-- Controle compacto para configuracoes da aba User (< [valor] >)
local SHAZAM_USER_STEPPER_UI = [[
Panel
  height: 22

  Button
    id: minus
    anchors.left: parent.left
    anchors.top: parent.top
    width: 34
    height: 22
    text: <

  TextEdit
    id: edit
    anchors.left: minus.right
    anchors.right: plus.left
    anchors.top: parent.top
    margin-left: 4
    margin-right: 4
    height: 22
    text-align: center

  Button
    id: plus
    anchors.right: parent.right
    anchors.top: parent.top
    width: 34
    height: 22
    text: >
]]

local addUserStepper = function(id, title, minV, maxV, defaultValue, step)
    UI["Label"](title)
    local w = setupUI(SHAZAM_USER_STEPPER_UI)
    w.minV, w.maxV = minV, maxV
    w.step = math.max(1, math.floor(tonumber(step) or 1))
    w.value = minV
    w.busy = false
    w.getValue = function(self) return self.value end
    w.setValue = function(self, value)
        value = math.floor(tonumber(value) or self.minV)
        value = math.max(self.minV, math.min(self.maxV, value))
        self.value = value
        storage["scrollBars"][id] = value
        self.busy = true
        self.edit:setText(tostring(value))
        self.busy = false
        if self.onValueChange then self.onValueChange(self, value) end
    end
    w.minus.onClick = function() w:setValue(w.value - w.step) end
    w.plus.onClick = function() w:setValue(w.value + w.step) end
    w.edit.onTextChange = function(widget, text)
        if w.busy then return end
        local n = tonumber(text)
        if n then w:setValue(n) end
    end
    w:setValue(storage["scrollBars"][id] or defaultValue)
    return w
end

local macroDelay = addUserStepper("macroDelay", "Macro Delay", 10, 1000, 50, 10)
macroDelay:setTooltip("Funciona apos o restart do bot.")

-- Delay central das macros de gameplay. Os modulos usam este valor somente
-- para macros comuns; CaveBot/TargetBot/Jump/Escadas mantem seus proprios ciclos.
getShazamMacroDelay = function(defaultValue)
    local value = tonumber(storage["scrollBars"] and storage["scrollBars"]["macroDelay"])
    if value and value >= 10 and value <= 1000 then
        return value
    end
    return defaultValue or 200
end

-- Macro Delay controla a ACAO, nao o ciclo de leitura da macro.
-- Cada modulo pode usar uma chave independente para nao bloquear outras macros.
local shazamActionTimes = {}
canShazamMacroAct = function(key, defaultValue)
    local delayMs = getShazamMacroDelay(defaultValue or 200)
    local last = shazamActionTimes[key] or 0
    if now - last < delayMs then return false end
    shazamActionTimes[key] = now
    return true
end

local checkBoxWidget = "CheckBox\n  id: checkBox\n"
storage["checkBoxs"] = storage["checkBoxs"] or {}

-- Injeção local da função necessária para corrigir o erro de 'nil value'
local addCheckBoxLocal = function(id, name, callback)
    local checkBox = setupUI(checkBoxWidget)
    checkBox:setText(name)
    -- Sincroniza o visual da caixinha com o que esta salvo (antes ela ficava
    -- desmarcada na tela mesmo com o valor ligado no storage).
    checkBox:setChecked(storage["checkBoxs"][id] == true)
    checkBox["onCheckChange"] = function(widget, checked)
        storage["checkBoxs"][id] = checked
        if (callback) then callback(widget, checked) end
    end
    schedule(0, function() checkBox:onCheckChange(storage["checkBoxs"][id] == true) end)
    return checkBox
end

-- Registra uma caixinha da aba User no Atalhos (vira um icone de ligar/desligar).
local registerToggle = function(key, checkBox)
  if (checkBox == nil) then return end
  local g = (type(_G) == "table" and _G) or modules["_G"]
  g.configData = g.configData or {}
  g.configData[key] = {
    macro = {
      isOn = function(self) return checkBox:isChecked() end,
      onClick = function(self) checkBox:setChecked(not checkBox:isChecked()) end,
    }
  }
end

UI["Label"]("Haste")
storage["hasteSpell"] = storage["hasteSpell"] or "Concentrate Chakra Feet"
addTextEdit("hasteSpell", storage["hasteSpell"], function(widget, text) storage["hasteSpell"] = text end)
storage["checkBoxs"]["autoHaste"] = storage["checkBoxs"]["autoHaste"] ~= false
registerToggle("autoHaste", addCheckBoxLocal("autoHaste", "Auto Haste"))

-- Criado usando a função interna segura
registerToggle("healParalyze", addCheckBoxLocal("antiLyze", "Heal Paralyze"))

UI["Label"]("Regeneration")
storage["regenSpell"] = storage["regenSpell"] or "Big Regeneration"
local regenerationSpells = {}
local regenRefactor = function()
    regenerationSpells = storage["regenSpell"]:split(",")
    for index, spell in ipairs(regenerationSpells) do regenerationSpells[index] = spell:trim() end
end
regenRefactor()
storage["checkBoxs"]["autoRegen"] = storage["checkBoxs"]["autoRegen"] ~= false
registerToggle("autoRegen", addCheckBoxLocal("autoRegen", "Auto Regeneration"))

addTextEdit("regenSpell", storage["regenSpell"], function(widget, text)
    storage["regenSpell"] = text
    regenRefactor()
end)

-- Scrollbar injetada nativamente
local horizontalScrollBar = "Panel\n  height: 15\n\n  Label\n    id: text\n    anchors.left: parent.left\n    anchors.right: parent.right\n    anchors.top: parent.top\n    text-align: center\n\n  HorizontalScrollBar\n    id: scroll\n    anchors.left: parent.left\n    anchors.right: parent.right\n    anchors.top: prev.top\n    minimum: 0\n    maximum: 10\n    step: 1\n"
storage["scrollBars"] = storage["scrollBars"] or {}

local addScrollBarLocal = function(id, title, min, max, defaultValue)
    local widget = setupUI(horizontalScrollBar)
    widget["scroll"]:setRange(min, max)
    if (max - min > 1000) then
        widget["scroll"]:setStep(100)
    elseif (max - min > 100) then
        widget["scroll"]:setStep(10)
    end
    widget["scroll"]:setValue(storage["scrollBars"][id] or defaultValue)
    widget["scroll"]["onValueChange"] = function(scroll, value)
        storage["scrollBars"][id] = value
        widget["scroll"]:setText(title .. ": " .. value)
    end
    widget["scroll"]["onValueChange"](widget["scroll"], widget["scroll"]:getValue())
    return widget
end

addUserStepper("regenPercent", "Regeneration %", 1, 100, 100, 1)

-- ============================================================================
-- KUNAI DASH & JUMP (portado da aba User do sistema anterior)
-- Usado pelo Bug Map ("Dash Sunshin"), pelo Jump e pelas Escadas.
--  * Kunai Dash & Jump : liga/desliga o uso da kunai
--  * Id da Kunai       : item da kunai (padrao 7382)
--  * Distance          : distancia (tiles) que o Bug Map joga a kunai
--  * Tecla p/ crosshair: tecla que abre o "use with" da kunai (padrao F2)
-- ============================================================================
do
  local kunaiConfig = {baseId = 7382}
  local notify = function(msg)
    if (type(warn) == "function") then warn(msg) else print(msg) end
  end

  kunaiConfig["checkBox"] = addCheckBoxLocal("useKunai", "Kunai Dash & Jump", function(widget, checked)
    -- Caixinha marcada: mostra Id / Distance / Tecla. Desmarcada: esconde tudo.
    for key, child in pairs(kunaiConfig) do
      if (key ~= "checkBox" and key ~= "baseId" and type(child) ~= "number" and type(child) ~= "string") then
        pcall(function()
          if (checked == true) then child:show() else child:hide() end
        end)
      end
    end
  end)

  registerToggle("kunaiDashJump", kunaiConfig["checkBox"])

  kunaiConfig["idLabel"] = UI["Label"]("Id da Kunai")
  kunaiConfig["idTextEdit"] = addTextEdit("KUNAI ID", storage["kunaiId"] or kunaiConfig["baseId"], function(widget, text)
    local ID = tonumber(text)
    if (not ID) then
      return notify("Insira um id valido.")
    end
    storage["kunaiId"] = ID
  end)

  kunaiConfig["distanceScrollBar"] = addUserStepper("distanceKunai", "Distancia da Kunai", 2, 15, 10, 1)

  kunaiConfig["crossHairKunaiKeyLabel"] = UI["Label"]("Tecla para crosshair")
  kunaiConfig["crossHairKunaiKey"] = addTextEdit("keyKunai", storage["kunaiKey"] or "F2", function(widget, text)
    local combo = modules["corelib"]["retranslateKeyComboDesc"](text)
    if (not combo) then
      return notify("Insira uma tecla valida")
    end
    storage["kunaiKey"] = combo
  end)

  -- Primeira vez: grava o ID padrao para o Bug Map/Jump ja funcionarem.
  if (not tonumber(storage["kunaiId"])) then
    storage["kunaiId"] = kunaiConfig["baseId"]
  end

  local game_interface = modules["_G"]["package"]["loaded"]["game_interface"]
  onKeyDown(function(key)
    if (not storage["checkBoxs"]["useKunai"]) then return end
    if (key ~= (storage["kunaiKey"] or "F2")) then return end
    local kunaiId = tonumber(storage["kunaiId"])
    if (not kunaiId) then return end
    game_interface["startUseWith"](Item["create"](kunaiId))
  end)

  -- Aplica a visibilidade assim que todos os campos existem (sem esperar o schedule).
  pcall(function() kunaiConfig["checkBox"]:onCheckChange(storage["checkBoxs"]["useKunai"] == true) end)

  UI["Separator"]()
end


-- ============================================================================
-- BIJUU CONFIGS / USAR PILL / MARCAR CRIATURAS (portados da aba User do sistema anterior)
--  * Bijuu Configs    : com o outfit da bijuu ativo, usa o regen e o buff da bijuu
--  * Usar Pill        : usa a pill quando o alvo que voce ataca e um player
--  * Marcar criaturas : marca de vermelho as criaturas que o servidor manda marcar
-- ============================================================================
local shazamNotify = function(msg)
  if (type(warn) == "function") then warn(msg) else print(msg) end
end

-- Mostra/esconde uma lista de widgets (usado pelas caixinhas que abrem opcoes).
local setWidgetsVisible = function(list, visible)
  for _, child in ipairs(list) do
    pcall(function()
      if (visible) then child:show() else child:hide() end
    end)
  end
end

-- Guarda o widget na lista (se existir) e devolve ele.
local addWidget = function(list, widget)
  if (widget ~= nil) then table.insert(list, widget) end
  return widget
end

local normalizeText = function(text)
  return tostring(text or ""):lower():trim()
end

-- Nome do mundo sem simbolos (mesma regra do sistema anterior.getWorldName do sistema anterior).
local shazamWorldName = (tostring(g_game["getWorldName"]() or ""):gsub("[^%w%s]", ""))

-- ----------------------------------------------------------------------------
-- BIJUU CONFIGS
-- ----------------------------------------------------------------------------
do
  local bijuuWidgets = {}

  local bijuuCheckBox = addCheckBoxLocal("useBijuu", "Bijuu Configs", function(widget, checked)
    setWidgetsVisible(bijuuWidgets, checked == true)
  end)
  bijuuCheckBox:setTooltip("Feito com base no NTO ULTIMATE.")
  registerToggle("bijuuConfigs", bijuuCheckBox)

  -- Valores padrao gravados, para as macros nunca lerem nil.
  storage["bijuuOutfit"] = storage["bijuuOutfit"] or 0
  storage["bijuuRegen"] = storage["bijuuRegen"] or "Bijuu Regeneration"
  storage["bijuuBuff"] = storage["bijuuBuff"] or "Bijuu Yaiba"

  addWidget(bijuuWidgets, UI["Label"]("Bijuu outfit"))
  addWidget(bijuuWidgets, addTextEdit("bijuuOutfit", tostring(storage["bijuuOutfit"]), function(widget, text)
    local ID = tonumber(text)
    if (not ID) then
      return shazamNotify("Insira um outfit valido.")
    end
    storage["bijuuOutfit"] = ID
  end))

  addWidget(bijuuWidgets, UI["Label"]("Bijuu regen spell"))
  addWidget(bijuuWidgets, addTextEdit("bijuuRegen", tostring(storage["bijuuRegen"]), function(widget, text)
    storage["bijuuRegen"] = text:lower():trim()
  end))

  addWidget(bijuuWidgets, UI["Label"]("Bijuu buff spell"))
  addWidget(bijuuWidgets, addTextEdit("bijuuBuff", tostring(storage["bijuuBuff"]), function(widget, text)
    storage["bijuuBuff"] = text:lower():trim()
  end))

  addWidget(bijuuWidgets, UI["Separator"]())

  macro(50, function()
    if (not storage["checkBoxs"]["useBijuu"]) then return end

    -- Fora do outfit da bijuu: nao faz nada (e zera o contador do Yaiba no NtoUltimate).
    if (tonumber(storage["bijuuOutfit"]) ~= player:getOutfit()["type"]) then
      if (shazamWorldName == "NtoUltimate" and storage["castedYaiba"] ~= nil) then
        storage["castedYaiba"] = nil
      end
      return
    end

    if (shazamWorldName == "NtoUltimate") then
      -- Enquanto na bijuu, segura as magias do Buffs para elas nao recastarem por cima.
      local especiais = storage["especiaisConfig"]
      local buffsConfig = type(especiais) == "table" and type(especiais["spells"]) == "table" and especiais["spells"]["Buffs"]
      if (type(buffsConfig) == "table") then
        for _, entry in pairs(buffsConfig) do
          if (type(entry) == "table") then entry["cooldownTime"] = os["time"]() + 1 end
        end
      end

      if ((storage["castedYaiba"] or 0) >= 2) then return end
    end

    if (storage["bijuuBuffExhaust"] and storage["bijuuBuffExhaust"] >= os["time"]()) then return end
    if (isInPz()) then return end

    if canShazamMacroAct("bijuuBuff", 50) then say(storage["bijuuBuff"]) end
  end)

  onTalk(function(name, level, mode, text)
    if (name ~= player:getName()) then return end
    if (mode ~= 44) then return end

    if (normalizeText(text) == normalizeText(storage["bijuuBuff"])) then
      storage["bijuuBuffExhaust"] = os["time"]() + 15
      storage["castedYaiba"] = (storage["castedYaiba"] or 0) + 1
    end
  end)
end

-- ----------------------------------------------------------------------------
-- USAR PILL
-- ----------------------------------------------------------------------------
do
  local pillConfig = {
    baseId = 11821,
    contents = {},
    triedToUse = nil,
  }
  local pillWidgets = {}

  local pillCheckBox = addCheckBoxLocal("usePill", "Usar Pill", function(widget, checked)
    setWidgetsVisible(pillWidgets, checked == true)
  end)

  registerToggle("usarPill", pillCheckBox)

  storage["pillId"] = storage["pillId"] or pillConfig["baseId"]
  storage["pillContent"] = storage["pillContent"] or "Nhack Nhack"
  storage["pillDelay"] = storage["pillDelay"] or 0

  addWidget(pillWidgets, UI["Label"]("Pill Id"))
  addWidget(pillWidgets, addTextEdit("pillId", tostring(storage["pillId"]), function(widget, text)
    local ID = tonumber(text)
    if (not ID) then
      return shazamNotify("Insira um id valido")
    end
    storage["pillId"] = ID
  end))

  -- Textos que o servidor fala quando a pill e usada (separados por virgula).
  local refactorContents = function()
    pillConfig["contents"] = tostring(storage["pillContent"]):split(",")
    for index, value in pairs(pillConfig["contents"]) do
      pillConfig["contents"][index] = value:lower():trim()
    end
  end
  refactorContents()

  addWidget(pillWidgets, UI["Label"]("Pill Text"))
  addWidget(pillWidgets, addTextEdit("pillContent", tostring(storage["pillContent"]), function(widget, text)
    widget:setTooltip("Se tiver mais de um texto, separe por virgula. ex: 'Nhack Nhack, Crock Crock!'")
    storage["pillContent"] = text
    refactorContents()
  end))

  addWidget(pillWidgets, UI["Separator"]())

  macro(50, function()
    if (not storage["checkBoxs"]["usePill"]) then return end

    local target = g_game["getAttackingCreature"]()
    if (not target) then return end
    if (not target:isPlayer()) then return end

    local pillId = tonumber(storage["pillId"]) or pillConfig["baseId"]

    -- Nao usa a pill enquanto o Auto Kai estiver em exaustao.
    local kaiExhaust = storage["autoKaiConfig"]
    kaiExhaust = kaiExhaust and kaiExhaust["kaiExhaust"]
    if (not kaiExhaust or kaiExhaust < os["time"]()) then
      if (storage["pillDelay"] < os["time"]()) then
        if (pillConfig["triedToUse"]) then
          useWith(pillId, player)
          pillConfig["triedToUse"] = false
        else
          use(pillId)
          pillConfig["triedToUse"] = true
        end
        delay(500)
        return
      end
      pillConfig["triedToUse"] = nil
    end
  end)

  -- Quando o servidor confirma a pill (fala do proprio personagem), espera 60s.
  onTalk(function(name, level, mode, text)
    if (mode ~= 44) then return end
    if (name ~= player:getName()) then return end

    if (not table["find"](pillConfig["contents"], text:trim(), true)) then return end
    storage["pillDelay"] = os["time"]() + 60
  end)
end

-- ----------------------------------------------------------------------------
-- MARCAR CRIATURAS
-- Intercepta os opcodes 134/147 do servidor e marca de vermelho a criatura por 2s.
-- O hook no ProtocolGame e registrado no ShazamGuard: ao recarregar a Shazam ou
-- abrir outra custom ele e desfeito (nao fica pendurado quebrando as outras).
-- ----------------------------------------------------------------------------
do
  registerToggle("marcarCriaturas", addCheckBoxLocal("markAttacking", "Marcar criaturas"))
  UI["Separator"]()

  local realG = modules["_G"]
  local g_map = realG["g_map"]
  local g_clock = realG["g_clock"]
  local gameRef = realG["g_game"]
  local protocol = realG["ProtocolGame"]
  local scheduleEvent = realG["scheduleEvent"]

  local setCreatureMarked = function(creature, color)
    if (not storage["checkBoxs"]["markAttacking"]) then return end
    if (not (creature ~= nil and creature:isMonster())) then return end

    creature:setMarked(color or "red")

    local time = g_clock["millis"]()
    creature["markTime"] = time
    scheduleEvent(function()
      if (creature["markTime"] == time) then
        creature:setMarked("")
      end
    end, 2000)
  end

  local opcodeCallbacks = {}

  opcodeCallbacks[134] = function(msg)
    local id = msg:getU32()
    local color = msg:getU8()

    local creature = g_map["getCreatureById"](id)
    if (color == 0) then
      setCreatureMarked(creature)
    end
  end

  opcodeCallbacks[147] = function(msg)
    local len
    if (gameRef["getProtocolVersion"]() >= 1035) then
      len = 1
    else
      len = msg:getU8()
    end

    for i = 1, len do
      local id = msg:getU32()
      local isPermanent = msg:getU8() ~= 1
      local color = msg:getU8()
      local creature = g_map["getCreatureById"](id)
      if (isPermanent) then
        if (color == 0xff) then
          setCreatureMarked(creature, "")
        elseif (color == 0) then
          setCreatureMarked(creature)
        end
      elseif (color == 0) then
        setCreatureMarked(creature)
      end
    end
  end

  if (protocol) then
    -- Tudo que o hook usa e capturado aqui (ele pode rodar depois de um reload do bot).
    local pcallRef, typeRef, printRef, tostringRef = pcall, type, print, tostring
    local guardRef = ShazamGuard
    local reportedError = false

    -- Funcao ORIGINAL do client (nunca o hook de outra custom).
    local originalOnOpcode = realG["__ShazamOpcodeOriginal"] or realG["oldOpcode"] or protocol["onOpcode"]
    realG["__ShazamOpcodeOriginal"] = originalOnOpcode

    local opcodeHook
    opcodeHook = function(self, opcode, msg, ...)
      local callback = opcodeCallbacks[opcode]
      if (callback and guardRef and guardRef.check()) then
        local ok, err = pcallRef(callback, msg)
        if (not ok and not reportedError) then
          reportedError = true
          printRef("[Shazam] Marcar criaturas: " .. tostringRef(err))
        end
      end
      if (typeRef(originalOnOpcode) == "function") then
        return originalOnOpcode(self, opcode, msg, ...)
      end
    end

    protocol["onOpcode"] = opcodeHook

    ShazamGuard.onCleanup(function()
      if (protocol["onOpcode"] == opcodeHook) then
        protocol["onOpcode"] = originalOnOpcode
      end
      if (realG["__ShazamOpcodeOriginal"] == originalOnOpcode) then
        realG["__ShazamOpcodeOriginal"] = nil
      end
    end)
  end
end


local speedDelay = 0
local maxSpeed
-- Haste e Regeneration agora possuem OFF real. Quando ambos estao desligados,
-- este ciclo retorna antes de consultar speed/haste/paralyze/HP.
macro(200, function()
    local autoHaste = storage["checkBoxs"]["autoHaste"] == true
    local autoRegen = storage["checkBoxs"]["autoRegen"] == true
    local antiLyze = storage["checkBoxs"]["antiLyze"] == true
    if not autoHaste and not autoRegen and not antiLyze then return end

    if autoHaste or antiLyze then
        local playerSpeed = player:getSpeed()
        local hasted = hasHaste()
        local paralyzed = isParalyzed()
        if hasted and (maxSpeed == nil or maxSpeed < playerSpeed) then maxSpeed = playerSpeed end
        local cast_haste = false
        if autoHaste and speedDelay < now and (not maxSpeed or playerSpeed < (maxSpeed - 10)) then
            if not paralyzed and not hasted then
                speedDelay = now + 500
                cast_haste = true
            end
        end
        if antiLyze and paralyzed then cast_haste = true end
        if cast_haste and canShazamMacroAct("haste", 100) then say(storage["hasteSpell"]) end
    end

    if not autoRegen then return end
    local regenPercent = storage["scrollBars"]["regenPercent"] or 100
    if player:getHealthPercent() < regenPercent then
        local bijuuOutfit = tonumber(storage["bijuuOutfit"])
        if storage["bijuuRegen"] and storage["checkBoxs"]["useBijuu"] and bijuuOutfit and player:getOutfit()["type"] == bijuuOutfit then
            if canShazamMacroAct("regen", 100) then say(storage["bijuuRegen"]) end
        else
            if canShazamMacroAct("regen", 100) then
                for _, spell in ipairs(regenerationSpells) do say(spell, -1) end
            end
        end
    end
end)

	UI["Label"]("Sense Spell");
	UI["TextEdit"](tk.storage["_sense_spell"] or "Sense", function(widget, text)
		tk.storage["_sense_spell"] = text;
	end)

-- ============================================================================
-- REINICIAR CUSTOM (portado da aba User do sistema anterior)
-- Reinicia o client para recarregar a custom local.
-- ============================================================================
if (not UI["ConfirmationWindow"]) then
  UI["ConfirmationWindow"] = function(title, question, callback)
    local window
    local closeWindow = function()
      window:destroy()
    end
    local onConfirm = function()
      closeWindow()
      callback()
    end
    window = displayGeneralBox(title, question, {
      {text = tr("Yes"), callback = onConfirm},
      {text = tr("No"), callback = closeWindow},
      anchor = (AnchorHorizontalCenter or 6)}, onConfirm, closeWindow)
    window["botWidget"] = true
    return window
  end
end

UI["Button"]("Reiniciar Custom", function()
  UI["ConfirmationWindow"]("Reiniciar Custom", "Deseja reiniciar o client para recarregar a custom local?", function()
    local app = (modules["corelib"] and modules["corelib"]["g_app"]) or modules["_G"]["g_app"]
    app["restart"]()
  end)
end)

-- ============================================================================
-- ATALHOS (portado da aba User do sistema anterior)
-- Janela "Atalho" que lista as macros registradas em _G.configData (Bug Map,
-- Combo, Enemy...). Para cada uma voce pode:
--   * trocar as teclas (quando a macro tem tecla de acao / teclas extras);
--   * marcar "Utilizar icon" e escolher o item do icone: cria um icone na tela
--     que liga/desliga a macro (arraste com CTRL apertado para mudar de lugar).
-- As escolhas ficam salvas em storage["config"].
-- ============================================================================
do
  local globalEnv = (type(_G) == "table") and _G or modules["_G"]
  globalEnv.configData = globalEnv.configData or {}
  local configData = globalEnv.configData

  if (storage["config"] == nil) then
    storage["config"] = {}
  end

  local data = {}

  -- Somente estas macros (as da aba Main) aparecem no Atalhos.
  -- Qualquer outra coisa registrada em configData (Heal Paralyze, Kunai, Pill,
  -- Macros PT, Travel, CaveBot, TargetBot...) fica de fora.
  local allowedShortcuts = {
    combo = true,
    buffs = true,
    fugas = true,
    especiais = true,
    attackTarget = true,
    followTarget = true,
    potion = true,
    antiTrap = true,
    autoEscadas = true,
    jump = true,
    sense = true,
    enemy = true,
    bugMap = true,
  }

  local mainWindow = setupUI([[
MainWindow
  size: 220 380
  !text: tr("Atalho")
  color: white

  BotPanel
    id: mainPanel
    anchors.top: parent.top
    anchors.bottom: parent.bottom
    anchors.left: parent.left
    anchors.right: parent.right
]], g_ui["getRootWidget"]())

  g_ui["loadUIFromString"]([[

UseItem < Panel
  height: 40

  UIWidget
    id: text
    margin-left: 35
    anchors.verticalCenter: parent.verticalCenter
    anchors.left: parent.left
    anchors.top: parent.top

  BotItem
    id: item
    anchors.left: parent.left
    anchors.top: parent.top
]])

  -- "bugMap" -> "Bug Map"
  local convertName = function(name)
    local newName = {}
    for index = 1, name:len() do
      local char = name:sub(index, index)
      if (index ~= 1 and char:upper() == char) then
        table["insert"](newName, " ")
      end
      table["insert"](newName, char)
    end
    return table["concat"](newName)
  end

  -- Copia o que esta salvo para a tabela que os modulos leem em tempo real.
  local updateData = function()
    for name, value in pairs(storage["config"]) do
      if (allowedShortcuts[name]) then
        configData[name] = value
      end
    end
  end

  -- A macro pode ser um objeto de macro (com .switch) ou o proprio switch.
  local resolveSwitch = function(macroRef)
    if (macroRef == nil) then return nil end
    local ok, switch = pcall(function() return macroRef["switch"] end)
    if (ok and switch ~= nil) then return switch end
    return macroRef
  end

  -- CaveBot e TargetBot nao tem um switch unico: usa as funcoes proprias deles.
  local registerBot = function(key, bot)
    if (type(bot) ~= "table" or type(bot["isOn"]) ~= "function") then return end
    if (configData[key] ~= nil) then return end
    configData[key] = {
      macro = {
        isOn = function(self) return bot["isOn"]() == true end,
        onClick = function(self)
          if (bot["isOn"]()) then bot["setOff"]() else bot["setOn"]() end
        end,
      }
    }
  end

  local main = function()
    -- CaveBot/TargetBot agora tem icones proprios (Free Modules/Icon.lua).

    for name, values in pairs(configData) do
      if (allowedShortcuts[name] and type(values) == "table") then
        local value = {
          name = name
        }
        for key, val in pairs(values) do
          value[key] = val
        end
        table["insert"](data, value)
      end
    end

    table["sort"](data, function(a, b)
      return a["name"] < b["name"]
    end)

    updateData()

    -- Primeira vez de cada macro: grava a config padrao dela (sem a referencia da macro).
    for name, value in pairs(configData) do
      if (allowedShortcuts[name] and type(value) == "table" and storage["config"][name] == nil) then
        storage["config"][name] = {}
        for key, val in pairs(value) do
          if (key ~= "macro") then
            storage["config"][name][key] = val
          end
        end
      end
    end

    for _, value in ipairs(data) do
      local firstExec = true
      local current_data = storage["config"][value["name"]]
      if (current_data == nil) then
        current_data = {}
        storage["config"][value["name"]] = current_data
      end

      local name = convertName(value["name"])
      if (name["ucwords"] ~= nil) then
        name = name:ucwords()
      end

      local parent = mainWindow["mainPanel"]["content"]
      UI["Label"](name, parent)

      if (value["actionKey"] ~= nil) then
        UI["Label"]("Tecla de acao:", parent)
        UI["TextEdit"](current_data["actionKey"] or value["actionKey"], function(widget, text)
          current_data["actionKey"] = text
          updateData()
        end, parent)
      end

      if (value["extra"] ~= nil) then
        if (current_data["extra"] == nil) then
          current_data["extra"] = {}
        end
        local extra = {}
        for extraName, extraVal in pairs(value["extra"]) do
          table["insert"](extra, {
            name = extraName,
            val = extraVal
          })
        end

        table["sort"](extra, function(a, b)
          return a["name"] < b["name"]
        end)

        for _, extraEntry in ipairs(extra) do
          local extraLabel = convertName(extraEntry["name"])
          if (extraLabel["ucwords"] ~= nil) then
            extraLabel = extraLabel:ucwords()
          end

          UI["Label"](extraLabel .. ":", parent)

          local textEdit = UI["TextEdit"](current_data["extra"][extraEntry["name"]] or extraEntry["val"], function(widget, text)
            current_data["extra"][extraEntry["name"]] = text
            updateData()
          end, parent)

          textEdit:setMarginTop(5)
        end
      end

      local icon
      local itemEdit
      local checkBox = UI["createWidget"]("CheckBox", parent)
      checkBox["onCheckChange"] = function(widget, checked)
        if (firstExec) then return end
        if (icon) then
          icon:destroy()
          icon = nil
        end

        if (not checked) then
          itemEdit:hide()
        end

        if (checked) then
          local switch = resolveSwitch(value["macro"])
          if (switch == nil) then
            -- Essa macro nao expos o switch dela: nao da para criar icone.
            itemEdit:hide()
            current_data["activatedIcon"] = false
            updateData()
            return
          end

          itemEdit:show()
          icon = addIcon(name, {item = current_data["iconId"], text = name}, function(icon, isOn)
            if (firstExec) then return end
            if ((isOn and not switch:isOn()) or (not isOn and switch:isOn())) then
              switch:onClick()
            end
          end)
          -- Deixa o icone ja no estado atual da macro (sem disparar nada: so visual).
          pcall(function() icon["setOn"](switch:isOn()) end)

          local isMobile = (g_app or modules["_G"]["g_app"])["isMobile"]()
          icon["onDragEnter"] = function(widget, mousePos)
            if (
              isMobile and not modules["corelib"]["g_keyboard"]["isKeyPressed"]("F2") or
              not isMobile and not modules["corelib"]["g_keyboard"]["isCtrlPressed"]()
            ) then
              return false
            end
            widget:breakAnchors()
            widget["movingReference"] = {x = mousePos["x"] - widget:getX(), y = mousePos["y"] - widget:getY()}
            return true
          end

          if (switch["oldCallback"] == nil) then
            switch["oldCallback"] = switch["onClick"]
          end

          switch["onClick"] = function(widget)
            widget:oldCallback()
            if (icon ~= nil) then
              icon["setOn"](widget:isOn())
            end
          end
        end
        current_data["activatedIcon"] = checked
        updateData()
      end

      checkBox:setTooltip("Utilizar icon")

      if (current_data["iconId"] == nil) then
        current_data["iconId"] = math["random"](1, 100)
      end

      itemEdit = UI["createWidget"]("UseItem", parent)

      itemEdit["item"]["onItemChange"] = function(widget)
        local item = widget:getItem()
        if (item ~= nil) then
          current_data["iconId"] = item:getId()
          checkBox:onCheckChange(true)
          updateData()
        end
      end
      itemEdit["text"]:setText("Id do icon")

      firstExec = false
      checkBox:setChecked(current_data["activatedIcon"] == true)
      checkBox:onCheckChange(current_data["activatedIcon"] == true)
    end
  end

  UI["Button"](tr("Close"), function()
    mainWindow:hide()
  end, mainWindow["mainPanel"]["content"])

  UI["Button"]("Atalhos", function()
    mainWindow:show()
    mainWindow:raise()
    mainWindow:focus()
  end)

  -- Espera 100ms para todas as outras macros terem se registrado em configData.
  schedule(100, main)

  mainWindow:hide()
end
