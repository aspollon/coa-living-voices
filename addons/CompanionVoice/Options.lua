-- Companion Voice settings: Interface > AddOns > Companion Voice (also /cvoice). Three pages: what is spoken and how,
-- the lines never spoken, and voices chosen per person. Every change applies at once.

local CV = CompanionVoice
local n = 0
local function nm() n = n + 1; return "CompanionVoiceOpt" .. n end

local RACE_LABEL = { human = "Human", dwarf = "Dwarf", gnome = "Gnome", nightelf = "Night elf", draenei = "Draenei",
                     orc = "Orc", undead = "Forsaken", tauren = "Tauren", troll = "Troll", bloodelf = "Blood elf" }
local VOICE_ORDER = { "human_m", "human_f", "dwarf_m", "dwarf_f", "gnome_m", "gnome_f", "nightelf_m", "nightelf_f",
                      "draenei_m", "draenei_f", "orc_m", "orc_f", "undead_m", "undead_f", "tauren_m", "tauren_f",
                      "troll_m", "troll_f", "bloodelf_m", "bloodelf_f" }
local function voiceLabel(v)
  local race, sex = v:match("^(%a+)_(%a)$")
  return (RACE_LABEL[race] or race) .. (sex == "f" and " woman" or " man")
end
local function takeLetter(take) return (take:match("_(%a)$") or "?"):upper() end
local function voiceOf(take) return take:match("^r%d_(%a+_%a)_%a$") end
function CV.takeLabel(take) local v = voiceOf(take); return v and (voiceLabel(v) .. " " .. takeLetter(take)) or take end

-- ---------------------------------------------------------------- widgets
-- the usable width of an options page: the Interface window's panel area (a page itself may not be sized yet when it
-- first opens), less the margins and the scroll bar room; never wider than the page if the page knows its width
local function usable(p)
  local c = InterfaceOptionsFramePanelContainer
  local w = c and c:GetWidth() or 0
  local own = p:GetWidth() or 0
  if own >= 300 and (w < 300 or own < w) then w = own end
  if w < 300 then w = 420 end
  return math.floor(w - 44)
end

local function header(parent, text, y, big)
  local s = parent:CreateFontString(nil, "ARTWORK", big and "GameFontNormalLarge" or "GameFontNormal")
  s:SetPoint("TOPLEFT", 16, y); s:SetText(text); return s
end
local function note(parent, text, x, y, width)
  local s = parent:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
  s:SetPoint("TOPLEFT", x, y); s:SetWidth(width or (usable(parent) - x + 16)); s:SetJustifyH("LEFT"); s:SetText(text); return s
end
local function check(parent, label, tip, x, y, key)
  local name = nm()
  local b = CreateFrame("CheckButton", name, parent, "OptionsCheckButtonTemplate")
  b:SetPoint("TOPLEFT", x, y)
  _G[name .. "Text"]:SetText(label)
  b.tooltipText = tip
  b:SetScript("OnClick", function(self) CV.db[key] = self:GetChecked() and true or false; CV.apply() end)
  b.refresh = function() b:SetChecked(CV.db[key]) end
  return b
end
local function slider(parent, label, x, y, lo, hi, step, key, fmt, scale, width)
  local name = nm()
  local s = CreateFrame("Slider", name, parent, "OptionsSliderTemplate")
  s:SetPoint("TOPLEFT", x, y); s:SetWidth(width or 180)
  s:SetMinMaxValues(lo, hi); s:SetValueStep(step)
  _G[name .. "Low"]:SetText(fmt:format(lo)); _G[name .. "High"]:SetText(fmt:format(hi))
  local function show(v) _G[name .. "Text"]:SetText(label .. ": " .. fmt:format(v)) end
  s:SetScript("OnValueChanged", function(self, v)
    v = math.floor(v / step + 0.5) * step
    show(v); CV.db[key] = v / (scale or 1); CV.apply()
  end)
  s.refresh = function() local v = CV.db[key] * (scale or 1); s:SetValue(v); show(v) end
  return s
end
local function button(parent, label, x, y, width, onClick)
  local b = CreateFrame("Button", nm(), parent, "UIPanelButtonTemplate")
  b:SetPoint("TOPLEFT", x, y); b:SetWidth(width); b:SetHeight(22); b:SetText(label)
  b:SetScript("OnClick", onClick); return b
