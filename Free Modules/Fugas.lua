-- ============================================================================
-- SISTEMA AVANÇADO DE AUTO FUGA E CONTROLE DE VIDAS/DASH (Otimizado sem Lag)
-- Interface padronizada: Macro + Config na mesma linha, com borda vermelha.
-- ============================================================================

storage.fugaSpells = storage.fugaSpells or {}
storage.fugaSettings = storage.fugaSettings or { isOn = true, showInfo = true }
if storage.fugaSettings.showInfo == nil then storage.fugaSettings.showInfo = true end
if type(storage.fugaSettings.infoPos) ~= "table" then
    storage.fugaSettings.infoPos = {x = 10, y = 45}
end

local fugaSpellsWidgets = {}
local storageAttackers = {}
local timeClean = 3
local lastCastAttempt = 0

local izanagiReviveState = {
    pending = false,
    died = false,
    origin = nil,
    lastPos = nil,
}

local function persistFuga()
    if type(ShazamPersistNow) == "function" then
        ShazamPersistNow()
    elseif type(saveConfig) == "function" then
        saveConfig()
    end
end

local function firstLetterUpper(str)
    if not str then return "" end
    return (str:gsub("(%a)([%w_']*)", function(first, rest)
        return first:upper() .. rest:lower()
    end))
end

local function getCastPercent(value)
    local percent = tonumber(value)
    if not percent then
        return 100
    end
    return math.max(0, math.min(100, percent))
end

local function formatRemainingTime(timeEnd)
    local currentSec = os.time()
    if not timeEnd or timeEnd <= currentSec then return "Pronto!" end
    local remaining = timeEnd - currentSec
    if remaining > 3600 then return "Pronto!" end
    return string.format("%.0f", remaining) .. "s"
end

local function getAllKeys()
    local keys = {}
    for _, key in pairs(modules.corelib.KeyCodeDescs or {}) do
        if key ~= "Unknown" then table.insert(keys, key) end
    end
    table.sort(keys)
    table.insert(keys, 1, "AUTO")
    return keys
end

local widgetConfig = [[
Label
  background-color: alpha
  font: verdana-11px-rounded
  padding: 2 6
  focusable: false
  phantom: false
  draggable: true
  text-auto-resize: true
]]

local function attachSpellWidgetCallbacks(widget, entry)
    widget.onDragEnter = function(self, mousePos)
        if not modules.corelib.g_keyboard.isCtrlPressed() then return false end
        self:breakAnchors()
        self.movingReference = {x = mousePos.x - self:getX(), y = mousePos.y - self:getY()}
        self.isDragging = true
        return true
    end
    widget.onDragMove = function(self, mousePos, moved)
        local parentRect = self:getParent():getRect()
        local newX = math.min(math.max(parentRect.x, mousePos.x - self.movingReference.x), parentRect.x + parentRect.width - self:getWidth())
        local newY = math.min(math.max(parentRect.y - self:getParent():getMarginTop(), mousePos.y - self.movingReference.y), parentRect.y + parentRect.height - self:getHeight())
        self:move(newX, newY)
        entry.widgetPos = {x = newX, y = newY}
        self.isDragging = true
        return true
    end
    widget.onMouseRelease = function(self, mousePos, mouseButton)
        if self.isDragging then
            self.isDragging = false
            persistFuga()
            return true
        end
    end
end

local entryWidget = [[
Label
  height: 18
  focusable: true
  background-color: alpha

  $focus:
    background-color: #ffffff33

  CheckBox
    id: enabled
    anchors.left: parent.left
    anchors.verticalCenter: parent.verticalCenter
    width: 15
    height: 15

  CheckBox
    id: showTimespell
    anchors.left: enabled.right
    anchors.verticalCenter: parent.verticalCenter
    margin-left: 5
    width: 15
    height: 15

  Label
    id: textToSet
    anchors.left: showTimespell.right
    anchors.verticalCenter: parent.verticalCenter
    margin-left: 8

  Button
    id: remove
    text: x
    anchors.right: parent.right
    anchors.verticalCenter: parent.verticalCenter
    width: 15
    height: 15
]]

local fugaIcon = setupUI("Panel\n  height: 17\n\n  BotSwitch\n    id: title\n    anchors.top: parent.top\n    anchors.left: parent.left\n    text-align: center\n    width: 130\n    !text: tr(\"Fugas\")\n\n  Button\n    id: config\n    anchors.top: prev.top\n    anchors.bottom: prev.bottom\n    anchors.left: prev.right\n    anchors.right: parent.right\n    text: Config\n")

-- Monitor visual das Fugas, no mesmo padrao do "Save Positions" do Jump.
-- A preferencia fica salva, mas o texto na tela so aparece quando:
--   1) Fugas estiver ligada; e
--   2) Monitor de Fugas estiver marcado.
local fugaMonitorCheck = setupUI([[
CheckBox
  id: checkBox
  margin-right: 1
  margin-left: 1
  margin-top: 3
  font: cipsoftFont
  text: Monitor de Fugas

  $checked:
    color: white
]])



-- ============================================================================
-- INFORMAÇÕES DE FUGA
-- Visual inspirado no painel "Informações de Batalha" da JinWoo.
-- Aqui mostramos SOMENTE informações relacionadas às FUGAS.
-- ============================================================================
local fugaStatusWidget = setupUI([[
UIWidget
  background-color: black
  padding: 0 5
  text-auto-resize: true
  text: Fuga: aguardando...
  text-align: center
]], g_ui.getRootWidget())

local function getAttackerCount()
    local count = 0
    local currentSec = os.time()
    for _, expire in pairs(storageAttackers) do
        if expire and expire >= currentSec then
            count = count + 1
        end
    end
    return math.min(count, 6)
end

local function getConfiguredFugaPercent()
    local bestPercent = nil

    for _, entry in ipairs(storage.fugaSpells or {}) do
        if entry and entry.enabled then
            local percent = tonumber(entry.selfHealth) or 0
            if percent > 0 then
                -- Igual ao sistema da JinWoo: percentual efetivo,
                -- incluindo +5% por atacante (ate 6 atacantes).
                local effective = percent
                if percent == 100 then effective = 45 end
                effective = math.min(effective + (getAttackerCount() * 5), 100)
                if not bestPercent or effective < bestPercent then
                    bestPercent = effective
                end
            end
        end
    end

    return bestPercent
end

local function hasActiveFuga()
    local now = os.time()
    for _, entry in ipairs(storage.fugaSpells or {}) do
        if entry and entry.enabled and (tonumber(entry.activeTime) or 0) >= now then
            return true
        end
    end
    return false
