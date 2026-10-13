lblInfo= UI.Label("-- UTILIDADES --")
lblInfo:setColor("yellow")

-- ============================================================================
-- Potions Sistema Unificado (Health / Chakra)
-- Switch "Potions" na lista do bot: liga/desliga o sistema todo
-- Botão "Config" ao lado: abre a janela de configuração
-- ============================================================================

tk.storage.PotionsSystem = tk.storage.PotionsSystem or {enabled = true}
tk.storage.HealthPotion  = tk.storage.HealthPotion  or {percent = 70, id = 23511, enabled = false}
tk.storage.ChakraPotion  = tk.storage.ChakraPotion  or {percent = 70, id = 23510, enabled = false}
tk.storage.VigorPotion   = nil -- removido: limpa sobra de versões antigas

local gameRootPanel = g_ui.getRootWidget():recursiveGetChildById("gameRootPanel")

-- Linha principal da lista de ferramentas do bot
local botWidget = setupUI([[
Panel
  height: 17

  BotSwitch
    id: switch
    anchors.top: parent.top
    anchors.left: parent.left
    width: 130
    text-align: center
    !text: tr("Potions")

    $on:
      color: white

    $!on:
      color: white

  Button
    id: configButton
    anchors.top: prev.top
    anchors.bottom: prev.bottom
    anchors.left: prev.right
    anchors.right: parent.right
    text: Config
]])

-- Interface visual estilizada (Painel de Configurações das Poções)
local screenWidget = setupUI([[
MainWindow
  size: 250 210
  !text: tr("Potions Settings")
  color: white

  Panel
    id: mainPanel
    image-source: /images/ui/panel_flat
    anchors.top: parent.top
    anchors.bottom: parent.bottom
    anchors.left: parent.left
    anchors.right: parent.right
    image-border: 6

    Panel
      id: hpRow
      anchors.top: parent.top
      anchors.left: parent.left
      anchors.right: parent.right
      margin-top: 8
      margin-left: 8
      margin-right: 8
      height: 46

      BotItem
        id: hpItem
        anchors.left: parent.left
        anchors.top: parent.top
        size: 35 35

      BotSwitch
        id: hpEnabled
        margin: 0
        anchors.left: prev.right
        anchors.top: parent.top
        anchors.right: parent.right
        text: Health Potion (%)
        height: 20
        margin-left: 6

      Panel
        id: hpPercent
        anchors.top: hpEnabled.bottom
        anchors.left: hpItem.right
        anchors.right: parent.right
        margin-top: 4
        margin-left: 6
        height: 22

    Panel
      id: mpRow
      anchors.top: hpRow.bottom
      anchors.left: parent.left
      anchors.right: parent.right
      margin-top: 8
      margin-left: 8
      margin-right: 8
      height: 46

      BotItem
        id: mpItem
        anchors.left: parent.left
        anchors.top: parent.top
        size: 35 35

      BotSwitch
        id: mpEnabled
        margin: 0
        anchors.left: prev.right
        anchors.top: parent.top
        anchors.right: parent.right
        text: Chakra Potion (%)
        height: 20
        margin-left: 6

      Panel
        id: mpPercent
        anchors.top: mpEnabled.bottom
        anchors.left: mpItem.right
        anchors.right: parent.right
        margin-top: 4
        margin-left: 6
        height: 22

    Button
      id: closeButton
      !text: tr("Fechar")
      anchors.bottom: parent.bottom
      anchors.right: parent.right
      anchors.left: parent.left
      margin-bottom: 6
      margin-left: 6
      margin-right: 6
]], g_ui.getRootWidget())

screenWidget:hide()

local mainPanel = screenWidget.mainPanel

-- ===================== Stepper ( - [valor] + ) =====================
local STEPPER_UI = [[
Panel
  height: 22

  Button
    id: minus
    anchors.top: parent.top
    anchors.left: parent.left
    width: 34
    height: 22
    text: <

  Button
    id: plus
    anchors.top: parent.top
    anchors.right: parent.right
    width: 34
    height: 22
    text: >

  TextEdit
    id: edit
    anchors.top: parent.top
    anchors.left: minus.right
    anchors.right: plus.left
    margin-left: 4
    margin-right: 4
    height: 22
    text-align: center
]]

