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
  pfUI:UpdateConfig("trades", nil, "bankreminder", "1")
  pfUI:UpdateConfig("trades", nil, "altreminder", "1")

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
    FauxScrollFrame_SetOffset(scroll, 0) -- nil until first scrolled, otherwise
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
      panel.source:SetText(string.format(T["Altoholic: %d alts on this realm"], plan.alts))
    end
  end

  local missing -- the Missing Recipes panel, made when first opened

  -- Puts p right of the window and of anything else hanging off its edge, like Atlas-CFM's
  -- profession tabs. ignore is left out of that, so the queue panel stays next to the window
  -- and the missing panel goes beyond it. Without pfUI's skin the frame is wider than its art,
  -- so there the Exit button shows where the art ends.
  local function PlaceBeside(p, ignore)
    local frame = p:GetParent()
    local skinned = frame.backdrop ~= nil
    local edge = frame:GetRight()
    if not edge then return end

    if not skinned then
      local exit = _G[ctx .. "CancelButton"]
      edge = exit and exit:GetRight() or edge
    end

    for _, child in ipairs({ frame:GetChildren() }) do
      if child ~= p and child ~= ignore and child:IsVisible() then
        local right = child:GetRight()
        if right and right > edge then edge = right end
      end
    end

    local x = edge - frame:GetRight() + 2
    if x ~= p.x then
      p.x = x
      p:ClearAllPoints()
      p:SetPoint("TOPLEFT", frame, "TOPRIGHT", x, skinned and 0 or -10)
    end
  end

  local function Place() PlaceBeside(panel, missing) end

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
      toggle:SetText(count > 0 and T["Queue"] .. " (" .. count .. ")" or T["Queue"])
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
    panel:EnableMouse(true) -- so clicks on its background don't go through to the world
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

  -- Moves a frame and everything in it up, keeping their order among themselves.
  local function Raise(frame, by)
    frame:SetFrameLevel(frame:GetFrameLevel() + by)
    for _, child in ipairs({ frame:GetChildren() }) do Raise(child, by) end
  end

  local function SetPanelShown(shown)
    M.DB().open = shown and 1 or nil
    if not shown then
      if panel then panel:Hide() end
      return
    end

    if not panel then CreatePanel() end
    -- Levels don't follow a new parent reliably, and the buttons have to sit above anything
    -- else hanging off the window.
    local frame = _G[M.windows[ctx].frame]
    panel:SetParent(frame)
    Raise(panel, frame:GetFrameLevel() + 10 - panel:GetFrameLevel())
    panel.x = nil
    panel:Show()
    Place()
    Refresh()
  end

  -- [ Missing recipes ]
  -- The recipes of the open profession the character doesn't know (core.lua's M.Missing),
  -- with where each is learned or found. With pfQuest loaded, the recipe item's tooltip names
  -- its vendors, mobs and chests and their zones, and a click shows them on the map.

  M.T = T
  -- the panel is as tall as the queue panel; the list starts under the button and ends a
  -- margin above the bottom, and is narrow enough for its scroll bar to stay inside
  local MISSING_HEIGHT, MISSING_TOP, MISSING_BOTTOM = 440, 54, 14
  local MISSING_ROWS = math.floor((MISSING_HEIGHT - MISSING_TOP - MISSING_BOTTOM) / ROW)
  local MISSING_WIDTH = WIDTH - 36
  local missingList, missingShown, missingRank = {}, {}, 0
  local learnableOnly

  local function MissingRowTooltip()
    local m = this.entry
    if not m then return end
    GameTooltip:SetOwner(this, "ANCHOR_RIGHT")
    GameTooltip:SetText(m.name)
    GameTooltip:AddLine(T["Skill"] .. ": " .. m.skill, .8, .8, .8)
    if m.level then GameTooltip:AddLine(string.format(T["Requires level %d"], m.level), .8, .8, .8) end
    if m.how ~= "" then GameTooltip:AddLine(m.how, .2, 1, .8, true) end
    local reagents = M.ParseReagents(m.reagents)
    if table.getn(reagents) > 0 then
      GameTooltip:AddLine(" ")
      GameTooltip:AddLine(T["Reagents"] .. ":", 1, 1, 1)
      for _, r in ipairs(reagents) do
        local name = (C_Item and C_Item.GetItemNameByID and C_Item.GetItemNameByID(r[1])) or GetItemInfo(r[1]) or ("item:" .. r[1])
        GameTooltip:AddLine(r[2] .. " x " .. name, .8, .8, .8)
      end
    end
    GameTooltip:Show()
  end

  -- the recipe item: its tooltip, where it comes from, and a click to map that
  local function RecipeTooltip()
    local r = this.recipe
    if not r then return end
    GameTooltip:SetOwner(this, "ANCHOR_RIGHT")
    GameTooltip:SetHyperlink("item:" .. r.id .. ":0:0:0")
    GameTooltip:AddLine(" ")
    if not M.AddItemSources(GameTooltip, r.id) then
      GameTooltip:AddLine(r.sources, .2, 1, .8, true)
    end
    if M.HasItemSources() then GameTooltip:AddLine(T["Click to show on the map"], .2, 1, .8) end
    GameTooltip:Show()
  end

  local function RecipeClick()
    local r = this.recipe
    if not r then return end
    if IsShiftKeyDown() and ChatFrameEditBox and ChatFrameEditBox:IsVisible() then
      local _, link = GetItemInfo(r.id)
      if link then ChatFrameEditBox:Insert(link) end
    elseif not M.ShowItemOnMap(r.id) and M.HasItemSources() then
      M.Say(T["pfQuest knows no place for this recipe"])
    end
  end

  local function CreateMissingRow(i)
    local row = CreateFrame("Button", nil, missing)
    row:SetWidth(MISSING_WIDTH)
    row:SetHeight(ROW)
    row:SetPoint("TOPLEFT", missing.scroll, "TOPLEFT", 0, -(i - 1) * ROW)
    row:SetScript("OnEnter", MissingRowTooltip)
    row:SetScript("OnLeave", function() GameTooltip:Hide() end)
    row:SetHighlightTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight")

    row.skill = Font(row, "RIGHT")
    row.skill:SetWidth(28)
    row.skill:SetPoint("LEFT", 0, 0)

    row.icon = row:CreateTexture(nil, "ARTWORK")
    row.icon:SetWidth(ROW - 4)
    row.icon:SetHeight(ROW - 4)
    row.icon:SetPoint("LEFT", row.skill, "RIGHT", 4, 0)
    row.icon:SetTexCoord(.08, .92, .08, .92)

    row.recipe = CreateFrame("Button", nil, row)
    row.recipe:SetWidth(ROW - 2)
    row.recipe:SetHeight(ROW - 2)
    row.recipe:SetPoint("RIGHT", -2, 0)
    row.recipe.icon = row.recipe:CreateTexture(nil, "ARTWORK")
    row.recipe.icon:SetAllPoints(row.recipe)
    row.recipe.icon:SetTexCoord(.08, .92, .08, .92)
    CreateBackdrop(row.recipe)
    row.recipe:SetScript("OnEnter", RecipeTooltip)
    row.recipe:SetScript("OnLeave", function() GameTooltip:Hide() end)
    row.recipe:SetScript("OnClick", RecipeClick)

    row.name = Font(row)
    row.name:SetHeight(ROW)
    row.name:SetPoint("LEFT", row.icon, "RIGHT", 4, 0)
    row.name:SetPoint("RIGHT", row.recipe, "LEFT", -4, 0)
    return row
  end

  local function DrawMissing()
    if not missing or not missing:IsVisible() then return end
    local total = table.getn(missingShown)
    FauxScrollFrame_Update(missing.scroll, total, MISSING_ROWS, ROW)
    local offset = FauxScrollFrame_GetOffset(missing.scroll)
    for i = 1, MISSING_ROWS do
      local row, m = missing.rows[i], missingShown[offset + i]
      row.entry = m
      if m then
        row.skill:SetText((m.skill <= missingRank and "|cff00ff00" or "|cffff5555") .. m.skill)
        local _, _, quality, _, _, _, _, _, icon = GetItemInfo(m.item or 0)
        row.icon:SetTexture(icon or (m.item and C_Item and C_Item.GetItemIconByID and C_Item.GetItemIconByID(m.item))
          or "Interface\\Icons\\Trade_Engraving")
        local hex = "|cffffffff"
        if quality then
          local _, _, _, h = GetItemQualityColor(quality)
          hex = h or hex
        end
        row.name:SetText(hex .. m.name)
        local r = m.recipes[1]
        row.recipe.recipe = r
        if r then
          local _, _, _, _, _, _, _, _, ricon = GetItemInfo(r.id)
          row.recipe.icon:SetTexture(ricon or (C_Item and C_Item.GetItemIconByID and C_Item.GetItemIconByID(r.id))
            or "Interface\\Icons\\INV_Misc_QuestionMark")
          row.recipe:Show()
        else
          row.recipe:Hide()
        end
        row:Show()
      else
        row:Hide()
      end
    end
    missing.empty:SetText(total == 0 and (table.getn(missingList) == 0 and T["Every recipe is known."]
      or T["Nothing more to learn at this skill."]) or "")
  end

  -- reads the window again and redraws
  local function RefreshMissing()
    if not missing or not missing:IsVisible() then return end
    local list, total, rank = M.Missing(ctx)
    missingList, missingRank = list or {}, rank or 0
    missingShown = missingList
    if learnableOnly then
      missingShown = {}
      for _, m in ipairs(missingList) do
        if m.skill <= missingRank then table.insert(missingShown, m) end
      end
    end
    if list then
      missing.title:SetText(string.format(T["Missing Recipes: %d of %d"], table.getn(list), total))
    else
      missing.title:SetText(T["Missing Recipes"])
      missing.empty:SetText(T["No recipe list for this profession."])
    end
    missing.only:SetText(learnableOnly and T["All recipes"] or T["Learnable now"])
    FauxScrollFrame_SetOffset(missing.scroll, 0)
    DrawMissing()
  end

  local function CreateMissingPanel()
    missing = CreateFrame("Frame", "pfUITradesMissingPanel", UIParent)
    missing:SetWidth(WIDTH)
    missing:SetHeight(MISSING_HEIGHT)
    missing:EnableMouse(true)
    CreateBackdrop(missing, nil, nil, .75)
    CreateBackdropShadow(missing)
    missing:Hide()

    missing.elapsed = 0
    missing:SetScript("OnUpdate", function()
      this.elapsed = this.elapsed + arg1
      if this.elapsed > .25 then
        this.elapsed = 0
        PlaceBeside(missing)
      end
    end)

    missing.title = Font(missing, "CENTER")
    missing.title:SetPoint("TOP", 0, -10)

    missing.only = Button(missing, T["Learnable now"], 100, 20, function()
      learnableOnly = not learnableOnly
      RefreshMissing()
    end)
    missing.only:SetPoint("TOPLEFT", 8, -28)

    missing.scroll = CreateFrame("ScrollFrame", "pfUITradesMissingScroll", missing, "FauxScrollFrameTemplate")
    missing.scroll:SetWidth(MISSING_WIDTH)
    missing.scroll:SetHeight(MISSING_ROWS * ROW)
    missing.scroll:SetPoint("TOPLEFT", 8, -MISSING_TOP)
    FauxScrollFrame_SetOffset(missing.scroll, 0)
    missing.scroll:SetScript("OnVerticalScroll", function()
      FauxScrollFrame_OnVerticalScroll(ROW, DrawMissing)
    end)
    SkinScrollbar(_G["pfUITradesMissingScrollScrollBar"])

    missing.empty = Font(missing)
    missing.empty:SetPoint("TOPLEFT", missing.scroll, "TOPLEFT", 2, -4)
    missing.empty:SetTextColor(.7, .7, .7)

    missing.rows = {}
    for i = 1, MISSING_ROWS do missing.rows[i] = CreateMissingRow(i) end
  end

  local function SetMissingShown(shown)
    M.DB().missingOpen = shown and 1 or nil
    if not shown then
      if missing then missing:Hide() end
      return
    end
    if not missing then CreateMissingPanel() end
    local frame = _G[M.windows[ctx].frame]
    missing:SetParent(frame)
    Raise(missing, frame:GetFrameLevel() + 10 - missing:GetFrameLevel())
    missing.x = nil
    missing:Show()
    PlaceBeside(missing)
    RefreshMissing()
  end

  -- a recipe learned while the window is open: "You have learned how to create a new item: %s."
  local learned = ERR_LEARN_RECIPE_S and ("^" .. string.gsub(string.gsub(ERR_LEARN_RECIPE_S,
    "([%.%(%)%-%+%*%?%[%]%^%$])", "%%%1"), "%%s", ".+"))
  local learnEvents = CreateFrame("Frame")
  learnEvents:RegisterEvent("CHAT_MSG_SYSTEM")
  learnEvents:SetScript("OnEvent", function()
    if learned and arg1 and string.find(arg1, learned) then RefreshMissing() end
  end)

  -- [ Window hooks ]

  -- Called when a window opens, and again when the profession in it changes.
  local function WindowShown(name)
    ctx = name
    local toggle = toggles[name]
    if not M.windows[name].Profession() then
      toggle:Hide()
      if toggles[name .. "Missing"] then toggles[name .. "Missing"]:Hide() end
      if panel then panel:Hide() end
      if missing then missing:Hide() end
      return
    end

    toggle:Show()
    CountOnToggle()
    if M.DB().open then SetPanelShown(true) end
    local missingToggle = toggles[name .. "Missing"]
    if missingToggle then
      if M.EnglishProfession(M.windows[name].Profession()) then missingToggle:Show() else missingToggle:Hide() end
    end
    if M.DB().missingOpen then SetMissingShown(true) end
  end

  local function Attach(name)
    local window = M.windows[name]
    local frame = _G[window.frame]

    -- TradeSkillFrame_Update does arithmetic on this offset, but TradeSkillFrame_Show only sets
    -- it after showing the window, so anything that redraws the list before then is an error.
    local list = _G[name .. "ListScrollFrame"]
    if list and not FauxScrollFrame_GetOffset(list) then FauxScrollFrame_SetOffset(list, 0) end

    -- Queue and Missing take turns: opening one closes the other
    local toggle = Button(frame, T["Queue"], 70, 22, function()
      local open = not (panel and panel:IsShown())
      if open then SetMissingShown(false) end
      SetPanelShown(open)
    end)
    -- Bottom left of the recipe details, level with Aegis_Exchange's button in the bottom right
    toggle:SetPoint("BOTTOMLEFT", _G[name .. "DetailScrollFrame"], "BOTTOMLEFT", 8, 8)
    toggle:SetFrameLevel(frame:GetFrameLevel() + 5)
    toggles[name] = toggle

    -- the recipes this character hasn't learned yet, beside the queue
    local missingToggle = Button(frame, T["Missing"], 70, 22, function()
      local open = not (missing and missing:IsShown())
      if open then SetPanelShown(false) end
      SetMissingShown(open)
    end)
    missingToggle:SetPoint("LEFT", toggle, "RIGHT", 4, 0)
    missingToggle:SetFrameLevel(frame:GetFrameLevel() + 5)
    toggles[name .. "Missing"] = missingToggle

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
    pfUI.gui.CreateGUIEntry(T["Thirdparty"], T["Tradeskill"], function()
      pfUI.gui.CreateConfig(M.onChange, T["Count materials on alts with Altoholic"], C.trades, "altoholic", "checkbox")
      pfUI.gui.CreateConfig(M.onChange, T["Count materials in the mail"], C.trades, "mail", "checkbox")
      pfUI.gui.CreateConfig(M.onChange, T["Remind me at the bank to take materials"], C.trades, "bankreminder", "checkbox")
      pfUI.gui.CreateConfig(M.onChange, T["Remind me at the bank and mailbox about materials for alts"], C.trades, "altreminder", "checkbox")
    end)
  end

  local waiter = CreateFrame("Frame")
  waiter:RegisterEvent("VARIABLES_LOADED")
  waiter:SetScript("OnEvent", Settings)
end)