end

local function updateFugaStatusWidget()
    if not fugaStatusWidget then return end

    if not storage.fugaSettings.isOn or storage.fugaSettings.showInfo == false then
        fugaStatusWidget:hide()
        return
    end

    local attackers = getAttackerCount()
    local status
    local color = attackers > 0 and "red" or "white"

    if hasActiveFuga() then
        status = string.format("Oponentes: %d | Fuga ativa!", attackers)
        color = "#00FFFF"
    else
        local percent = getConfiguredFugaPercent()
        if percent then
            status = string.format("Oponentes: %d | Fuga em %d%%", attackers, math.floor(percent + 0.5))
        elseif #(storage.fugaSpells or {}) == 0 then
            status = string.format("Oponentes: %d | Fuga: nenhuma configurada", attackers)
        else
            status = string.format("Oponentes: %d | Fuga: pronta", attackers)
        end
    end

    fugaStatusWidget:setText(status)
    fugaStatusWidget:setColor(color)
    fugaStatusWidget:show()
end

-- Permite mover somente segurando CTRL + botao esquerdo do mouse.
-- A posicao e salva em storage para permanecer apos reiniciar o bot.
fugaStatusWidget:setDraggable(true)
fugaStatusWidget:setFocusable(true)
fugaStatusWidget:setPosition(storage.fugaSettings.infoPos or {x = 10, y = 45})

fugaStatusWidget.onDragEnter = function(self, mousePos)
    if not modules.corelib.g_keyboard.isCtrlPressed() then
        return false
    end

    self:breakAnchors()
    self.movingReference = {
        x = mousePos.x - self:getX(),
        y = mousePos.y - self:getY()
    }
    self.isDragging = true
    return true
end

fugaStatusWidget.onDragMove = function(self, mousePos, moved)
    if not self.isDragging or not modules.corelib.g_keyboard.isCtrlPressed() then
        return false
    end

    local parent = self:getParent()
    local parentRect = parent:getRect()
    local newX = math.min(
        math.max(parentRect.x, mousePos.x - self.movingReference.x),
        parentRect.x + parentRect.width - self:getWidth()
    )
    local newY = math.min(
        math.max(parentRect.y - parent:getMarginTop(), mousePos.y - self.movingReference.y),
        parentRect.y + parentRect.height - self:getHeight()
    )

    self:move(newX, newY)
    storage.fugaSettings.infoPos = {x = newX, y = newY}
    return true
end

fugaStatusWidget.onMouseRelease = function(self, mousePos, mouseButton)
    if self.isDragging then
        self.isDragging = false
        persistFuga()
        return true
    end
end

local fugaInterface = setupUI([[
MainWindow
  text: Fugas by JinWoo Scripts
  size: 510 350

  Panel
    id: mainPanel
    image-source: /images/ui/panel_flat
    anchors.top: parent.top
    anchors.bottom: parent.bottom
    anchors.left: parent.left
    anchors.right: parent.right
    image-border: 6

  TextList
    id: spellList
    anchors.left: parent.left
    anchors.top: parent.top
    padding: 1
    width: 170
    anchors.bottom: moveUp.top
    margin-bottom: 5
    vertical-scrollbar: spellListScrollBar

  VerticalScrollBar
    id: spellListScrollBar
    anchors.top: spellList.top
    anchors.bottom: spellList.bottom
    anchors.left: spellList.right
    step: 14
    pixels-scroll: true

  Button
    id: moveUp
    anchors.bottom: parent.bottom
    anchors.left: parent.left
    text: Move Up
    width: 80

  Button
    id: moveDown
    anchors.bottom: parent.bottom
    anchors.left: moveUp.right
    margin-left: 10
    text: Move Down
    width: 80

  VerticalSeparator
    id: sep2
    anchors.top: parent.top
    anchors.bottom: parent.bottom
    anchors.left: spellListScrollBar.right
    margin-left: 10

  Label
    id: castSpellLabel
    anchors.left: sep2.right
    anchors.top: parent.top
    text: Cast Spell:
    margin-left: 10
    margin-top: 5

  TextEdit
    id: castSpell
    anchors.left: castSpellLabel.right
    anchors.right: parent.right
    anchors.verticalCenter: castSpellLabel.verticalCenter
    margin-left: 5

  Label
    id: orangeSpellLabel
    anchors.left: sep2.right
    anchors.top: castSpell.bottom
    text: Msg Laranja:
    margin-left: 10
    margin-top: 15

  TextEdit
    id: orangeSpell
    anchors.left: orangeSpellLabel.right
    anchors.right: sameSpell.left
    anchors.verticalCenter: orangeSpellLabel.verticalCenter
    margin-left: 5
    margin-right: 5

  CheckBox
    id: sameSpell
    anchors.right: parent.right
    anchors.verticalCenter: orangeSpellLabel.verticalCenter
    text: = Cast?
    width: 60

  Label
    id: onScreenLabel
    anchors.left: sep2.right
    anchors.top: orangeSpell.bottom
    text: Nome Tela:
    margin-left: 10
    margin-top: 15

  TextEdit
    id: onScreen
    anchors.left: onScreenLabel.right
    anchors.right: parent.right
    anchors.verticalCenter: onScreenLabel.verticalCenter
    margin-left: 5

  Label
    id: hotkeyLabel
    anchors.left: sep2.right
    anchors.top: onScreen.bottom
    text: Hotkey Manual:
    margin-left: 10
    margin-top: 15

  ComboBox
    id: hotkeyList
    anchors.left: hotkeyLabel.right
    anchors.right: parent.right
    anchors.verticalCenter: hotkeyLabel.verticalCenter
    margin-left: 5

  Label
    id: hppercentLabel
    anchors.left: sep2.right
    anchors.top: hotkeyLabel.bottom
    text: HP Percent:
    margin-left: 10
    margin-top: 15

  Panel
    id: hppercent
    anchors.left: hppercentLabel.right
    anchors.right: parent.right
    anchors.verticalCenter: hppercentLabel.verticalCenter
    margin-left: 5
    height: 22

  Label
    id: cooldownTotalLabel
    anchors.left: sep2.right
    anchors.top: hppercent.bottom
    text: CD Total:
    margin-left: 10
    margin-top: 15

  Panel
    id: cooldownTotal
    anchors.left: cooldownTotalLabel.right
    anchors.right: parent.right
    anchors.verticalCenter: cooldownTotalLabel.verticalCenter
    margin-left: 15
    height: 22

  Label
    id: cooldownActiveLabel
    anchors.left: sep2.right
    anchors.top: cooldownTotal.bottom
    text: CD Ativo:
    margin-left: 10
    margin-top: 15

  Panel
    id: cooldownActive
    anchors.left: cooldownActiveLabel.right
    anchors.right: parent.right
    anchors.verticalCenter: cooldownActiveLabel.verticalCenter
    margin-left: 14
    height: 22

  Panel
    id: optionsPanel
    anchors.left: sep2.right
    anchors.right: parent.right
    anchors.top: cooldownActive.bottom
    margin-top: 15
    margin-left: 10
    height: 20
    layout:
      type: horizontalBox
      spacing: 8

    CheckBox
      id: reviveOption
      text: Revive
      tooltip: Reseta o estado ativo caso retorne em coordenadas de ressurreicao.

    CheckBox
      id: lifesOption
      text: Vidas
      tooltip: Habilita cargas de sobrevivencia regressivas (Ex: Kakuzu/Danzou).

    CheckBox
      id: multipleOption
      text: Multi
      tooltip: Habilita cargas de uso consecutivo (Ex: Dash do Raikage 2x).

    SpinBox
      id: configValue
      width: 40
      minimum: 1
      maximum: 10
      step: 1
      editable: true

  CheckBox
    id: showInfo
    text: Informações de Batalha
    anchors.left: sep2.right
    anchors.bottom: insertSpell.top
    margin-left: 10
    margin-bottom: 5

  Button
    id: insertSpell
    text: Insert Spell
    anchors.right: parent.right
    anchors.bottom: parent.bottom
    width: 80

  Button
    id: closeButton
    text: Close
    anchors.right: insertSpell.left
    anchors.bottom: parent.bottom
    margin-right: 5
    width: 60
]], g_ui.getRootWidget())

