-- Auto Summon - OTCv8
-- Configuracao por janela, sem dependencias externas.

storage.shazamSummon = storage.shazamSummon or {
  jutsu = "",
  mensagem = "",
  nomes = "",
  intervalo = 850
}
local cfg = storage.shazamSummon
local ultimoCast = 0
local confirmado = false
local aguardando = false
local vistoNaTela = false
local proximaTentativa = 0

local function normalizar(s)
  return tostring(s or ""):lower():gsub("^%s+", ""):gsub("%s+$", "")
end

-- Lista normalizada apenas quando a configuracao muda.
local nomesCacheTexto, nomesCache = nil, {}
local function nomesConfigurados()
  local texto = normalizar(cfg.nomes)
  if texto ~= nomesCacheTexto then
    nomesCacheTexto, nomesCache = texto, {}
    for nome in texto:gmatch("[^,]+") do
      nome = normalizar(nome)
      if nome ~= "" then nomesCache[#nomesCache + 1] = nome end
    end
  end
  return nomesCache
end

local function verificar()
  local nomes = nomesConfigurados()
  if #nomes == 0 then return nil end
  -- Busca apenas os nomes configurados; encerra assim que todos forem vistos.
  local faltantes = {}
  for _, nome in ipairs(nomes) do faltantes[nome] = true end
  local presentes = 0
  for _, criatura in ipairs(getSpectators() or {}) do
    local nome = normalizar(criatura:getName())
    if faltantes[nome] then
      faltantes[nome] = nil
      presentes = presentes + 1
      if presentes == #nomes then break end
    end
  end
  return presentes == #nomes, presentes
end

-- Mesma disposicao do Travel System: macro a esquerda, Config a direita.
local janela = setupUI([[
Panel
  height: 17

  BotSwitch
    id: ativar
    anchors.top: parent.top
    anchors.left: parent.left
    text-align: center
    width: 130
    !text: tr("Auto Summon")

  Button
    id: config
    anchors.top: prev.top
    anchors.left: prev.right
    anchors.right: parent.right
    margin-left: 3
    height: 17
    text: Config
]])

local configUI = setupUI([[
MainWindow
  id: summonWindow
  size: 340 255
  text: Auto Summon - Config
  @onSetup: self:hide()
  @onEscape: self:hide()

  Label
    text: Nome do Jutsu
    anchors.top: parent.top
    anchors.left: parent.left
    margin-top: 12
    margin-left: 12
  TextEdit
    id: jutsu
    anchors.top: prev.bottom
    anchors.left: parent.left
    anchors.right: parent.right
    margin-left: 12
    margin-right: 12
    margin-top: 3
    height: 24

  Label
    text: Mensagem laranja (trecho)
    anchors.top: jutsu.bottom
    anchors.left: parent.left
    margin-top: 9
    margin-left: 12
  TextEdit
    id: mensagem
    anchors.top: prev.bottom
    anchors.left: parent.left
    anchors.right: parent.right
    margin-left: 12
    margin-right: 12
    margin-top: 3
    height: 24

  Label
    text: Nomes dos summons (separados por virgula)
    anchors.top: mensagem.bottom
    anchors.left: parent.left
    margin-top: 9
    margin-left: 12
  TextEdit
    id: nomes
    anchors.top: prev.bottom
    anchors.left: parent.left
    anchors.right: parent.right
    margin-left: 12
    margin-right: 12
    margin-top: 3
    height: 24

  Button
    id: salvar
    text: Salvar e fechar
    anchors.bottom: parent.bottom
    anchors.left: parent.left
    anchors.right: parent.right
    margin-left: 12
    margin-right: 12
    margin-bottom: 10
    height: 25
]], g_ui.getRootWidget())

local function salvar()
  cfg.jutsu = configUI.jutsu:getText()
  cfg.mensagem = configUI.mensagem:getText()
  cfg.nomes = configUI.nomes:getText()
  confirmado = false
  aguardando = false
  vistoNaTela = false
  proximaTentativa = 0
  configUI:hide()
end

janela.config.onClick = function()
  configUI.jutsu:setText(cfg.jutsu or "")
  configUI.mensagem:setText(cfg.mensagem or "")
  configUI.nomes:setText(cfg.nomes or "")
  configUI:show()
  configUI:raise()
  configUI:focus()
end
configUI.salvar.onClick = salvar

-- Resposta rapida sem spam: kai apenas quando TODOS somem da tela.
-- A ausencia da tela nao prova morte; escadas e jump tambem acionam kai.
local fase = "verificar"
local executarEm = 0
local proximoKai = 0
local proximoJutsu = 0
local ultimaPresenca = false
local intervaloKai = 1200
local esperaAposKai = 250
local intervaloMinJutsu = 850

local summonMacro = macro(100, function()
  if not g_game.isOnline() or normalizar(cfg.jutsu) == "" then return end
  local todos, presentes = verificar()
  if todos == nil then return end -- Exige nomes para evitar kai infinito.
  local tempo = now

  if presentes > 0 then
    ultimaPresenca = true
    if fase == "aguardando_summon" then fase = "verificar" end
  end
  if todos then
    confirmado = true
    aguardando = false
    vistoNaTela = true
    fase = "verificar"
    return
  end

  -- Sumiram todos apos ja terem sido vistos: limpar summon preso em outro andar.
  if presentes == 0 and ultimaPresenca and fase == "verificar" and tempo >= proximoKai then
    say("kai")
    proximoKai = tempo + intervaloKai
    executarEm = tempo + esperaAposKai
    fase = "aguardando_summon"
    ultimaPresenca = false
    confirmado = false
    aguardando = false
    vistoNaTela = false
    return
  end

  if fase == "aguardando_summon" and tempo < executarEm then return end
  if fase == "aguardando_summon" then fase = "verificar" end

  -- Invoca imediatamente quando permitido, inclusive durante o combate.
  -- Respeita o intervalo salvo caso seja maior que o minimo de seguranca.
  local intervalo = intervaloMinJutsu
  if tempo < proximoJutsu then return end
  proximoJutsu = tempo + intervalo
  ultimoCast = tempo
  aguardando = true
  say(cfg.jutsu)
end)

-- Botao esquerdo alterna o macro, como no Travel System.
-- A cor segue o estilo do botao da custom (ativo/inativo).
cfg.ativo = cfg.ativo == true
summonMacro.setOn(cfg.ativo)
local function atualizarBotao()
  janela.ativar:setOn(cfg.ativo)
end
atualizarBotao()
janela.ativar.onClick = function()
  cfg.ativo = not cfg.ativo
  summonMacro.setOn(cfg.ativo)
  atualizarBotao()
end

onTextMessage(function(mode, texto)
  if not summonMacro:isOn() then return end
  local trecho = normalizar(cfg.mensagem)
  if trecho == "" or not aguardando then return end
  if normalizar(texto):find(trecho, 1, true) then
    confirmado = true
    aguardando = false
  end
end)