end
local function editbox(parent, x, y, width)
  local e = CreateFrame("EditBox", nm(), parent, "InputBoxTemplate")
  e:SetPoint("TOPLEFT", x, y); e:SetWidth(width); e:SetHeight(20); e:SetAutoFocus(false)
  e:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
  return e
end
local function dropdown(parent, x, y, width)
  local d = CreateFrame("Frame", nm(), parent, "UIDropDownMenuTemplate")
  d:SetPoint("TOPLEFT", x, y); UIDropDownMenu_SetWidth(d, width); return d
end

local function refreshAll(widgets) for _, w in ipairs(widgets) do if w.refresh then w.refresh() end end end

-- ---------------------------------------------------------------- page 1: what is spoken, and how
local main = CreateFrame("Frame", "CompanionVoiceOptions", UIParent)
main.name = "Companion Voice"
main:Hide()
local mainWidgets, status

local function buildMain()
  local p = main
  header(p, "Companion Voice", -16, true)
  note(p, "Party, whisper, say and yell spoken aloud on this computer, each speaker in a voice that fits their race. "
       .. "Channels are never spoken.", 16, -40)
  status = note(p, "", 16, -60)
  local w = {}
  local W = usable(p)
  local col = math.floor(W / 2) + 16                  -- the right column
  local sw = math.floor(W / 2) - 44                   -- a slider's width (its end labels hang past it a little)
  w[#w + 1] = check(p, "Speak chat aloud", "Everything below applies only while this is on.", 14, -80, "on")
  w[#w + 1] = check(p, "Party chat", nil, 34, -106, "party")
  w[#w + 1] = check(p, "Whispers to me", nil, col, -106, "whisper")
  w[#w + 1] = check(p, "Say (players)", nil, 34, -132, "say")
  w[#w + 1] = check(p, "Yell (players)", nil, col, -132, "yell")
  w[#w + 1] = check(p, "Say (NPCs)", "What creatures and NPCs say nearby.", 34, -158, "npcSay")
  w[#w + 1] = check(p, "Yell (NPCs)", "Boss and NPC yells.", col, -158, "npcYell")
  header(p, "Who is heard", -192)
  w[#w + 1] = check(p, "Group members", "People in your party.", 14, -210, "fromGroup")
  w[#w + 1] = check(p, "Friends", "People on your friends list.", col, -210, "fromFriends")
  w[#w + 1] = check(p, "Guild", "Members of your guild.", 14, -236, "fromGuild")
  w[#w + 1] = check(p, "Everyone else", "Anyone not in your group, friends or guild: strangers, and bots outside your group.", col, -236, "fromOthers")
  w[#w + 1] = check(p, "Only lines the realm labels", "On a realm running the Companion Voice server module, speak only the lines its companions "
                    .. "write for speaking. Has no effect elsewhere except to silence everything.", 14, -266, "companionsOnly")
  w[#w + 1] = check(p, "Quiet while I'm in combat", "Lines that arrive during a fight are not spoken.", 14, -292, "quietInCombat")
  header(p, "How it sounds", -328)
  w[#w + 1] = slider(p, "Volume", 24, -358, 0, 100, 5, "volume", "%d%%", 100, sw)
  w[#w + 1] = slider(p, "Speed", col + 10, -358, 0.7, 1.5, 0.05, "speed", "%.2f", nil, sw)
  w[#w + 1] = slider(p, "Longest line", 24, -408, 100, 500, 25, "maxChars", "%d", nil, sw)
  w[#w + 1] = slider(p, "Longest wait", col + 10, -408, 5, 60, 5, "maxWait", "%d s", nil, sw)
  button(p, "Test my voice", 16, -452, 130, function() SlashCmdList.COMPANIONVOICE("test") end)
  button(p, "Stop speaking", 156, -452, 130, function() CV.stop() end)
  mainWidgets = w
end

local function refreshMain()
  if not CV.db then return end
  if not mainWidgets then buildMain() end
  refreshAll(mainWidgets)
  local engine = CompanionVoiceEngine
  if engine then
    local st, why = engine.Status()
    status:SetText("Speech engine: " .. st .. (why and (" (" .. why .. ")") or ""))
  else
    status:SetText("|cffff6060The Living Voices client patch (LivingVoices.dll 0.5 or later) is missing: nothing can be spoken.|r")
  end
end
main:SetScript("OnShow", refreshMain)
main.refresh = refreshMain
main.default = function()
  for k, v in pairs(CV.DEFAULTS) do CV.db[k] = v end
  CV.apply(); refreshMain()
end

-- ---------------------------------------------------------------- page 2: lines never spoken
local lines = CreateFrame("Frame", "CompanionVoiceOptionsLines", UIParent)
lines.name = "Lines not spoken"; lines.parent = main.name
lines:Hide()
local linesEdit

local function linesText() return table.concat(CV.db.skip, "\n") end
local function saveLines()
  local list = {}
  for l in (linesEdit:GetText() .. "\n"):gmatch("(.-)\n") do
    l = l:gsub("^%s+", ""):gsub("%s+$", "")
    if l ~= "" then list[#list + 1] = l end
  end
  CV.db.skip = list
end

local function buildLines()
  local p = lines
  header(p, "Lines not spoken", -16, true)
  note(p, "One per line. A line of chat containing any of these is not spoken (capitals do not matter). Start one with ^ "
       .. "to match only the start of a line. It begins with the status messages stock playerbots whisper "
       .. "(\"Quest Incompleted: ...\"); on a realm running the Companion Voice server module, bots' unwritten lines are "
       .. "left silent anyway.", 16, -40)
  local box = CreateFrame("Frame", nil, p)
  local W = usable(p)
  box:SetPoint("TOPLEFT", 16, -100); box:SetWidth(W); box:SetHeight(320)
  box:SetBackdrop({ bgFile = "Interface\\Tooltips\\UI-Tooltip-Background", edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
                    tile = true, tileSize = 16, edgeSize = 16, insets = { left = 4, right = 4, top = 4, bottom = 4 } })
  box:SetBackdropColor(0, 0, 0, 0.6)
  local scroll = CreateFrame("ScrollFrame", nm(), box, "UIPanelScrollFrameTemplate")
  scroll:SetPoint("TOPLEFT", 8, -8); scroll:SetPoint("BOTTOMRIGHT", -28, 8)
  linesEdit = CreateFrame("EditBox", nm(), scroll)
  linesEdit:SetMultiLine(true); linesEdit:SetAutoFocus(false); linesEdit:SetFontObject(ChatFontNormal)
  linesEdit:SetWidth(W - 44); linesEdit:SetHeight(300)
  linesEdit:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
  linesEdit:SetScript("OnEditFocusLost", saveLines)
  scroll:SetScrollChild(linesEdit)
  box:EnableMouse(true); box:SetScript("OnMouseDown", function() linesEdit:SetFocus() end)
  button(p, "Restore the playerbots list", 16, -430, 200, function()
    CV.db.skip = {}; for i, e in ipairs(CV.DEFAULT_SKIP) do CV.db.skip[i] = e end
    linesEdit:SetText(linesText())
  end)
end

local function refreshLines()
  if not CV.db then return end
  if not linesEdit then buildLines() end
  linesEdit:SetText(linesText())
end
lines:SetScript("OnShow", refreshLines)
lines:SetScript("OnHide", function() if linesEdit then saveLines() end end)
lines.refresh = refreshLines
lines.okay = function() if linesEdit then saveLines() end end

-- ---------------------------------------------------------------- page 3: voices chosen per person
local voices = CreateFrame("Frame", "CompanionVoiceOptionsVoices", UIParent)
voices.name = "Voices"; voices.parent = main.name
voices:Hide()
local vName, vVoice, vTake, vVariant, vList
local sel = { voice = "human_m", take = nil, variant = 0 }

local function takesOf(v) return CompanionVoiceVoices.takes[v] or {} end
local function showSel()
  UIDropDownMenu_SetText(vVoice, voiceLabel(sel.voice))
  if not sel.take then sel.take = takesOf(sel.voice)[1] end
  UIDropDownMenu_SetText(vTake, sel.take and ("Take " .. takeLetter(sel.take)) or "-")
  vVariant.refresh()
end
local function listText()
  local names = {}
  for k in pairs(CV.db.voices) do names[#names + 1] = k end
  table.sort(names)
  if #names == 0 then return "Nobody has a chosen voice yet: each speaker's voice comes from their race and name." end
  local out = {}
  for i, k in ipairs(names) do
    if i > 18 then out[#out + 1] = ("... and %d more"):format(#names - 18); break end
    local v = CV.db.voices[k]
    out[#out + 1] = ("%s: %s, variant %d"):format(k:gsub("^%l", string.upper), CV.takeLabel(v.take), (v.variant or 0) + 1)
  end
  return table.concat(out, "\n")
end
local function loadName()
  local v = CV.db.voices[(vName:GetText() or ""):lower()]
  if v then sel.take, sel.variant, sel.voice = v.take, v.variant or 0, voiceOf(v.take) or sel.voice end
  showSel()
end

local function buildVoices()
  local p = voices
  header(p, "Voices", -16, true)
  note(p, "Give someone a voice of your choosing instead of the one drawn from their race and name. Type a name, pick a "
       .. "voice, take and variant, and save.", 16, -40)
  note(p, "Name", 20, -80, 100)
  vName = editbox(p, 24, -94, 160)
  vName:SetScript("OnEnterPressed", function(self) self:ClearFocus(); loadName() end)
  note(p, "Voice", 196, -80, 100)
  vVoice = dropdown(p, 178, -90, 110)
  UIDropDownMenu_Initialize(vVoice, function()
    for _, v in ipairs(VOICE_ORDER) do
      if CompanionVoiceVoices.takes[v] then
        local info = UIDropDownMenu_CreateInfo()
        info.text, info.arg1, info.checked = voiceLabel(v), v, sel.voice == v
        info.func = function(_, voice) sel.voice, sel.take = voice, nil; showSel() end
        UIDropDownMenu_AddButton(info)
      end
    end
  end)
  note(p, "Take", 196, -128, 60)
  vTake = dropdown(p, 178, -138, 70)
  UIDropDownMenu_Initialize(vTake, function()
    for _, t in ipairs(takesOf(sel.voice)) do
      local info = UIDropDownMenu_CreateInfo()
      info.text, info.arg1, info.checked = "Take " .. takeLetter(t), t, sel.take == t
      info.func = function(_, take) sel.take = take; showSel() end
      UIDropDownMenu_AddButton(info)
    end
  end)
  local name = nm()
  vVariant = CreateFrame("Slider", name, p, "OptionsSliderTemplate")
  vVariant:SetPoint("TOPLEFT", 24, -146); vVariant:SetWidth(130)
  vVariant:SetMinMaxValues(1, CompanionVoiceVoices.variants); vVariant:SetValueStep(1)
  _G[name .. "Low"]:SetText("1"); _G[name .. "High"]:SetText(tostring(CompanionVoiceVoices.variants))
  vVariant:SetScript("OnValueChanged", function(self, v)
    sel.variant = math.floor(v + 0.5) - 1; _G[name .. "Text"]:SetText("Variant: " .. (sel.variant + 1))
  end)
  vVariant.refresh = function() vVariant:SetValue(sel.variant + 1); _G[name .. "Text"]:SetText("Variant: " .. (sel.variant + 1)) end
  button(p, "Preview", 16, -190, 80, function()
    if sel.take then CV.preview(sel.take, sel.variant, "Right, that's the last of them. Shall we move on?") end
  end)
  button(p, "Save for name", 100, -190, 110, function()
    local who = (vName:GetText() or ""):gsub("%s", "")
    if who == "" or not sel.take then return CV.say("type a name first.") end
    CV.db.voices[who:lower()] = { take = sel.take, variant = sel.variant }
    vList:SetText(listText())
  end)
  button(p, "Use their own voice", 214, -190, 140, function()
    local who = (vName:GetText() or ""):gsub("%s", ""):lower()
    CV.db.voices[who] = nil
    vList:SetText(listText())
  end)
  header(p, "Chosen voices", -228)
  vList = note(p, "", 16, -248)
end

local function refreshVoices()
  if not CV.db then return end
  if not vList then buildVoices() end
  showSel(); vList:SetText(listText())
end
voices:SetScript("OnShow", refreshVoices)
voices.refresh = refreshVoices

InterfaceOptions_AddCategory(main)
InterfaceOptions_AddCategory(lines)
InterfaceOptions_AddCategory(voices)

function CV.openOptions()
  InterfaceOptionsFrame_OpenToCategory(main)   -- twice: the first call only opens the frame on 3.3.5
  InterfaceOptionsFrame_OpenToCategory(main)
end