-- ============================================================================
-- INTERFACE PRINCIPAL NO PADRAO DO "ESPECIAIS" (JinWoo)
-- A tela de cadastro detalhado abaixo continua existindo para manter as
-- melhorias exclusivas do Fugas.lua (Vidas, Multi, Revive/Izanagi etc.).
-- ============================================================================
local fugaMainScreen = setupUI([[
MainWindow
  size: 320 360
  text: Fugas by JinWoo Scripts
  color: white

  Panel
    id: mainPanel
    image-source: /images/ui/panel_flat
    anchors.top: parent.top
    anchors.bottom: parent.bottom
    anchors.left: parent.left
    anchors.right: parent.right
    image-border: 6

    TextList
      id: spellsList
      image-source: /images/ui/textedit
      anchors.centerIn: parent
      anchors.left: parent.left
      anchors.right: parent.right
      margin-top: 20
      margin-left: 10
      margin-right: 10
      image-border: 6
      height: 180
      vertical-scrollbar: spellsListScroll

    VerticalScrollBar
      id: spellsListScroll
      anchors.top: spellsList.top
      anchors.bottom: spellsList.bottom
      anchors.right: spellsList.right
      step: 10
      pixels-scroll: true

    TextEdit
      id: nameField
      tooltip: Nome da Magia
      anchors.bottom: spellsList.top
      anchors.left: parent.left
      margin-bottom: 5
      margin-left: 10
      width: 185

    Label
      text: Nome da Magia
      anchors.bottom: prev.top
      anchors.left: prev.left
      margin-left: 50
      margin-bottom: 2

    ComboBox
      id: typeList
      anchors.top: parent.top
      anchors.left: spellsList.left
      anchors.right: spellsList.right
      text-offset: 3 0
      margin-top: 5

    Button
      id: addButton
      text: Adicionar
      anchors.top: nameField.top
      anchors.bottom: nameField.bottom
      anchors.left: nameField.right
      anchors.right: spellsList.right
      margin-left: 5

    Label
      id: message
      anchors.top: spellsList.bottom
      anchors.right: parent.right
      anchors.left: parent.left
      margin-top: 2
      text-auto-resize: true
      text-align: center
      text-wrap: true

    CheckBox
      id: showInfo
      text: Informacoes de batalha
      anchors.left: spellsList.left
      anchors.bottom: closeButton.top
      margin-bottom: 8

    Button
      id: closeButton
      text: Fechar
      anchors.bottom: parent.bottom
      anchors.right: spellsList.right
      anchors.left: spellsList.left
      margin-bottom: 1
]], g_ui.getRootWidget())

fugaMainScreen:hide()
fugaMainScreen.mainPanel.typeList:addOption("Fugas")
fugaMainScreen.mainPanel.typeList:setCurrentOption("Fugas")

local FUGA_MAIN_ENTRY = [[
Label
  background-color: alpha
  text-offset: 37 4
  focusable: true
  height: 16
  font: verdana-11px-rounded

  CheckBox
    id: enabled
    tooltip: Ativar
    anchors.left: parent.left
    anchors.verticalCenter: parent.verticalCenter
    width: 15
    height: 15
    margin-top: 2
    margin-left: 3

  CheckBox
    id: spellTime
    tooltip: Ativar Time Spell
    anchors.left: prev.right
    anchors.verticalCenter: prev.verticalCenter
    width: 15
    height: 15
    margin-left: 3

  $focus:
    background-color: #00000055

  Button
    id: remove
    text: x
    anchors.right: parent.right
    margin-right: 15
    text-offset: 1 0
    width: 15
    height: 15
    tooltip: Remover magia da lista
]]

local refreshFugaMainList

-- ============================================================
--  STEPPER  ( -  [valor]  +  )  -- substitui a barra com setas < >
--  Mesmo estilo dos botoes do Auto Treino. Mantem a API:
--  getValue() / setValue(v) / onValueChange(widget, valor)
-- ============================================================
local STEPPER_UI = [[
Panel
  height: 22

  Button
    id: minus
    anchors.top: parent.top
    anchors.left: parent.left
    width: 28
    height: 22
    text: <

  TextEdit
    id: edit
    anchors.top: parent.top
    anchors.left: minus.right
    margin-left: 4
    width: 60
    height: 22
    text-align: center

  Button
    id: plus
    anchors.top: parent.top
    anchors.left: edit.right
    margin-left: 4
    width: 28
    height: 22
    text: >

  Label
    id: unit
    anchors.verticalCenter: parent.verticalCenter
    anchors.left: plus.right
    margin-left: 6
]]

