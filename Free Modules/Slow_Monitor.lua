-- ============================================================================
-- SHAZAM SLOW MONITOR
-- Oculta APENAS o aviso visual "Slow macro/Slow hotkey" do Bot.
-- O warning continua indo para o logger/Terminal (Ctrl+T / NTO ARTS.log).
-- Tambem mantem um resumo em memoria para consulta dentro da Custom.
-- ============================================================================

setDefaultTab("Main")

local realG = modules["_G"]
local logger = realG and realG["g_logger"] or nil
local originalWarning = warning
local entries = {}
local total = 0
local startedAt = os.date("%d/%m/%Y %H:%M:%S")

local function isSlow(text)
  text = tostring(text or "")
  local lower = text:lower()
  -- OTCv8 tambem mede callbacks (onTalk, onTextMessage, onCreature*, etc.).
  -- Captura qualquer diagnostico que comece com "Slow ", sem esconder warnings normais.
  return lower:match("^%s*slow%s+") ~= nil
end

local function parseSlow(text)
  text = tostring(text or "")
  local ms = tonumber(text:match("%((%d+)ms%)")) or 0
  local kind = text:match("^[Ss]low%s+([^%s%(]+)") or "Macro"
  local name = text:match("ms%):%s*(.-)%s*%-%s*%[string") or text:match("ms%):%s*(.-)%s*%-%s*") or ""
  if name == "" then name = "(sem nome)" end

  local file, line = text:match('%[string "([^"]+)"%]:(%d+)')
  if not file then
    file, line = text:match('([%w_ %-%./\\]+%.lua)%]?:?(%d*)')
  end
  file = file or "origem desconhecida"
  line = line or "?"

  return ms, kind, name, file, line
end

local function capture(text)
  local ms, kind, name, file, line = parseSlow(text)
  local key = file .. ":" .. line
  local e = entries[key]
  if not e then
    e = {kind=kind, name=name, file=file, line=line, count=0, peak=0, sum=0, last=0, lastTime=""}
    entries[key] = e
  end
  e.count = e.count + 1
  e.sum = e.sum + ms
  e.last = ms
  if ms > e.peak then e.peak = ms end
  e.lastTime = os.date("%H:%M:%S")
  total = total + 1
end

-- Ponto principal: context.warning e consultado em tempo de execucao pelo OTCv8.
-- Para Slow Macro, NAO chamamos o callback visual do Bot; mandamos direto ao logger.
-- Para qualquer outro warning, mantemos o comportamento original.
warning = function(text)
  text = tostring(text or "")
  if isSlow(text) then
    capture(text)
    if logger and type(logger.warning) == "function" then
      pcall(logger.warning, "[BOT] " .. text)
    else
      -- fallback: ainda fica no terminal, sem usar o warning visual do Bot
      print("[BOT] " .. text)
    end
    return
  end
  return originalWarning(text)
end

-- Em alguns scripts o alias warn pode ser usado diretamente. Nao o substituimos:
-- assim somente o diagnostico gerado por context.warning e filtrado.

local function sortedEntries()
  local list = {}
  for _, e in pairs(entries) do table.insert(list, e) end
  table.sort(list, function(a,b)
    if a.count ~= b.count then return a.count > b.count end
    return a.peak > b.peak
  end)
  return list
end

local function buildReport()
  local out = {
    "SHAZAM - SLOW MONITOR",
    "Sessao: " .. startedAt,
    "Total detectado: " .. total,
    "Aviso visual: OCULTO | Terminal/Log: ATIVO",
    "----------------------------------------"
  }
  local list = sortedEntries()
  if #list == 0 then
    table.insert(out, "Nenhum evento Slow detectado nesta sessao.")
  else
    for i, e in ipairs(list) do
      local avg = e.count > 0 and math.floor(e.sum / e.count) or 0
      table.insert(out, string.format("%02d) %s:%s", i, e.file, e.line))
      table.insert(out, string.format("    %s: %s | Ocorrencias: %d", e.kind, e.name, e.count))
      table.insert(out, string.format("    Ultimo: %dms | Media: %dms | Pico: %dms | %s", e.last, avg, e.peak, e.lastTime))
    end
  end
  return table.concat(out, "\n")
end

local monitorWindow = setupUI([[
MainWindow
  id: shazamSlowMonitorWindow
  size: 560 420
  !text: tr('Slow Monitor - Shazam')
  @onSetup: self:hide();
  @onEscape: self:hide();

  Panel
    id: mainPanel
    anchors.fill: parent
    image-source: /images/ui/panel_flat
    image-border: 6

    Label
      id: status
      text: Slow visual oculto | Log/Terminal ativo
      color: #7CFC00
      anchors.top: parent.top
      anchors.left: parent.left
      anchors.right: parent.right
      margin-top: 8
      margin-left: 10
      text-align: center

    TextEdit
      id: report
      anchors.top: status.bottom
      anchors.left: parent.left
      anchors.right: parent.right
      anchors.bottom: clearButton.top
      margin-top: 8
      margin-left: 10
      margin-right: 10
      margin-bottom: 8
      text-wrap: false
      vertical-scrollbar: reportScroll

    VerticalScrollBar
      id: reportScroll
      anchors.top: report.top
      anchors.bottom: report.bottom
      anchors.right: report.right
      step: 20
      pixels-scroll: true

    Button
      id: clearButton
      text: Limpar
      anchors.bottom: parent.bottom
      anchors.left: parent.left
      margin-left: 10
      margin-bottom: 10
      size: 110 26

    Button
      id: copyButton
      text: Copiar Relatorio
      anchors.bottom: parent.bottom
      anchors.left: clearButton.right
      margin-left: 10
      margin-bottom: 10
      size: 150 26

    Button
      id: closeButton
      text: Fechar
      anchors.bottom: parent.bottom
      anchors.right: parent.right
      margin-right: 10
      margin-bottom: 10
      size: 110 26
]], g_ui.getRootWidget())

local function refreshWindow()
  if monitorWindow and monitorWindow.mainPanel and monitorWindow.mainPanel.report then
    monitorWindow.mainPanel.report:setText(buildReport())
  end
end

monitorWindow.mainPanel.clearButton.onClick = function()
  entries = {}
  total = 0
  startedAt = os.date("%d/%m/%Y %H:%M:%S")
  refreshWindow()
end

monitorWindow.mainPanel.copyButton.onClick = function()
  local report = buildReport()
  if g_window and g_window.setClipboardText then
    g_window.setClipboardText(report)
    monitorWindow.mainPanel.status:setText("Relatorio copiado para a area de transferencia")
  end
end

monitorWindow.mainPanel.closeButton.onClick = function() monitorWindow:hide() end

local openButton = setupUI([[
Button
  id: slowMonitorButton
  text: Slow Monitor
  height: 24
  margin-top: 3
  tooltip: Ver macros e callbacks lentos sem poluir a tela do jogo
]])

openButton.onClick = function()
  refreshWindow()
  monitorWindow:show()
  monitorWindow:raise()
  monitorWindow:focus()
end

if ShazamGuard then
  ShazamGuard.trackWidget(monitorWindow)
  ShazamGuard.onCleanup(function()
    -- So restaura se ainda somos o filtro ativo desta sessao.
    if warning ~= originalWarning then
      warning = originalWarning
    end
  end)
end

-- Atualizacao leve somente enquanto a janela estiver visivel.
macro(1000, function()
  if monitorWindow and monitorWindow:isVisible() then refreshWindow() end
end)
