-- The panel beside the profession window and the pfUI settings. pfUI runs this in its own
-- environment, so its API (SkinButton, CreateBackdrop, T, C, ...) is available as globals.

pfUI:RegisterModule("trades", function()
  local M = pfUITrades

  local WIDTH, ROW = 320, 18
  local TASK_ROWS, MATERIAL_ROWS = 8, 10
  local COLUMNS = { "need", "bags", "bank", "mail", "alts" }
  local COLUMN_WIDTH = 30

  local STATUS = {
    bags = { .4, 1, .4 },
    bank = { 1, 1, .3 },
    elsewhere = { 1, .6, .2 },
    short = { 1, .3, .3 },
  }

  local panel, ctx, plan
  local toggles = {}

  pfUI:UpdateConfig("trades", nil, "altoholic", "1")
  pfUI:UpdateConfig("trades", nil, "mail", "1")

  local function Font(parent, justify)
    local text = parent:CreateFontString(nil, "OVERLAY")
    text:SetFont(pfUI.font_default, C.global.font_size, "OUTLINE")
    text:SetJustifyH(justify or "LEFT")
    return text
  end

  local serial = 0
  local function Button(parent, label, width, height, onClick)
    serial = serial + 1
    local button = CreateFrame("Button", "pfUITradesButton" .. serial, parent, "UIPanelButtonTemplate")
    button:SetWidth(width)
    button:SetHeight(height)
    button:SetText(label)
    SkinButton(button)
    button:SetScript("OnClick", onClick)
    return button
  end

  local function Arrow(parent, direction, onClick)
    serial = serial + 1
    local button = CreateFrame("Button", "pfUITradesButton" .. serial, parent)
    SkinArrowButton(button, direction, 13)
    button:SetScript("OnClick", onClick)
    return button
  end

  local function Scroller(name, rows, update)
    local scroll = CreateFrame("ScrollFrame", name, panel, "FauxScrollFrameTemplate")
    scroll:SetWidth(WIDTH - 32)
    scroll:SetHeight(rows * ROW)
    scroll:SetScript("OnVerticalScroll", function()
      FauxScrollFrame_OnVerticalScroll(ROW, update)
    end)
    SkinScrollbar(_G[name .. "ScrollBar"])
    return scroll
  end

  local function Profession()
    return ctx and M.windows[ctx].Profession()
  end

  -- [ Drawing ]

  local function DrawTasks()
    local tasks = plan.tasks
    local total = table.getn(tasks)
    FauxScrollFrame_Update(panel.taskScroll, total, TASK_ROWS, ROW)
    local offset = FauxScrollFrame_GetOffset(panel.taskScroll)

    for r, row in ipairs(panel.taskRows) do
      local task = tasks[r + offset]
      row.task = task
      if task then
        local ready = plan.ready[task]
        row.icon:SetTexture(task.icon)
        row.name:SetText(task.name)
        if ready >= task.count then
          row.count:SetText("|cff66ff66" .. task.count .. "|r")
        elseif ready > 0 then
          row.count:SetText("|cffffff4d" .. ready .. "/" .. task.count .. "|r")
        else
          row.count:SetText("|cffff4d4d" .. task.count .. "|r")
        end
        row:Show()
      else
        row:Hide()
      end
    end

    panel.empty:SetText(total == 0 and T["Select a recipe and press Add."] or "")
  end

  local function DrawMaterials()
    local materials = plan.materials
    FauxScrollFrame_Update(panel.materialScroll, table.getn(materials), MATERIAL_ROWS, ROW)
    local offset = FauxScrollFrame_GetOffset(panel.materialScroll)

    for r, row in ipairs(panel.materialRows) do
      local material = materials[r + offset]
      row.material = material
      if material then
        local color = STATUS[material.status]
        row.icon:SetTexture(material.icon)
        row.name:SetText(material.name)
        row.name:SetTextColor(color[1], color[2], color[3])
        for _, key in ipairs(COLUMNS) do
          local value = material[key]
          row[key]:SetText(value > 0 and tostring(value) or "|cff555555-|r")
        end
        row:Show()
      else
        row:Hide()
      end
    end

    if plan.alts == "off" then
      panel.source:SetText(T["Altoholic: turned off, alts not counted"])
    elseif plan.alts == "missing" then
      panel.source:SetText(T["Altoholic: not loaded, alts not counted"])
    else
      panel.source:SetText(string.format(T["Altoholic: %d alts on this realm and faction"], plan.alts))
    end
  end

  -- Sits right of the window and of anything else hanging off its edge, like Atlas-CFM's
  -- profession tabs or the Gromissingcrafts panel. Without pfUI's skin the frame is wider than
  -- its art, so there the Exit button shows where the art ends.
  local function Place()
    local frame = panel:GetParent()
    local skinned = frame.backdrop ~= nil
    local edge = frame:GetRight()
    if not edge then return end

    if not skinned then
      local exit = _G[ctx .. "CancelButton"]
      edge = exit and exit:GetRight() or edge
    end

    local children = { frame:GetChildren() }
    if GromissingcraftsWindow then table.insert(children, GromissingcraftsWindow) end
    for _, child in ipairs(children) do
      if child ~= panel and child:IsVisible() then
        local right = child:GetRight()
        if right and right > edge then edge = right end
      end
    end

    local x = edge - frame:GetRight() + 2
    if x ~= panel.x then
      panel.x = x
      panel:ClearAllPoints()
      panel:SetPoint("TOPLEFT", frame, "TOPRIGHT", x, skinned and 0 or -10)
    end
  end

  local function Refresh()
    if not panel or not panel:IsVisible() then return end
    local profession = Profession()
    if not profession then return end

    plan = M.Plan(profession)
    panel.title:SetText(profession)

    local readonly = M.windows[ctx].Linked()
    local running = M.running ~= nil
    panel.start:SetText(running and T["Stop"] or M.windows[ctx].batch and T["Start"] or T["Next"])
    if readonly or (not running and table.getn(plan.tasks) == 0) then
      panel.start:Disable()
    else
      panel.start:Enable()
    end
    if readonly then panel.add:Disable() else panel.add:Enable() end

    DrawTasks()
    DrawMaterials()
  end

  local function CountOnToggle()
    local toggle = toggles[ctx]
    local profession = Profession()
    if toggle and profession then
      local count = table.getn(M.Tasks(profession))
      toggle:SetText(count > 0 and T["Tasks"] .. " (" .. count .. ")" or T["Tasks"])
    end
  end

  M.onChange = function()
    CountOnToggle()
    Refresh()
  end

  -- [ Rows ]

  local function RowTooltip()
    local material = this.material
    if not material then return end
    GameTooltip:SetOwner(this, "ANCHOR_RIGHT")
    GameTooltip:SetText(material.name)
    GameTooltip:AddDoubleLine(T["Needed"], material.need, 1, 1, 1, 1, 1, 1)
    GameTooltip:AddDoubleLine(T["Bags"], material.bags, 1, 1, 1, 1, 1, 1)
    GameTooltip:AddDoubleLine(T["Bank"], material.bank, 1, 1, 1, 1, 1, 1)
    if material.mail > 0 then
      GameTooltip:AddDoubleLine(T["Mail"], material.mail, 1, 1, 1, 1, 1, 1)
    end
    for _, char in ipairs(material.chars) do
      local parts = {}
      if char.bags > 0 then table.insert(parts, T["Bags"] .. " " .. char.bags) end
      if char.bank > 0 then table.insert(parts, T["Bank"] .. " " .. char.bank) end
      if char.mail > 0 then table.insert(parts, T["Mail"] .. " " .. char.mail) end
      GameTooltip:AddDoubleLine(char.name, table.concat(parts, ", "), .2, 1, .8, 1, 1, 1)
    end
    GameTooltip:Show()
  end

  local function CreateTaskRow(i)
    local row = CreateFrame("Button", nil, panel)
    row:SetWidth(WIDTH - 32)
    row:SetHeight(ROW)
    row:SetPoint("TOPLEFT", panel.taskScroll, "TOPLEFT", 0, -(i - 1) * ROW)
    row:SetScript("OnClick", function() M.SelectTask(ctx, this.task) end)
    row:SetHighlightTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight")

    row.icon = row:CreateTexture(nil, "ARTWORK")
    row.icon:SetWidth(ROW - 4)
    row.icon:SetHeight(ROW - 4)
    row.icon:SetPoint("LEFT", 2, 0)
    row.icon:SetTexCoord(.08, .92, .08, .92)

    -- right to left: remove, down, up, plus, minus
    local remove = Button(row, "x", 14, 14, function()
      M.Remove(Profession(), this:GetParent().task)
    end)
    remove:SetPoint("RIGHT", 0, 0)
    local down = Arrow(row, "down", function() M.Move(Profession(), this:GetParent().task, 1) end)
    down:SetPoint("RIGHT", remove, "LEFT", -3, 0)
    local up = Arrow(row, "up", function() M.Move(Profession(), this:GetParent().task, -1) end)
    up:SetPoint("RIGHT", down, "LEFT", -3, 0)
    -- shift changes the count by 5
    local plus = Button(row, "+", 14, 14, function()
      M.Adjust(Profession(), this:GetParent().task, IsShiftKeyDown() and 5 or 1)
    end)
    plus:SetPoint("RIGHT", up, "LEFT", -3, 0)
    local minus = Button(row, "-", 14, 14, function()
      M.Adjust(Profession(), this:GetParent().task, IsShiftKeyDown() and -5 or -1)
    end)
    minus:SetPoint("RIGHT", plus, "LEFT", -3, 0)

    row.count = Font(row, "RIGHT")
    row.count:SetWidth(36)
    row.count:SetPoint("RIGHT", minus, "LEFT", -3, 0)

    row.name = Font(row)
    row.name:SetHeight(ROW)
    row.name:SetPoint("LEFT", row.icon, "RIGHT", 3, 0)
    row.name:SetPoint("RIGHT", row.count, "LEFT", -2, 0)
    return row
  end

  local function CreateMaterialRow(i)
    local row = CreateFrame("Button", nil, panel)
    row:SetWidth(WIDTH - 32)
    row:SetHeight(ROW)
    row:SetPoint("TOPLEFT", panel.materialScroll, "TOPLEFT", 0, -(i - 1) * ROW)
    row:SetScript("OnEnter", RowTooltip)
    row:SetScript("OnLeave", function() GameTooltip:Hide() end)
    row:SetHighlightTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight")

    row.icon = row:CreateTexture(nil, "ARTWORK")
    row.icon:SetWidth(ROW - 4)
    row.icon:SetHeight(ROW - 4)
    row.icon:SetPoint("LEFT", 2, 0)
    row.icon:SetTexCoord(.08, .92, .08, .92)

    for c, key in ipairs(COLUMNS) do
      row[key] = Font(row, "RIGHT")
      row[key]:SetWidth(COLUMN_WIDTH)
      row[key]:SetPoint("RIGHT", -(table.getn(COLUMNS) - c) * COLUMN_WIDTH, 0)
    end

    row.name = Font(row)
    row.name:SetHeight(ROW)
    row.name:SetPoint("LEFT", row.icon, "RIGHT", 3, 0)
    row.name:SetPoint("RIGHT", row.need, "LEFT", -2, 0)
    return row
  end

  -- [ Panel ]

  local function CreatePanel()
    panel = CreateFrame("Frame", "pfUITradesPanel", UIParent)
    panel:SetWidth(WIDTH)
    panel:SetHeight(440)
    CreateBackdrop(panel, nil, nil, .75)
    CreateBackdropShadow(panel)
    panel:Hide()

    -- other addons can open and close beside the window at any time
    panel.elapsed = 0
    panel:SetScript("OnUpdate", function()
      this.elapsed = this.elapsed + arg1
      if this.elapsed > .25 then
        this.elapsed = 0
        Place()
      end
    end)

    panel.title = Font(panel, "CENTER")
    panel.title:SetPoint("TOP", 0, -10)

    panel.add = Button(panel, T["Add"], 70, 20, function()
      local count = 1
      if ctx == "TradeSkill" and TradeSkillInputBox then
        count = math.max(TradeSkillInputBox:GetNumber(), 1)
      end
      M.AddSelected(ctx, count)
    end)
    panel.add:SetPoint("TOPLEFT", 8, -28)

    panel.start = Button(panel, T["Start"], 70, 20, function()
      if M.running then M.Stop() else M.Start(ctx) end
    end)
    panel.start:SetPoint("LEFT", panel.add, "RIGHT", 4, 0)

    panel.clear = Button(panel, T["Clear"], 70, 20, function() M.Clear(Profession()) end)
    panel.clear:SetPoint("TOPRIGHT", -8, -28)

    panel.taskScroll = Scroller("pfUITradesTaskScroll", TASK_ROWS, Refresh)
    panel.taskScroll:SetPoint("TOPLEFT", 8, -54)

    panel.empty = Font(panel)
    panel.empty:SetPoint("TOPLEFT", panel.taskScroll, "TOPLEFT", 2, -4)

    panel.taskRows = {}
    for i = 1, TASK_ROWS do panel.taskRows[i] = CreateTaskRow(i) end

    local header = CreateFrame("Frame", nil, panel)
    header:SetWidth(WIDTH - 32)
    header:SetHeight(ROW)
    header:SetPoint("TOPLEFT", panel.taskScroll, "BOTTOMLEFT", 0, -8)

    local label = Font(header)
    label:SetPoint("LEFT", 2, 0)
    label:SetText(T["Materials"])
    for c, key in ipairs(COLUMNS) do
      local column = Font(header, "RIGHT")
      column:SetWidth(COLUMN_WIDTH)
      column:SetPoint("RIGHT", -(table.getn(COLUMNS) - c) * COLUMN_WIDTH, 0)
      column:SetText(T[string.upper(string.sub(key, 1, 1)) .. string.sub(key, 2)])
      column:SetTextColor(.7, .7, .7)
    end

    panel.materialScroll = Scroller("pfUITradesMaterialScroll", MATERIAL_ROWS, Refresh)
    panel.materialScroll:SetPoint("TOPLEFT", header, "BOTTOMLEFT", 0, 0)

    panel.materialRows = {}
    for i = 1, MATERIAL_ROWS do panel.materialRows[i] = CreateMaterialRow(i) end

    panel.source = Font(panel)
    panel.source:SetPoint("BOTTOMLEFT", 10, 10)
    panel.source:SetTextColor(.7, .7, .7)
  end

  local function SetPanelShown(shown)
    M.DB().open = shown and 1 or nil
    if not shown then
      if panel then panel:Hide() end
      return
    end

    if not panel then CreatePanel() end
    panel:SetParent(_G[M.windows[ctx].frame])
    panel.x = nil
    panel:Show()
    Place()
    Refresh()
  end

  -- [ Window hooks ]

  -- Called when a window opens, and again when the profession in it changes.
  local function WindowShown(name)
    ctx = name
    local toggle = toggles[name]
    if not M.windows[name].Profession() then
      toggle:Hide()
      if panel then panel:Hide() end
      return
    end

    toggle:Show()
    CountOnToggle()
    if M.DB().open then SetPanelShown(true) end
  end

  local function Attach(name)
    local window = M.windows[name]
    local frame = _G[window.frame]
    local toggle = Button(frame, T["Tasks"], 70, 18, function()
      SetPanelShown(not (panel and panel:IsShown()))
    end)
    toggle:SetFrameLevel(frame:GetFrameLevel() + 5)
    toggles[name] = toggle

    -- Left of the close button, or of Atlas-CFM's button there, which can turn up after us
    local function Anchor()
      local atlas = _G[window.frame .. "AtlasButton"]
      local beside = atlas and atlas:IsVisible() and atlas or _G[window.frame .. "CloseButton"]
      if beside ~= toggle.beside then
        toggle.beside = beside
        toggle:ClearAllPoints()
        toggle:SetPoint("RIGHT", beside, "LEFT", -4, 0)
      end
    end
    Anchor()

    local elapsed = 0
    toggle:SetScript("OnUpdate", function()
      elapsed = elapsed + arg1
      if elapsed > .5 then
        elapsed = 0
        Anchor()
      end
    end)

    HookScript(frame, "OnShow", function() WindowShown(name) end)
    if frame:IsShown() then WindowShown(name) end
  end

  HookAddon("Blizzard_TradeSkillUI", function() Attach("TradeSkill") end)
  HookAddon("Blizzard_CraftUI", function() Attach("Craft") end)

  local events = CreateFrame("Frame")
  events:RegisterEvent("TRADE_SKILL_SHOW")
  events:RegisterEvent("CRAFT_SHOW")
  events:SetScript("OnEvent", function()
    local name = event == "CRAFT_SHOW" and "Craft" or "TradeSkill"
    if toggles[name] and _G[M.windows[name].frame]:IsShown() then WindowShown(name) end
  end)

  -- [ Settings ]

  local function Settings()
    if ATSWFrame or IsAddOnLoaded("AdvancedTradeSkillWindow2") then
      M.Say("AdvancedTradeSkillWindow2 is also enabled and uses the same window. Disable it to use the task list here.")
    end

    if not pfUI.gui then return end
    pfUI.gui.CreateGUIEntry(T["Thirdparty"], T["Trades"], function()
      pfUI.gui.CreateConfig(M.onChange, T["Count materials on alts with Altoholic"], C.trades, "altoholic", "checkbox")
      pfUI.gui.CreateConfig(M.onChange, T["Count materials in the mail"], C.trades, "mail", "checkbox")
    end)
  end

  local waiter = CreateFrame("Frame")
  waiter:RegisterEvent("VARIABLES_LOADED")
  waiter:SetScript("OnEvent", Settings)
end)
