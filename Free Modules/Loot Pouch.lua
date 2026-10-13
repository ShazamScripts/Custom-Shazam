-- Retira automaticamente do Loot Pouch quando a pilha chega ao limite escolhido.
-- O painel nativo continua sendo monitorado mesmo quando a janela esta fechada.

if type(setDefaultTab) == "function" then
  setDefaultTab("Others")
end

local MACRO_NAME = "Auto Retirar Loot 500"
local CONFIG_KEY = "autoLootPouch"
local DEFAULT_ITEM_LIMIT = 200
local RIGHT_BUTTON = MouseRightButton or 2
local CONFIRM_TIMEOUT = 5000
local ACTION_COOLDOWN = 1800

local function normalizeItemLimit(value)
  value = math.floor(tonumber(value) or DEFAULT_ITEM_LIMIT)
  if value < 1 then return 1 end
  if value > 500 then return 500 end
  return value
end

storage[CONFIG_KEY] = type(storage[CONFIG_KEY]) == "table"
    and storage[CONFIG_KEY] or {}

local ITEM_LIMIT = normalizeItemLimit(storage[CONFIG_KEY].itemLimit)
storage[CONFIG_KEY].itemLimit = ITEM_LIMIT

local state = {
  pouch = nil,
  waitingConfirm = false,
  nativeConfirm = false,
  confirmReadyAt = 0,
  confirmDeadline = 0,
  nextAction = 0,
  nextPouchSearch = 0,
  nextOpenCheck = 0,
  openedByMacro = false,
  inspectUntil = 0
}

local function safeCall(callback, fallback)
  local ok, value = pcall(callback)
  if ok then
    return value
  end
  return fallback
end

local function timeNow()
  if type(now) == "number" then
    return now
  end
  if g_clock and type(g_clock.millis) == "function" then
    return tonumber(safeCall(function() return g_clock.millis() end, 0)) or 0
  end
  return math.floor(os.clock() * 1000)
end

local function rootWidget()
  if not g_ui or type(g_ui.getRootWidget) ~= "function" then
    return nil
  end
  return safeCall(function() return g_ui.getRootWidget() end, nil)
end

local function parentOf(widget)
  if not widget then return nil end
  return safeCall(function() return widget:getParent() end, nil)
end

local function childrenOf(widget)
  if not widget then return {} end
  local children = safeCall(function() return widget:getChildren() end, {})
  return type(children) == "table" and children or {}
end