local function createStepper(parent, minV, maxV, startValue, unit)
    local w = setupUI(STEPPER_UI, parent)
    w.isStepper = true
    w.minV = minV
    w.maxV = maxV
    w.value = minV
    w.busy = false
    w.unit:setText(unit or "")

    w.getValue = function(self) return self.value end

    w.setValue = function(self, v)
        v = math.floor(tonumber(v) or self.minV)
        v = math.max(self.minV, math.min(self.maxV, v))
        self.value = v
        self.busy = true
        self.edit:setText(tostring(v))
        self.busy = false
        if self.onValueChange then self.onValueChange(self, v) end
    end

    w.minus.onClick = function() w:setValue(w.value - 1) end
    w.plus.onClick = function() w:setValue(w.value + 1) end

    -- tambem da para digitar o valor direto
    w.edit.onTextChange = function(widget, text)
        if w.busy then return end
        local n = tonumber(text)
        if not n then return end
        if n < w.minV or n > w.maxV then
            w:setValue(n)
        else
            w.value = math.floor(n)
            if w.onValueChange then w.onValueChange(w, w.value) end
        end
    end

    w:setValue(startValue or minV)
    return w
end

-- (estas constantes nao existiam neste arquivo: addAnchor recebia nil, dava erro
-- e os campos HP Percent / CD Total / CD Ativo sumiam)
local AnchorTop, AnchorBottom, AnchorLeft, AnchorRight = 1, 2, 3, 4

local function fugaStepper(placeholder, minV, maxV, unit)
    local st = createStepper(placeholder, minV, maxV, 0, unit)
    st:addAnchor(AnchorLeft, "parent", AnchorLeft)
    st:addAnchor(AnchorRight, "parent", AnchorRight)
    st:addAnchor(AnchorTop, "parent", AnchorTop)
    return st
end
local fugaHp = fugaStepper(fugaInterface.hppercent, 0, 100, "%")
local fugaCdTotal = fugaStepper(fugaInterface.cooldownTotal, 0, 180, "s")
local fugaCdActive = fugaStepper(fugaInterface.cooldownActive, 0, 180, "s")


for _, k in ipairs(getAllKeys()) do fugaInterface.hotkeyList:addOption(k) end

local refreshFugaList

local function reindexTable(t)
    for i, e in ipairs(t) do e.index = i end
end

refreshFugaList = function()
    for _, child in pairs(fugaInterface.spellList:getChildren()) do child:destroy() end
    for _, widget in pairs(fugaSpellsWidgets) do widget:destroy() end
    fugaSpellsWidgets = {}

    for index, entry in ipairs(storage.fugaSpells) do
        local label = setupUI(entryWidget, fugaInterface.spellList)
        local newWidget = setupUI(widgetConfig, g_ui.getRootWidget())
        newWidget:setText(firstLetterUpper(entry.onScreen) .. ": Pronto!")
        attachSpellWidgetCallbacks(newWidget, entry)
        if not entry.widgetPos then entry.widgetPos = {x = 50, y = 50} end
        if storage.fugaSettings.isOn and entry.enableTimeSpell then newWidget:show() else newWidget:hide() end
        newWidget:setPosition(entry.widgetPos)
        fugaSpellsWidgets[entry.spellCast] = newWidget

        label.onDoubleClick = function()
            fugaInterface.castSpell:setText(entry.spellCast)
            fugaInterface.orangeSpell:setText(entry.orangeSpell)
            fugaInterface.onScreen:setText(entry.onScreen)
            fugaHp:setValue(entry.selfHealth)
            fugaCdTotal:setValue(entry.rawCooldownTotal or 0)
            fugaCdActive:setValue(entry.rawCooldownActive or 0)
            if entry.keyPress then fugaInterface.hotkeyList:setCurrentOption(entry.keyPress) end
            fugaInterface.optionsPanel.lifesOption:setChecked(entry.enableLifes == true)
            fugaInterface.optionsPanel.multipleOption:setChecked(entry.enableMultiple == true)
            fugaInterface.optionsPanel.reviveOption:setChecked(entry.enableRevive == true)
            if entry.enableLifes then
                fugaInterface.optionsPanel.configValue:show()
                fugaInterface.optionsPanel.configValue:setValue(entry.amountLifes or 4)
            elseif entry.enableMultiple then
                fugaInterface.optionsPanel.configValue:show()
                fugaInterface.optionsPanel.configValue:setValue(entry.amountUses or 2)
            end
            table.remove(storage.fugaSpells, index)
            reindexTable(storage.fugaSpells)
            refreshFugaList()
            persistFuga()
        end

        label.enabled:setChecked(entry.enabled)
        label.enabled.onClick = function()
            entry.enabled = not entry.enabled
            label.enabled:setChecked(entry.enabled)
            persistFuga()
        end

        label.showTimespell:setChecked(entry.enableTimeSpell)
        label.showTimespell.onClick = function()
            entry.enableTimeSpell = not entry.enableTimeSpell
            label.showTimespell:setChecked(entry.enableTimeSpell)
            if storage.fugaSettings.isOn and entry.enableTimeSpell then newWidget:show() else newWidget:hide() end
            persistFuga()
        end

        label.remove.onClick = function()
            table.remove(storage.fugaSpells, index)
            reindexTable(storage.fugaSpells)
            refreshFugaList()
            persistFuga()
        end

        local keyText = (entry.keyPress and entry.keyPress ~= "AUTO") and (" [" .. entry.keyPress .. "]") or ""
        label.textToSet:setText(firstLetterUpper(entry.spellCast) .. " | " .. entry.selfHealth .. "%" .. keyText)
    end
end

fugaInterface:hide()
fugaIcon.title:setOn(storage.fugaSettings.isOn)

fugaIcon.title.onClick = function(w)
    storage.fugaSettings.isOn = not storage.fugaSettings.isOn
    w:setOn(storage.fugaSettings.isOn)

    -- O cooldown/activeTime continua salvo e sendo atualizado pelos callbacks,
    -- mas nenhum TimeSpell fica visível enquanto a macro Fugas estiver desligada.
    for _, entry in ipairs(storage.fugaSpells or {}) do
        local spellWidget = fugaSpellsWidgets[entry.spellCast]
        if spellWidget then
            if storage.fugaSettings.isOn and entry.enableTimeSpell then
                spellWidget:show()
            else
                spellWidget:hide()
            end
        end
    end

    -- Atualiza imediatamente o texto flutuante. Assim, ao desligar Fugas,
    -- ele some na mesma hora mesmo que "Monitor de Fugas" continue marcado.
    updateFugaStatusWidget()
    persistFuga()
end