local function createStepper(parent, minV, maxV, startValue, step)
    local w = setupUI(STEPPER_UI, parent)
    w:addAnchor(3, "parent", 3)
    w:addAnchor(4, "parent", 4)
    w:addAnchor(1, "parent", 1)
    w.minV, w.maxV = minV, maxV
    w.step = math.max(1, math.floor(tonumber(step) or 1))
    w.value = minV
    w.busy = false

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

    w.minus.onClick = function() w:setValue((math.ceil(w.value / w.step) - 1) * w.step) end
    w.plus.onClick = function() w:setValue((math.floor(w.value / w.step) + 1) * w.step) end

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

-- ===================== Configuração: Health Potion =====================
local hpStepper = createStepper(mainPanel.hpRow.hpPercent, 0, 100, tk.storage.HealthPotion.percent, 1)
hpStepper.onValueChange = function(self, value)
    tk.storage.HealthPotion.percent = value
end

mainPanel.hpRow.hpEnabled:setOn(tk.storage.HealthPotion.enabled)
mainPanel.hpRow.hpItem:setItemId(tk.storage.HealthPotion.id)

mainPanel.hpRow.hpEnabled.onClick = function(self)
    tk.storage.HealthPotion.enabled = not tk.storage.HealthPotion.enabled
    self:setOn(tk.storage.HealthPotion.enabled)
end

mainPanel.hpRow.hpItem.onItemChange = function(self)
    tk.storage.HealthPotion.id = self:getItemId()
end

-- ===================== Configuração: Chakra Potion =====================
local mpStepper = createStepper(mainPanel.mpRow.mpPercent, 0, 100, tk.storage.ChakraPotion.percent, 1)
mpStepper.onValueChange = function(self, value)
    tk.storage.ChakraPotion.percent = value
end

mainPanel.mpRow.mpEnabled:setOn(tk.storage.ChakraPotion.enabled)
mainPanel.mpRow.mpItem:setItemId(tk.storage.ChakraPotion.id)

mainPanel.mpRow.mpEnabled.onClick = function(self)
    tk.storage.ChakraPotion.enabled = not tk.storage.ChakraPotion.enabled
    self:setOn(tk.storage.ChakraPotion.enabled)
end

mainPanel.mpRow.mpItem.onItemChange = function(self)
    tk.storage.ChakraPotion.id = self:getItemId()
end

-- ===================== Controles de Interface e Cliques =====================
botWidget.switch:setOn(tk.storage.PotionsSystem.enabled)

botWidget.switch.onClick = function()
    local status = not botWidget.switch:isOn()
    tk.storage.PotionsSystem.enabled = status
    botWidget.switch:setOn(status)
end

-- Abre as configurações pelo botão Config, no mesmo padrão do Combo
botWidget.configButton.onClick = function()
    screenWidget:show()
    screenWidget:raise()
    screenWidget:focus()
end

screenWidget.onEscape = function()
    screenWidget:hide()
    if gameRootPanel then gameRootPanel:focus() end
end

screenWidget.mainPanel.closeButton.onClick = function()
    screenWidget:hide()
    if gameRootPanel then gameRootPanel:focus() end
end

-- ===================== Mecânica Inteligente de Macros =====================
local potionUseDelay = 400 -- Delay de exaustão padrão e dinâmico entre poções
local lastHealthPotionUse = 0
local lastChakraPotionUse = 0

-- Macro Corrigida: Vida (Health Potion)
macro((tonumber(storage["scrollBars"] and storage["scrollBars"]["macroDelay"]) or 50), function()
    if not tk.storage.PotionsSystem.enabled then return end
    if not tk.storage.HealthPotion.enabled then return end
    if now - lastHealthPotionUse < potionUseDelay then return end
    
    if player:getHealthPercent() <= tk.storage.HealthPotion.percent then
        useWith(tk.storage.HealthPotion.id, player)
        lastHealthPotionUse = now
    end
end)

-- Macro Corrigida: Mana (Chakra Potion) - Corrigido usando manapercent() estável
macro((tonumber(storage["scrollBars"] and storage["scrollBars"]["macroDelay"]) or 50), function()
    if not tk.storage.PotionsSystem.enabled then return end
    if not tk.storage.ChakraPotion.enabled then return end
    if now - lastChakraPotionUse < potionUseDelay then return end

    if manapercent() <= tk.storage.ChakraPotion.percent then
        useWith(tk.storage.ChakraPotion.id, player)
        lastChakraPotionUse = now
    end
end)


-- Atalhos: registra esta macro para aparecer na janela Atalhos (aba User).
do
  local g = (type(_G) == "table" and _G) or modules["_G"]
  g.configData = g.configData or {}
  g.configData["potion"] = {macro = botWidget.switch}
end