local function descendantsOf(widget)
  if not widget then return {} end

  local descendants = safeCall(function()
    return widget:recursiveGetChildren()
  end, nil)

  if type(descendants) == "table" then
    return descendants
  end

  -- Compatibilidade com clientes que nao expoem recursiveGetChildren.
  local result = {}
  local queue = childrenOf(widget)
  local index = 1
  while index <= #queue and #result < 5000 do
    local child = queue[index]
    index = index + 1
    result[#result + 1] = child
    for _, grandChild in ipairs(childrenOf(child)) do
      queue[#queue + 1] = grandChild
    end
  end
  return result
end

local function widgetsIn(widget)
  local result = {widget}
  for _, child in ipairs(descendantsOf(widget)) do
    result[#result + 1] = child
  end
  return result
end

local function isVisible(widget)
  if not widget then return false end
  local root = rootWidget()
  local current = widget
  local depth = 0

  while current and depth < 40 do
    if not safeCall(function() return current:isVisible() end, false) then
      return false
    end
    if current == root then
      return true
    end
    current = parentOf(current)
    depth = depth + 1
  end

  return current == root
end

local function isAttached(widget)
  if not widget then return false end
  if safeCall(function() return widget:isDestroyed() end, false) then
    return false
  end

  local root = rootWidget()
  local current = widget
  local depth = 0
  while current and depth < 40 do
    if current == root then return true end
    current = parentOf(current)
    depth = depth + 1
  end
  return false
end

local function widgetText(widget)
  local text = safeCall(function() return widget:getText() end, "")
  return tostring(text or ""):lower()
end

local function trim(text)
  return tostring(text or ""):gsub("^%s+", ""):gsub("%s+$", "")
end

local function className(widget)
  return tostring(safeCall(function() return widget:getClassName() end, "") or "")
end

local function widgetId(widget)
  return tostring(safeCall(function() return widget:getId() end, "") or "")
end

local function childById(widget, id)
  if not widget then return nil end
  return safeCall(function() return widget:recursiveGetChildById(id) end, nil)
end

local function isItemWidget(widget)
  local class = className(widget)
  if class == "UIItem" or class:find("UIItem", 1, true) then
    return true
  end
  return safeCall(function() return widget:getItem() ~= nil end, false)
end

local function itemCount(widget)
  local count = 0

  count = math.max(count, tonumber(safeCall(function()
    return widget:getItemCount()
  end, 0)) or 0)

  count = math.max(count, tonumber(safeCall(function()
    return widget:getItemCountOrSubType()
  end, 0)) or 0)

  local item = safeCall(function() return widget:getItem() end, nil)
  if item then
    count = math.max(count, tonumber(safeCall(function()
      return item:getCount()
    end, 0)) or 0)
  end

  return count
end

local function findWidget(scope, predicate)
  for _, widget in ipairs(widgetsIn(scope)) do
    if safeCall(function() return predicate(widget) end, false) then
      return widget
    end
  end
  return nil
end

local function hasVisibleText(scope, fragment)
  return findWidget(scope, function(widget)
    return isVisible(widget) and widgetText(widget):find(fragment, 1, true) ~= nil
  end) ~= nil
end

local function findPouchScope(currentTime)
  if state.pouch then
    if widgetId(state.pouch) == "lootPouch" and isAttached(state.pouch) then
      return state.pouch
    end
    if isVisible(state.pouch)
        and hasVisibleText(state.pouch, "limite por item") then
      return state.pouch
    end
  end

  state.pouch = nil
  if currentTime < state.nextPouchSearch then
    return nil
  end
  state.nextPouchSearch = currentTime + 1000

  local root = rootWidget()
  if not root then return nil end

  -- Identificador nativo do modulo game_lootpouch. A janela e criada uma
  -- unica vez pelo cliente e pode continuar atualizada mesmo estando oculta.
  local nativePouch = childById(root, "lootPouch")
  if nativePouch then
    state.pouch = nativePouch
    return nativePouch
  end

  local marker = findWidget(root, function(widget)
    if not isVisible(widget) then return false end
    local text = widgetText(widget)
    return text:find("loot pouch", 1, true) ~= nil
        or text:find("limite por item", 1, true) ~= nil
  end)
  if not marker then return nil end

  -- Sobe somente ate o menor ancestral que contem os dados e os itens
  -- do Pouch, evitando qualquer item do inventario normal.
  local current = marker
  for _ = 1, 14 do
    if hasVisibleText(current, "limite por item") then
      local pouchItem = findWidget(current, function(widget)
        return isVisible(widget) and isItemWidget(widget)
      end)
      if pouchItem then
        state.pouch = current
        return current
      end
    end
    current = parentOf(current)
    if not current or current == root then break end
  end

  return nil
end

local function findFullItem(scope)
  -- Caminho nativo: cada LootPouchGridItem possui itemIcon e itemCount.
  local collectedPanel = childById(scope, "collectedPanel")
  if collectedPanel then
    for _, countLabel in ipairs(widgetsIn(collectedPanel)) do
      if widgetId(countLabel) == "itemCount" then
        local count = tonumber(widgetText(countLabel):match("(%d+)")) or 0
        if count >= ITEM_LIMIT then
          local card = parentOf(countLabel)
          for _ = 1, 5 do
            if not card or card == collectedPanel then break end
            local itemIcon = childById(card, "itemIcon")
            if itemIcon then
              return itemIcon, card
            end
            card = parentOf(card)
          end
        end
      end
    end
    -- Se o painel nativo existe, somente os cards acima sao validos. Nao
    -- deixa o fallback confundir previews/itens decorativos com loot cheio.
    return nil
  end

  -- Fallback para a versao do Pouch incorporada ao modulo Wikipedia.
  return findWidget(scope, function(widget)
    return isVisible(widget)
        and isItemWidget(widget)
        and itemCount(widget) >= ITEM_LIMIT
  end)
end

local function centerOf(widget)
  local rect = safeCall(function() return widget:getRect() end, nil)
  if not rect then return nil end
  return {
    x = rect.x + math.floor(rect.width / 2),
    y = rect.y + math.floor(rect.height / 2)
  }
end

local function callRightRelease(widget, position)
  if not widget then return false, false end
  local ok, handled = pcall(function()
    return widget:onMouseRelease(position, RIGHT_BUTTON)
  end)
  return ok, handled
end

local function rightClickItem(itemWidget, scope, eventWidget)
  local position = centerOf(itemWidget)
  if not position then return false end

  -- No modulo nativo o evento pertence ao LootPouchGridItem (o card); no
  -- fallback ele pertence ao proprio UIItem.
  local firstTarget = eventWidget or itemWidget
  local ok, handled = callRightRelease(firstTarget, position)
  if ok and handled ~= false then
    return true
  end

  -- Fallback seguro: sobe somente pelos pais que pertencem ao proprio Pouch.
  -- Nao faz hit-test global, pois a janela nativa pode estar oculta e haver
  -- outro widget visivel nas mesmas coordenadas.
  local target = parentOf(firstTarget)
  local depth = 0
  while target and depth < 20 do
    local eventOk, eventHandled = callRightRelease(target, position)
    if eventOk and eventHandled ~= false then
      return true
    end
    if target == scope then break end
    target = parentOf(target)
    depth = depth + 1
  end

  -- Alguns callbacks nao retornam true, mesmo depois de enviar a retirada.
  return ok
end

local function findConfirmButton()
  local root = rootWidget()
  if not root then return nil end

  -- IDs nativos do game_lootpouch.
  local nativeDialog = childById(root, "lootPouchConfirm")
  if nativeDialog and isVisible(nativeDialog) then
    local nativeButton = childById(nativeDialog, "confirmAcceptButton")
    if nativeButton and isVisible(nativeButton) then
      return nativeButton
    end
  end

  local marker = findWidget(root, function(widget)
    if not isVisible(widget) then return false end
    local text = widgetText(widget)
    return text:find("confirmar retirada", 1, true) ~= nil
        or text:find("deseja retirar", 1, true) ~= nil
  end)
  if not marker then return nil end

  local current = marker
  for _ = 1, 14 do
    local button = findWidget(current, function(widget)
      if not isVisible(widget) or trim(widgetText(widget)) ~= "confirmar" then
        return false
      end
      local class = className(widget)
      return class:find("Button", 1, true) ~= nil
          or safeCall(function() return type(widget.onClick) == "function" end, false)
    end)
    if button then return button end

    current = parentOf(current)
    if not current or current == root then break end
  end

  return nil
end

local function clickButton(button)
  if not button then return false end
  if not safeCall(function() return button:isEnabled() end, true) then
    return false
  end
  return pcall(function() button:onClick() end)
end

-- Interface identica ao painel de 17px do Travel System.
local cfg = storage[CONFIG_KEY]
if cfg.active == nil then cfg.active = true end

local ui = setupUI([[
Panel
  height: 17

  BotSwitch
    id: macro
    anchors.top: parent.top
    anchors.left: parent.left
    text-align: center
    width: 130
    text: Auto Retirar Loot

  Button
    id: configs
    anchors.top: prev.top
    anchors.left: prev.right
    anchors.right: parent.right
    margin-left: 3
    height: 17
    text: Config
]])

-- Ciclo fixo: abrir, inspecionar, coletar (se houver), fechar e esperar 60s.
local OPEN_CHECK_INTERVAL = 60000
local INSPECT_TIME = 2200

local function nativePouch()
  local root = rootWidget()
  return root and childById(root, "lootPouch") or nil
end

local function pouchWindow()
  local pouch = nativePouch()
  if not pouch then return nil end
  local current, root = pouch, rootWidget()
  local candidate = pouch
  for _ = 1, 14 do
    if not current or current == root then break end
    local cls = className(current):lower()
    if cls:find("window", 1, true) then return current end
    if not safeCall(function() return current:isVisible() end, true) then
      candidate = current
    end
    local parent = parentOf(current)
    if not parent or parent == root then break end
    current = parent
  end
  return candidate
end

local function closePouch()
  if state.openedByMacro then
    local window = pouchWindow()
    if window and isAttached(window) then
      pcall(function() window:hide() end)
    end
  end
  state.openedByMacro = false
  state.inspectUntil = 0
  state.pouch = nil
  state.nextPouchSearch = 0
end

local function openPouch(currentTime)
  local mod = modules and modules.game_lootpouch
  -- Executa a funcao de abertura em TODOS os ciclos, inclusive apos hide().
  local called = false
  if mod then
    for _, fn in ipairs({"showWindow", "openWindow", "show", "open"}) do
      if type(mod[fn]) == "function" then
        called = pcall(function() mod[fn]() end)
        if called then break end
      end
    end
  end
  local window = pouchWindow()
  if window and isAttached(window) then
    local ok = pcall(function()
      window:show()
      window:raise()
    end)
    called = called or ok
  end
  if called then
    state.openedByMacro = true
    state.inspectUntil = currentTime + INSPECT_TIME
    state.pouch = nil
    state.nextPouchSearch = 0
  end
  return called
end

local function closeAfterCollect()
  if type(schedule) == "function" then
    schedule(350, closePouch)
  else
    closePouch()
  end
end

local autoLootPouch = macro(250, function()
  if not g_game or not safeCall(function() return g_game.isOnline() end, false) then
    return
  end

  local currentTime = timeNow()

  if state.waitingConfirm then
    -- O modulo nativo deixa o item pendente no callback do card e expoe o
    -- mesmo confirmador usado pelo botao da janela. Isso tambem funciona com
    -- o Pouch oculto.
    if state.nativeConfirm and currentTime >= state.confirmReadyAt then
      state.nativeConfirm = false
      local lootPouchModule = modules and modules.game_lootpouch or nil
      if lootPouchModule and type(lootPouchModule.confirmUpgrade) == "function" then
        local confirmed = pcall(function()
          lootPouchModule.confirmUpgrade()
        end)
        if confirmed then
          state.waitingConfirm = false
          state.confirmReadyAt = 0
          state.confirmDeadline = 0
          state.nextAction = currentTime + ACTION_COOLDOWN
          closeAfterCollect()
          return
        end
      end
    end

    local confirmButton = findConfirmButton()
    if confirmButton and clickButton(confirmButton) then
      state.waitingConfirm = false
      state.nativeConfirm = false
      state.confirmReadyAt = 0
      state.confirmDeadline = 0
      state.nextAction = currentTime + ACTION_COOLDOWN
      closeAfterCollect()
      return
    end

    if currentTime >= state.confirmDeadline then
      state.waitingConfirm = false
      state.nativeConfirm = false
      state.confirmReadyAt = 0
      state.confirmDeadline = 0
      state.nextAction = currentTime + 1000
    end
    return
  end

  if currentTime < state.nextAction then return end

  -- O relogio de 60 segundos independe de a janela estar visivel ou nao.
  -- Nunca espera indefinidamente por uma janela que ja foi escondida.
  if not state.openedByMacro then
    if currentTime < state.nextOpenCheck then return end
    state.nextOpenCheck = currentTime + OPEN_CHECK_INTERVAL
    if not openPouch(currentTime) then
      -- Sem modulo/janela nativa disponivel: tenta novamente em 5 segundos.
      state.nextOpenCheck = currentTime + 5000
    end
    return
  end

  if currentTime >= state.inspectUntil then
    -- Fecha caso nao haja pilha suficiente ou o painel nao tenha carregado.
    closePouch()
    return
  end

  local pouch = findPouchScope(currentTime)
  if not pouch then
    if state.openedByMacro and currentTime >= state.inspectUntil then
      closePouch()
    end
    return
  end

  local fullItem, eventWidget = findFullItem(pouch)
  if not fullItem then
    if state.openedByMacro and currentTime >= state.inspectUntil then
      closePouch()
    end
    return
  end

  if rightClickItem(fullItem, pouch, eventWidget) then
    state.waitingConfirm = true
    state.nativeConfirm = eventWidget ~= nil
    state.confirmReadyAt = currentTime + 250
    state.confirmDeadline = currentTime + CONFIRM_TIMEOUT
    state.inspectUntil = currentTime + CONFIRM_TIMEOUT + 500
    state.nextAction = currentTime + ACTION_COOLDOWN
  else
    state.nextAction = currentTime + 1000
  end
end)

local function saveSettings()
  cfg.itemLimit = ITEM_LIMIT
  if type(ShazamPersistNow) == "function" then
    pcall(ShazamPersistNow)
  elseif type(saveConfig) == "function" then
    pcall(saveConfig)
  end
end

local function openItemLimitEditor()
  local textEdit = modules and modules.client_textedit or nil
  if not textEdit or type(textEdit.show) ~= "function" then
    print("[Auto Loot] Editor de configuracao indisponivel.")
    return
  end
  textEdit.show(tostring(ITEM_LIMIT), {
    title = "Auto Loot Pouch - Config",
    description = "Retirar quando a pilha atingir (1 a 500):",
    width = 360,
    validation = [[^([1-9]|[1-9][0-9]|[1-4][0-9][0-9]|500)$]]
  }, function(text)
    local value = tostring(text or ""):match("^%s*(%d+)%s*$")
    if not value then return end
    ITEM_LIMIT = normalizeItemLimit(value)
    saveSettings()
    ui.macro:setTooltip("Retira automaticamente ao atingir " .. ITEM_LIMIT .. " itens.")
  end)
end

ui.configs.onClick = openItemLimitEditor
ui.macro.onClick = function()
  cfg.active = not cfg.active
  ui.macro:setOn(cfg.active)
  if cfg.active then
    state.nextOpenCheck = 0
    autoLootPouch.setOn()
  else
    closePouch()
    autoLootPouch.setOff()
  end
  saveSettings()
end

ui.macro:setOn(cfg.active)
ui.macro:setTooltip("Retira automaticamente ao atingir " .. ITEM_LIMIT .. " itens.")
if cfg.active then autoLootPouch.setOn() else autoLootPouch.setOff() end