fugaIcon.config.onClick = function()
    if fugaMainScreen:isVisible() then
        fugaMainScreen:hide()
    else
        if refreshFugaMainList then refreshFugaMainList() end
        fugaMainScreen:show()
        fugaMainScreen:raise()
        fugaMainScreen:focus()
    end
end

fugaIcon.onMouseRelease = function(self, mousePos, mouseButton)
    if mouseButton == 2 then
        if refreshFugaMainList then refreshFugaMainList() end
        fugaMainScreen:show()
        fugaMainScreen:raise()
        fugaMainScreen:focus()
    end
end

fugaInterface.closeButton.onClick = function() fugaInterface:hide() end

-- Checkbox principal do monitor (fora do Config), igual ao Save Positions do Jump.
fugaMonitorCheck:setChecked(storage.fugaSettings.showInfo ~= false)
fugaMonitorCheck.onCheckChange = function(_, checked)
    storage.fugaSettings.showInfo = checked
    -- Mantem os controles antigos sincronizados, embora fiquem ocultos.
    if fugaInterface and fugaInterface.showInfo then fugaInterface.showInfo:setChecked(checked) end
    if fugaMainScreen and fugaMainScreen.mainPanel and fugaMainScreen.mainPanel.showInfo then
        fugaMainScreen.mainPanel.showInfo:setChecked(checked)
    end
    persistFuga()
    updateFugaStatusWidget()
end

fugaInterface.showInfo:setChecked(storage.fugaSettings.showInfo ~= false)
fugaInterface.showInfo.onCheckChange = function(_, checked)
    storage.fugaSettings.showInfo = checked
    persistFuga()
    updateFugaStatusWidget()
end

fugaInterface.sameSpell:setChecked(true)
fugaInterface.orangeSpell:setEnabled(false)
fugaInterface.sameSpell.onCheckChange = function(w, checked)
    if checked then
        fugaInterface.orangeSpell:setEnabled(false)
    else
        fugaInterface.orangeSpell:setEnabled(true)
        fugaInterface.orangeSpell:setText(fugaInterface.castSpell:getText())
    end
end

fugaInterface.optionsPanel.configValue:hide()
fugaInterface.optionsPanel.lifesOption.onCheckChange = function(_, checked)
    if checked then
        fugaInterface.optionsPanel.multipleOption:setChecked(false)
        fugaInterface.optionsPanel.configValue:show()
    elseif not fugaInterface.optionsPanel.multipleOption:isChecked() then
        fugaInterface.optionsPanel.configValue:hide()
    end
end

fugaInterface.optionsPanel.multipleOption.onCheckChange = function(_, checked)
    if checked then
        fugaInterface.optionsPanel.lifesOption:setChecked(false)
        fugaInterface.optionsPanel.configValue:show()
    elseif not fugaInterface.optionsPanel.lifesOption:isChecked() then
        fugaInterface.optionsPanel.configValue:hide()
    end
end

fugaInterface.insertSpell.onClick = function()
    local spellName = fugaInterface.castSpell:getText():trim():lower()
    local orangeMsg = fugaInterface.orangeSpell:getText():trim():lower()
    if fugaInterface.sameSpell:isChecked() then orangeMsg = spellName end
    local onScreen = fugaInterface.onScreen:getText():trim()
    local hp = fugaHp:getValue()
    local cdTotal = fugaCdTotal:getValue()
    local cdActive = fugaCdActive:getValue()
    local selectedKey = fugaInterface.hotkeyList:getCurrentOption().text
    if spellName:len() == 0 or onScreen:len() == 0 or hp == 0 or cdTotal == 0 then return end

    local spellConfig = {
        spellCast = spellName,
        orangeSpell = orangeMsg,
        onScreen = onScreen,
        selfHealth = hp,
        rawCooldownActive = cdActive,
        rawCooldownTotal = cdTotal,
        keyPress = selectedKey,
        cooldownTime = 0,
        activeTime = 0,
        enableTimeSpell = true,
        enabled = true
    }

    if fugaInterface.optionsPanel.lifesOption:isChecked() then
        spellConfig.enableLifes = true
        spellConfig.amountLifes = fugaInterface.optionsPanel.configValue:getValue()
        spellConfig.currentLifes = spellConfig.amountLifes
    elseif fugaInterface.optionsPanel.multipleOption:isChecked() then
        spellConfig.enableMultiple = true
        spellConfig.amountUses = fugaInterface.optionsPanel.configValue:getValue()
        spellConfig.currentUses = spellConfig.amountUses
    end
    if fugaInterface.optionsPanel.reviveOption:isChecked() then spellConfig.enableRevive = true end

    table.insert(storage.fugaSpells, spellConfig)
    reindexTable(storage.fugaSpells)
    refreshFugaList()
    persistFuga()
    -- Reseta completamente o formulário após inserir, deixando pronto para a próxima macro.
    -- Antes apenas os TextEdits eram limpos, então HP/CD/hotkey/opções permaneciam com os
    -- valores da macro anterior.
    fugaInterface.castSpell:clearText()
    fugaInterface.orangeSpell:clearText()
    fugaInterface.onScreen:clearText()

    fugaHp:setValue(0)

    fugaCdTotal:setValue(0)

    fugaCdActive:setValue(0)

    fugaInterface.hotkeyList:setCurrentOption('AUTO')

    fugaInterface.sameSpell:setChecked(true)
    fugaInterface.orangeSpell:setEnabled(false)

    fugaInterface.optionsPanel.lifesOption:setChecked(false)
    fugaInterface.optionsPanel.multipleOption:setChecked(false)
    fugaInterface.optionsPanel.reviveOption:setChecked(false)
    fugaInterface.optionsPanel.configValue:setValue(0)
    fugaInterface.optionsPanel.configValue:hide()
end

fugaInterface.moveUp.onClick = function()
    local action = fugaInterface.spellList:getFocusedChild()
    if not action then return end
    local index = fugaInterface.spellList:getChildIndex(action)
    if index < 2 then return end
    fugaInterface.spellList:moveChildToIndex(action, index - 1)
    storage.fugaSpells[index], storage.fugaSpells[index - 1] = storage.fugaSpells[index - 1], storage.fugaSpells[index]
    reindexTable(storage.fugaSpells)
    persistFuga()
end

fugaInterface.moveDown.onClick = function()
    local action = fugaInterface.spellList:getFocusedChild()
    if not action then return end
    local index = fugaInterface.spellList:getChildIndex(action)
    if index >= fugaInterface.spellList:getChildCount() then return end
    fugaInterface.spellList:moveChildToIndex(action, index + 1)
    storage.fugaSpells[index], storage.fugaSpells[index + 1] = storage.fugaSpells[index + 1], storage.fugaSpells[index]
    reindexTable(storage.fugaSpells)
    persistFuga()
end

-- ============================================================================
-- MOTOR DE FUGAS
-- Baseado exclusivamente na lógica ESCAPE do sistema Especiais.
-- Mantém a contagem de mortes/vidas do Fugas.lua e o suporte a Izanagi.
-- ============================================================================

local oldHealthPercent = hppercent()
local armIzanagiRevive

local function getAttackersAddition()
    local attackers = 0
    for _, expire in pairs(storageAttackers) do
        if expire and expire >= os.time() then
            attackers = attackers + 1
        end
    end
    attackers = math.min(attackers, 6)
    return attackers * 5
end

-- Mantém a regra do Especiais:
-- 100% = automático a partir de 45%, somando 5% por atacante.
local function getEscapePercent(value)
    local percent = tonumber(value) or 0
    if percent == 100 then
        percent = 45
    end
    percent = percent + getAttackersAddition()
    return math.min(percent, 100)
end

local function hasAnyActiveFuga(currentSec)
    for _, entry in ipairs(storage.fugaSpells or {}) do
        if entry and entry.enabled and (tonumber(entry.activeTime) or 0) >= currentSec then
            return true
        end
    end
    return false
end

local function canCastFuga(entry, currentSec)
    if not entry or not entry.enabled then
        return false
    end

    if (tonumber(entry.cooldownTime) or 0) >= currentSec then
        return false
    end

    -- O Especiais não permite uma segunda fuga enquanto existe
    -- uma fuga ativa.
    if hasAnyActiveFuga(currentSec) then
        return false
    end

    local key = entry.keyPress
    local percent = tonumber(entry.selfHealth) or 0

    -- AUTO / porcentagem.
    if percent > 0 then
        local healthPercent = hppercent()
        if healthPercent < getEscapePercent(percent) then
            return true
        end
    end

    -- Hotkey manual.
    if key and key ~= "AUTO"
        and modules.corelib.g_keyboard.isKeyPressed(key)
        and not modules.game_console:isChatEnabled() then
        return true
    end

    return false
end

-- O Especiais respeita a ordem das fugas:
-- se uma fuga automática já está pronta para ser usada, as seguintes
-- automáticas não furam a fila. Hotkeys manuais continuam funcionando.
local function doEscapeCast()
    local spells = storage.fugaSpells or {}
    if #spells == 0 then return end

    local currentSec = os.time()
    local anyAutomaticReady = false

    for _, entry in ipairs(spells) do
        if entry and entry.enabled then
            local key = entry.keyPress
            local isManualKey = key and key ~= "AUTO"

            if not isManualKey
                and (tonumber(entry.rawCooldownTotal) or 0) > 0 then

                if anyAutomaticReady then
                    goto continue
                end

                if (tonumber(entry.cooldownTime) or 0) < currentSec then
                    anyAutomaticReady = true
                end
            end

            if canCastFuga(entry, currentSec) then
                -- A fuga foi disparada: o cooldown/tempo ativo será
                -- confirmado pela mensagem laranja, como no Especiais.
                say(entry.spellCast)

                if entry.enableRevive
                    and tostring(entry.spellCast or ''):lower() == 'izanagi' then
                    armIzanagiRevive()
                end

                lastCastAttempt = 4
                return
            end

            ::continue::
        end
    end
end

-- Recebe a confirmação da fuga pela mensagem laranja.
-- Essa parte segue a mecânica do Especiais: cooldown e tempo ativo
-- começam somente quando o servidor confirma o uso.
onTalk(function(name, level, mode, text)
    if mode ~= 44 or name ~= g_game.getCharacterName() then return end

    local txt = text:trim():lower()
    local currentSec = os.time()

    -- Izanagi: registra a posição de origem no momento da confirmação.
    if txt == 'izanagi' then
        for _, entry in ipairs(storage.fugaSpells or {}) do
            if entry and entry.enabled and entry.enableRevive
                and tostring(entry.spellCast or ''):lower() == 'izanagi' then
                local origin = player:getPosition()
                if origin then
                    izanagiReviveState.pending = true
                    izanagiReviveState.died = false
                    izanagiReviveState.origin = {
                        x = origin.x, y = origin.y, z = origin.z
                    }
                    izanagiReviveState.lastPos = {
                        x = origin.x, y = origin.y, z = origin.z
                    }
                end
                break
            end
        end
    end

    for _, entry in ipairs(storage.fugaSpells or {}) do
        if entry and txt == tostring(entry.orangeSpell or ''):lower() then
            local rawTotalSec = tonumber(entry.rawCooldownTotal) or 0
            local rawActiveSec = tonumber(entry.rawCooldownActive) or 0

            if (tonumber(entry.cooldownTime) or 0) < currentSec then
                if entry.enableLifes then
                    -- Primeira confirmação inicia o ciclo completo.
                    -- As confirmações seguintes não consomem vidas:
                    -- a vida é consumida somente quando uma morte é detectada.
                    if not entry.activeTime or entry.activeTime < currentSec then
                        entry.currentLifes = tonumber(entry.amountLifes) or 1
                    end
                    entry.cooldownTime = currentSec + rawTotalSec
                    entry.activeTime = currentSec + rawActiveSec

                elseif entry.enableMultiple then
                    if not entry.activeTime or entry.activeTime < currentSec then
                        entry.currentUses = tonumber(entry.amountUses) or 1
                    end
                    entry.cooldownTime = currentSec + rawTotalSec
                    entry.activeTime = currentSec + rawActiveSec

                else
                    entry.cooldownTime = currentSec + rawTotalSec
                    entry.activeTime = currentSec + rawActiveSec
                end

                persistFuga()
            end

            break
        end
    end
end)

-- ============================================================================
-- CONTAGEM DE MORTES / VIDAS
-- Mantida do Fugas.lua, mas agora compatível com a mecânica do Especiais:
-- a carga só é consumida quando o HP sobe bruscamente após a morte.
-- ============================================================================

onCreatureHealthPercentChange(function(creature, percent)
    if creature ~= player or percent == nil then return end

    local diff = percent - oldHealthPercent
    oldHealthPercent = percent

    -- O Especiais considera uma subida >= 85 pontos como retorno após morte.
    if diff < 85 then return end

    local currentSec = os.time()
    local changed = false

    for _, entry in ipairs(storage.fugaSpells or {}) do
        if entry and entry.enabled and entry.enableLifes then
            local activeTime = tonumber(entry.activeTime) or 0

            if activeTime >= currentSec then
                local currentLifes = tonumber(entry.currentLifes)
                    or tonumber(entry.amountLifes)
                    or 1

                if currentLifes > 0 then
                    currentLifes = currentLifes - 1
                    entry.currentLifes = currentLifes
                    changed = true
                end

                -- Ao atingir o limite de mortes, encerra o estado ativo,
                -- exatamente como o controle death_max_count do Especiais.
                if currentLifes <= 0 then
                    entry.activeTime = nil
                    entry.cooldownTime = nil
                    entry.currentLifes = tonumber(entry.amountLifes) or 1
                end
            end
        end
    end

    if changed then
        persistFuga()
    end
end)

-- Controle específico do ciclo do Izanagi.
armIzanagiRevive = function()
    local origin = player:getPosition()
    if not origin then return end

    izanagiReviveState.pending = true
    izanagiReviveState.died = false
    izanagiReviveState.origin = {
        x = origin.x, y = origin.y, z = origin.z
    }
    izanagiReviveState.lastPos = {
        x = origin.x, y = origin.y, z = origin.z
    }
end

local function resetIzanagiState()
    local changed = false

    for _, entry in ipairs(storage.fugaSpells or {}) do
        if entry and entry.enableRevive
            and tostring(entry.spellCast or ''):lower() == 'izanagi' then

            -- Encerra somente o tempo ativo. O cooldownTime é mantido, pois ele
            -- já foi calculado como (momento do cast + CD Total). Assim, se você
            -- morreu com 7s de 10s ativos e o CD é 75s, sobram 68s de cooldown.
            entry.activeTime = 0

            if entry.enableLifes then
                entry.currentLifes = tonumber(entry.amountLifes) or 1
            end

            if entry.enableMultiple then
                entry.currentUses = tonumber(entry.amountUses) or 1
            end

            changed = true
        end
    end

    if changed then persistFuga() end

    izanagiReviveState.pending = false
    izanagiReviveState.died = false
    izanagiReviveState.origin = nil
    izanagiReviveState.lastPos = nil
end

local function distance2D(a, b)
    if not a or not b then return 999999 end
    return math.max(math.abs(a.x - b.x), math.abs(a.y - b.y))
end

local function safePlayerIsDead()
    if not player then return false end

    if type(player.isDead) == 'function' then
        local ok, result = pcall(function() return player:isDead() end)
        if ok and result == true then return true end
    end

    if type(player.getHealth) == 'function' then
        local ok, hp = pcall(function() return player:getHealth() end)
        if ok and tonumber(hp) and tonumber(hp) <= 0 then return true end
    end

    local ok, hp = pcall(function() return hppercent() end)
    if ok and tonumber(hp) and tonumber(hp) <= 0 then return true end

    return false
end

local function trackIzanagiRevive()
    if not izanagiReviveState.pending or not izanagiReviveState.origin then return end

    local pPos = player:getPosition()
    if not pPos then return end

    local deadNow = safePlayerIsDead()

    if deadNow then
        izanagiReviveState.died = true
        izanagiReviveState.lastPos = {
            x = pPos.x, y = pPos.y, z = pPos.z
        }
        return
    end

    if izanagiReviveState.died then
        local sameFloor = pPos.z == izanagiReviveState.origin.z
        local nearOrigin = distance2D(pPos, izanagiReviveState.origin) <= 3

        if sameFloor and nearOrigin then
            resetIzanagiState()
            return
        end
    end

    izanagiReviveState.lastPos = {
        x = pPos.x, y = pPos.y, z = pPos.z
    }
end

-- Registro de atacantes: SOMENTE PLAYERS, igual ao Especiais da Tyr Livre.
-- A mensagem de dano so serve como gatilho; o nome so entra na lista se existir
-- na tela uma criatura correspondente e ela for realmente um player.
onTextMessage(function(mode, text)
    if not text or not text:find("attack by") then return end

    local spectators = (ShazamCore and ShazamCore.getSpectators(false, 80) or getSpectators())
    if not spectators then return end

    for _, spec in ipairs(spectators) do
        if spec and spec:isPlayer() and spec ~= player then
            local specName = spec:getName()
            if specName and text:find(specName, 1, true) then
                storageAttackers[specName] = os.time() + 1
                break
            end
        end
    end
end)

-- Limpeza dos atacantes, como no Especiais.
macro(500, function()
    if not storage.fugaSettings.isOn then return end
    local currentSec = os.time()

    for name, expire in pairs(storageAttackers) do
        if expire < currentSec then
            storageAttackers[name] = nil
        end
    end
end)

-- Motor principal das fugas.
macro(100, function()
    if not storage.fugaSettings.isOn or isInPz() then return end

    trackIzanagiRevive()

    if lastCastAttempt > 0 then
        lastCastAttempt = lastCastAttempt - 1
        return
    end

    doEscapeCast()
end)

-- Atualização visual (desacoplada do motor; nao precisa competir a cada 250ms).
macro(300, function()
    if not storage.fugaSettings.isOn then
        -- Fugas OFF sempre esconde TUDO da tela, independentemente da
        -- preferencia salva do Monitor de Fugas.
        if fugaStatusWidget then fugaStatusWidget:hide() end
        for _, widget in pairs(fugaSpellsWidgets or {}) do widget:hide() end
        return
    end
    updateFugaStatusWidget()

    local currentSec = os.time()

    for _, spellConfig in ipairs(storage.fugaSpells or {}) do
        local widget = fugaSpellsWidgets[spellConfig.spellCast]

        if widget then
            -- Visibilidade é independente do cooldown: desligar a macro só esconde
            -- o TimeSpell; cooldownTime/activeTime permanecem intactos.
            if storage.fugaSettings.isOn and spellConfig.enableTimeSpell then
                widget:show()
            else
                widget:hide()
            end

            local textToSet = firstLetterUpper(spellConfig.onScreen)
            local color = "green"

            if spellConfig.enableLifes
                and (spellConfig.currentLifes or 0) <= 0
                and spellConfig.cooldownTime
                and spellConfig.cooldownTime > currentSec then

                textToSet = textToSet .. ': ' .. formatRemainingTime(spellConfig.cooldownTime)
                color = "#FF4040"

            elseif spellConfig.enableMultiple
                and (spellConfig.currentUses or 0) <= 0
                and spellConfig.cooldownTime
                and spellConfig.cooldownTime > currentSec then

                textToSet = textToSet .. ': ' .. formatRemainingTime(spellConfig.cooldownTime)
                color = "#FF4040"

            elseif spellConfig.activeTime and spellConfig.activeTime > currentSec then
                textToSet = textToSet .. ': ' .. formatRemainingTime(spellConfig.activeTime)
                color = "#00FFFF"

            elseif spellConfig.cooldownTime and spellConfig.cooldownTime > currentSec then
                textToSet = textToSet .. ': ' .. formatRemainingTime(spellConfig.cooldownTime)
                color = "#FF4040"

            else
                textToSet = textToSet .. ': Pronto!'
            end

            if spellConfig.enableLifes and spellConfig.currentLifes then
                textToSet = '[' .. spellConfig.currentLifes .. ' Mortes] ' .. textToSet
            elseif spellConfig.enableMultiple and spellConfig.currentUses then
                textToSet = '[' .. spellConfig.currentUses .. ' Usos] ' .. textToSet
            end

            widget:setText(textToSet)
            widget:setColor(color)
        end
    end
end)

-- Sincroniza a lista principal com o storage usado pelo motor melhorado.
refreshFugaMainList = function()
    local list = fugaMainScreen.mainPanel.spellsList
    for _, child in pairs(list:getChildren()) do child:destroy() end

    for index, entry in ipairs(storage.fugaSpells or {}) do
        local row = setupUI(FUGA_MAIN_ENTRY, list)
        row:setId("fuga_" .. tostring(index))
        row.enabled:setChecked(entry.enabled == true)
        row.spellTime:setChecked(entry.enableTimeSpell == true)

        local keyText = (entry.keyPress and entry.keyPress ~= "AUTO") and (" | Key: " .. entry.keyPress) or ""
        local hpText = tostring(entry.selfHealth or 0) .. "%"
        row:setText(firstLetterUpper(entry.spellCast or "") .. " | " .. hpText .. keyText)

        row.enabled.onCheckChange = function(_, checked)
            entry.enabled = checked
            persistFuga()
        end
        row.spellTime.onCheckChange = function(_, checked)
            entry.enableTimeSpell = checked
            local sw = fugaSpellsWidgets[entry.spellCast]
            if sw then
                if storage.fugaSettings.isOn and checked then sw:show() else sw:hide() end
            end
            persistFuga()
        end
        row.remove.onClick = function()
            table.remove(storage.fugaSpells, index)
            reindexTable(storage.fugaSpells)
            refreshFugaList()
            refreshFugaMainList()
            persistFuga()
        end
        row.onDoubleClick = function()
            -- Reaproveita o editor completo do Fugas para não perder Vidas/Multi/Revive.
            fugaInterface.castSpell:setText(entry.spellCast or "")
            fugaInterface.orangeSpell:setText(entry.orangeSpell or entry.spellCast or "")
            fugaInterface.onScreen:setText(entry.onScreen or entry.spellCast or "")
            fugaHp:setValue(entry.selfHealth or 0)
            fugaCdTotal:setValue(entry.rawCooldownTotal or 0)
            fugaCdActive:setValue(entry.rawCooldownActive or 0)
            if entry.keyPress then fugaInterface.hotkeyList:setCurrentOption(entry.keyPress) end
            fugaInterface.optionsPanel.lifesOption:setChecked(entry.enableLifes == true)
            fugaInterface.optionsPanel.multipleOption:setChecked(entry.enableMultiple == true)
            fugaInterface.optionsPanel.reviveOption:setChecked(entry.enableRevive == true)
            if entry.enableLifes then
                fugaInterface.optionsPanel.configValue:show()
                fugaInterface.optionsPanel.configValue:setValue(entry.amountLifes or 4)
            elseif entry.enableMultiple then
                fugaInterface.optionsPanel.configValue:show()
                fugaInterface.optionsPanel.configValue:setValue(entry.amountUses or 2)
            else
                fugaInterface.optionsPanel.configValue:hide()
            end
            table.remove(storage.fugaSpells, index)
            reindexTable(storage.fugaSpells)
            refreshFugaList()
            refreshFugaMainList()
            fugaMainScreen:hide()
            fugaInterface:show(); fugaInterface:raise(); fugaInterface:focus()
        end
    end
end

fugaMainScreen.mainPanel.addButton.onClick = function()
    local spell = fugaMainScreen.mainPanel.nameField:getText():trim():lower()
    if spell:len() == 0 then
        fugaMainScreen.mainPanel.message:setText("Insira uma magia!")
        fugaMainScreen.mainPanel.message:setColor("red")
        return
    end
    fugaMainScreen.mainPanel.message:setText("")
    fugaInterface.castSpell:setText(spell)
    fugaInterface.orangeSpell:setText(spell)
    fugaInterface.onScreen:setText(spell)
    fugaMainScreen:hide()
    fugaInterface:show(); fugaInterface:raise(); fugaInterface:focus()
end

fugaMainScreen.mainPanel.closeButton.onClick = function()
    fugaMainScreen:hide()
end
fugaMainScreen.onEscape = function()
    fugaMainScreen:hide()
    if gameRootPanel then gameRootPanel:focus() end
end
fugaMainScreen.mainPanel.showInfo:setChecked(storage.fugaSettings.showInfo ~= false)
fugaMainScreen.mainPanel.showInfo.onCheckChange = function(_, checked)
    storage.fugaSettings.showInfo = checked
    fugaInterface.showInfo:setChecked(checked)
    fugaMonitorCheck:setChecked(checked)
    persistFuga()
    updateFugaStatusWidget()
end

-- Os checkboxes antigos ficavam dentro das janelas de configuracao (inclusive
-- perto do botao Fechar). Agora o controle oficial e "Monitor de Fugas" abaixo
-- da macro, entao escondemos os antigos para nao haver controles duplicados.
fugaInterface.showInfo:hide()
fugaMainScreen.mainPanel.showInfo:hide()

-- Ao fechar o editor detalhado, volta para a tela principal no padrão Especiais.
fugaInterface.closeButton.onClick = function()
    fugaInterface:hide()
    refreshFugaMainList()
    fugaMainScreen:show(); fugaMainScreen:raise(); fugaMainScreen:focus()
end

refreshFugaList()
refreshFugaMainList()
updateFugaStatusWidget()


-- Atalhos: registra esta macro para aparecer na janela Atalhos (aba User).
do
  local g = (type(_G) == "table" and _G) or modules["_G"]
  g.configData = g.configData or {}
  g.configData["fugas"] = {macro = fugaIcon.title}
end
