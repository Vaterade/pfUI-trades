-- Tasks, materials and the crafting queue. Nothing here touches the panel: ui.lua sets
-- pfUITrades.onChange and redraws from pfUITrades.Plan().
--
-- A task is { name, spell, count, icon, item, made, reagents = { { id, name, icon, count }, ... } }.
-- Reagents are stored on the task, so materials can be worked out while the recipe's window
-- isn't the one the client has data for. count is the number of crafts left, not of items.

pfUITrades = {}
local M = pfUITrades

local function Say(text)
  DEFAULT_CHAT_FRAME:AddMessage("|cff33ffccpf|cffffffffUI|cffaaaaaa Trades:|r " .. text)
end
M.Say = Say

local function Changed()
  if M.onChange then M.onChange() end
end

local function ItemID(link)
  if not link then return nil end
  local _, _, id = string.find(link, "item:(%d+)")
  return tonumber(id)
end

-- The client can give a reagent's ID before it has the item's name and icon. Asking by ID also
-- makes it fetch them.
local function ReadReagent(id, name, icon, count)
  if not id then return nil end
  return {
    id = id,
    name = name or C_Item.GetItemNameByID(id) or ("item:" .. id),
    icon = icon or C_Item.GetItemIconByID(id),
    count = count,
  }
end

function M.DB()
  pfUITrades_DB = pfUITrades_DB or {}
  pfUITrades_DB.tasks = pfUITrades_DB.tasks or {}
  return pfUITrades_DB
end

function M.Option(key)
  local config = pfUI_config and pfUI_config.trades
  return not config or config[key] ~= "0"
end

-- [ The two profession windows ]

-- The subclass and slot dropdowns and collapsed headers change which rows exist, and so every
-- row's index. The window's search box and checkboxes don't: they only filter the drawing.
local function ActiveFilter(getFilter, options)
  for i = 0, table.getn(options) do
    if getFilter(i) then return i end
  end
end

local TradeSkill = { batch = true, frame = "TradeSkillFrame" }

function TradeSkill.Profession()
  local name = GetTradeSkillLine()
  if name and name ~= "UNKNOWN" then return name end
end

function TradeSkill.Linked()
  return IsTradeSkillLinked()
end

function TradeSkill.Count() return GetNumTradeSkills() end
function TradeSkill.Selected() return GetTradeSkillSelectionIndex() end
function TradeSkill.Info(i) return GetTradeSkillInfo(i) end
function TradeSkill.Cast(i, count) DoTradeSkill(i, count) end

function TradeSkill.Select(i)
  TradeSkillFrame_SetSelection(i)
  TradeSkillFrame_Update()
end

function TradeSkill.Read(i)
  local name, kind = GetTradeSkillInfo(i)
  if not name or kind == "header" then return nil end

  local _, _, spell = string.find(GetTradeSkillRecipeLink(i) or "", "|Henchant:(%d+)")
  local task = {
    name = name,
    spell = tonumber(spell),
    icon = GetTradeSkillIcon(i),
    item = GetTradeSkillItemID(i),
    made = GetTradeSkillNumMade(i) or 1,
    reagents = {},
  }
  for r = 1, GetTradeSkillNumReagents(i) do
    local rname, ricon, rcount = GetTradeSkillReagentInfo(i, r)
    local reagent = ReadReagent(GetTradeSkillReagentItemID(i, r), rname, ricon, rcount)
    if not reagent then return nil end
    table.insert(task.reagents, reagent)
  end
  return task
end

function TradeSkill.WithFullList(run)
  local subclass = ActiveFilter(GetTradeSkillSubClassFilter, { GetTradeSkillSubClasses() })
  local invslot = ActiveFilter(GetTradeSkillInvSlotFilter, { GetTradeSkillInvSlots() })
  local selected = GetTradeSkillSelectionIndex()
  local collapsed

  if subclass and subclass > 0 then SetTradeSkillSubClassFilter(0, 1, 1) end
  if invslot and invslot > 0 then SetTradeSkillInvSlotFilter(0, 1, 1) end

  for i = 1, GetNumTradeSkills() do
    local name, kind, _, expanded = GetTradeSkillInfo(i)
    if kind == "header" and not expanded then
      collapsed = collapsed or {}
      collapsed[name] = true
    end
  end
  if collapsed then ExpandTradeSkillSubClass(0) end

  -- whatever run does, the player's list has to come back
  local ok, failure = pcall(run)

  if collapsed then
    for i = GetNumTradeSkills(), 1, -1 do
      local name, kind = GetTradeSkillInfo(i)
      if kind == "header" and collapsed[name] then CollapseTradeSkillSubClass(i) end
    end
  end
  if invslot and invslot > 0 then SetTradeSkillInvSlotFilter(invslot, 1, 1) end
  if subclass and subclass > 0 then SetTradeSkillSubClassFilter(subclass, 1, 1) end
  if collapsed or (invslot and invslot > 0) or (subclass and subclass > 0) then
    SelectTradeSkill(selected)
  end

  if not ok then error(failure, 0) end
end

-- Enchanting. A craft waits for the player to click the item it goes on, so it can't repeat or
-- run unattended; Start casts one and the task counts down when the enchant goes off.
local Craft = { batch = false, frame = "CraftFrame" }

function Craft.Profession()
  return (GetCraftDisplaySkillLine()) -- nil for Beast Training, which has no materials
end

function Craft.Linked()
  return IsCraftLinked()
end

function Craft.Count() return GetNumCrafts() end
function Craft.Selected() return GetCraftSelectionIndex() end
function Craft.Cast(i) DoCraft(i) end

function Craft.Info(i)
  local name, _, kind, available, expanded = GetCraftInfo(i)
  return name, kind, available, expanded
end

function Craft.Select(i)
  CraftFrame_SetSelection(i)
  CraftFrame_Update()
end

function Craft.Read(i)
  local name, _, kind = GetCraftInfo(i)
  if not name or kind == "header" then return nil end

  local task = { name = name, spell = GetCraftSpellID(i), icon = GetCraftIcon(i), made = 0, reagents = {} }
  for r = 1, GetCraftNumReagents(i) do
    local rname, ricon, rcount = GetCraftReagentInfo(i, r)
    local reagent = ReadReagent(GetCraftReagentItemID(i, r), rname, ricon, rcount)
    if not reagent then return nil end
    table.insert(task.reagents, reagent)
  end
  return task
end

function Craft.WithFullList(run)
  local selected = GetCraftSelectionIndex()
  local collapsed

  for i = 1, GetNumCrafts() do
    local name, _, kind, _, expanded = GetCraftInfo(i)
    if kind == "header" and not expanded then
      collapsed = collapsed or {}
      collapsed[name] = true
    end
  end
  if collapsed then ExpandCraftSkillLine(0) end

  local ok, failure = pcall(run)

  if collapsed then
    for i = GetNumCrafts(), 1, -1 do
      local name, _, kind = GetCraftInfo(i)
      if kind == "header" and collapsed[name] then CollapseCraftSkillLine(i) end
    end
    SelectCraft(selected)
  end

  if not ok then error(failure, 0) end
end

M.windows = { TradeSkill = TradeSkill, Craft = Craft }

local function FindRow(window, name)
  for i = 1, window.Count() do
    local rowName, kind = window.Info(i)
    if rowName == name and kind ~= "header" then return i end
  end
end

-- Calls found(index) with the recipe's current row, widening the list only if it's hidden.
local function WithRecipe(window, name, found)
  local i = FindRow(window, name)
  if i then
    found(i)
    return true
  end

  local done
  window.WithFullList(function()
    i = FindRow(window, name)
    if i then
      found(i)
      done = true
    end
  end)
  return done
end

-- [ Tasks ]

function M.Tasks(profession)
  local tasks = M.DB().tasks
  tasks[profession] = tasks[profession] or {}
  return tasks[profession]
end

function M.AddSelected(ctx, count)
  local window = M.windows[ctx]
  local profession = window.Profession()
  local selected = window.Selected()
  if not profession or not selected or selected == 0 then return end

  local task = window.Read(selected)
  if not task then
    local name, kind = window.Info(selected)
    if name and kind ~= "header" then Say("couldn't read the materials for " .. name .. ", try again.") end
    return
  end

  local tasks = M.Tasks(profession)
  for _, existing in ipairs(tasks) do
    if existing.name == task.name then
      existing.count = existing.count + count
      Changed()
      return existing
    end
  end

  task.count = count
  table.insert(tasks, task)
  Changed()
  return task
end

local function Position(tasks, task)
  for i, candidate in ipairs(tasks) do
    if candidate == task then return i end
  end
end

function M.Remove(profession, task)
  local tasks = M.Tasks(profession)
  local i = Position(tasks, task)
  if not i then return end
  if M.running and M.running.task == task then M.Stop() end
  table.remove(tasks, i)
  Changed()
end

function M.Adjust(profession, task, delta)
  task.count = task.count + delta
  if task.count <= 0 then
    M.Remove(profession, task)
  else
    Changed()
  end
end

function M.Move(profession, task, delta)
  local tasks = M.Tasks(profession)
  local i = Position(tasks, task)
  local j = i and i + delta
  if not j or j < 1 or j > table.getn(tasks) then return end
  tasks[i], tasks[j] = tasks[j], tasks[i]
  Changed()
end

function M.Clear(profession)
  if M.running and M.running.profession == profession then M.Stop() end
  M.DB().tasks[profession] = {}
  Changed()
end

function M.SelectTask(ctx, task)
  local window = M.windows[ctx]
  local i = FindRow(window, task.name)
  if i then window.Select(i) end
end

-- [ Materials ]

-- Reads the other characters of this realm and faction, who are the ones that can mail things
-- here, plus this character's own mail. Their bags and banks only change while they're logged
-- in, and this character's are read live, so its bags and bank are skipped. rawget, because
-- reading a missing entry from Altoholic's database creates it.
local function ReadAltoholic(wanted)
  local found = {}
  if not M.Option("altoholic") then return found, "off" end

  local account = Altoholic and Altoholic.db and Altoholic.db.account
  local data = account and rawget(account, "data")
  if not data then return found, "missing" end

  local faction = rawget(data, UnitFactionGroup("player"))
  local realm = faction and rawget(faction, GetRealmName())
  local chars = realm and rawget(realm, "char")
  if not chars then return found, 0 end

  local me = UnitName("player")
  local useMail = M.Option("mail")
  local alts = 0

  local function Add(id, name, source, amount)
    found[id] = found[id] or {}
    found[id][name] = found[id][name] or { name = name, bags = 0, bank = 0, mail = 0 }
    found[id][name][source] = found[id][name][source] + amount
  end

  for name, c in pairs(chars) do
    if name ~= me then
      alts = alts + 1
      for bagName, b in pairs(rawget(c, "bag") or {}) do
        local isBank = bagName == "Bag100"
        local number = tonumber(string.sub(bagName, 4))
        if number and number > 4 then isBank = true end
        local ids, counts = b.ids or {}, b.counts or {}
        -- only up to size: a smaller bag swapped in leaves old entries past its end
        for slot = 1, b.size or 0 do
          local id = ids[slot]
          if id and wanted[id] then
            local amount = counts[slot]
            if not amount or amount == 0 then amount = 1 end
            Add(id, name, isBank and "bank" or "bags", amount)
          end
        end
      end
    end

    if useMail then
      for _, mail in pairs(rawget(c, "mail") or {}) do
        local id = ItemID(mail.link)
        if id and wanted[id] then
          local amount = mail.count
          if not amount or amount == 0 then amount = 1 end
          Add(id, name, "mail", amount)
        end
      end
    end
  end

  return found, alts
end

-- Works out, for a profession's tasks in order:
--   plan.ready[task]  crafts possible from what's in the bags now. Each task uses up what
--                     earlier tasks leave and can use what they make, so bars smelted by one
--                     task count towards the next.
--   plan.materials    a row per reagent still needed: need, bags, bank, mail, alts (totals),
--                     chars (per-alt breakdown), status bags/bank/elsewhere/short.
--   plan.alts         number of alts read, or "off"/"missing"
function M.Plan(profession)
  local tasks = M.Tasks(profession)
  local plan = { tasks = tasks, ready = {}, materials = {} }
  local stock, needed, planned, order = {}, {}, {}, {}

  local function InBags(id)
    if not stock[id] then stock[id] = C_Item.GetItemCount(id) end
    return stock[id]
  end

  for _, task in ipairs(tasks) do
    local ready = task.count
    for _, reagent in ipairs(task.reagents) do
      ready = math.min(ready, math.floor(InBags(reagent.id) / reagent.count))
      if not needed[reagent.id] then
        needed[reagent.id] = { id = reagent.id, name = reagent.name, icon = reagent.icon, need = 0 }
        table.insert(order, needed[reagent.id])
      end
      needed[reagent.id].need = needed[reagent.id].need + task.count * reagent.count
    end
    for _, reagent in ipairs(task.reagents) do
      stock[reagent.id] = stock[reagent.id] - ready * reagent.count
    end
    if task.item then
      stock[task.item] = InBags(task.item) + ready * task.made
      planned[task.item] = (planned[task.item] or 0) + task.count * task.made
    end
    plan.ready[task] = ready
  end

  local wanted = {}
  for _, row in ipairs(order) do wanted[row.id] = true end
  local found
  found, plan.alts = ReadAltoholic(wanted)

  local me = UnitName("player")
  for _, row in ipairs(order) do
    row.need = row.need - (planned[row.id] or 0)
    if row.need > 0 then
      row.bags = C_Item.GetItemCount(row.id)
      row.bank = C_Item.GetItemCount(row.id, true) - row.bags
      row.mail, row.alts, row.chars = 0, 0, {}

      for name, entry in pairs(found[row.id] or {}) do
        if name == me then
          row.mail = entry.mail
        else
          row.alts = row.alts + entry.bags + entry.bank + entry.mail
          table.insert(row.chars, entry)
        end
      end
      table.sort(row.chars, function(a, b) return a.name < b.name end)

      if row.bags >= row.need then
        row.status = "bags"
      elseif row.bags + row.bank >= row.need then
        row.status = "bank"
      elseif row.bags + row.bank + row.mail + row.alts >= row.need then
        row.status = "elsewhere"
      else
        row.status = "short"
      end
      table.insert(plan.materials, row)
    end
  end

  return plan
end

-- [ Crafting ]

-- The client only starts these casts from a click. Called from OnUpdate, DoTradeSkill reaches
-- the client's cast function (nampower_debug.log shows "Attempt cast") but no cast begins and no
-- event says so, however long it has been since the last cast. So a queue can't run by itself:
-- each press of Start casts one batch, and M.Start has to be called from a click.
local CONFIRM_TIME = 3 -- how long the next cast has to show up before the batch counts as over

local function EndBatch()
  M.running, M.confirm = nil, nil
end

-- Casts the first task that has its materials, as many as it can.
function M.Start(ctx)
  local window = M.windows[ctx]
  local profession = window.Profession()
  if not profession or window.Linked() then return end

  local plan = M.Plan(profession)

  for _, task in ipairs(plan.tasks) do
    local count = plan.ready[task]
    if count > 0 then
      -- before the cast: the client can turn it down from inside the call
      if window.batch then
        M.running = { ctx = ctx, profession = profession, task = task, left = count }
        M.confirm = GetTime() + CONFIRM_TIME
        M.driver:Show()
      else
        EndBatch()
      end

      local started = WithRecipe(window, task.name, function(i) window.Cast(i, count) end)
      if started then
        Changed()
        return true
      end
      EndBatch()
      Say("this character doesn't know " .. task.name .. ", skipping it.")
    end
  end

  EndBatch()
  if table.getn(plan.tasks) == 0 then
    Say("the task list is finished.")
  else
    Say("the remaining tasks are waiting for materials.")
  end
  Changed()
end

-- Stops the batch in progress.
function M.Stop()
  local wasCasting = M.running
  EndBatch()
  if wasCasting then SpellStopCasting() end
  Changed()
end

-- By spell ID, which two recipes can't share. By name only if no task has that ID, in case a
-- recipe's cast turns out to be a different spell from the one its link names.
local function FindTask(spell, name)
  local byName, byNameProfession
  for profession, tasks in pairs(M.DB().tasks) do
    for _, task in ipairs(tasks) do
      if task.spell == spell then return profession, task end
      if task.name == name then byName, byNameProfession = task, profession end
    end
  end
  return byNameProfession, byName
end

local function IsRunning(spell, name)
  local running = M.running
  return running and (running.task.spell == spell or running.task.name == name)
end

-- [ Events ]

local driver = CreateFrame("Frame")
M.driver = driver
driver:Hide() -- OnUpdate only runs while waiting for a cast to show up

driver:SetScript("OnUpdate", function()
  if M.confirm and GetTime() >= M.confirm then
    -- the cast never began or the batch quietly ended early, so don't sit on Stop
    EndBatch()
    Changed()
  end
  if not M.confirm then driver:Hide() end
end)

-- Any successful cast of a listed recipe counts, so crafting with the window's own Create
-- button also works through the list. Args: unit, castGUID, spellID, spellName.
driver:SetScript("OnEvent", function()
  if event == "UNIT_SPELLCAST_SUCCEEDED" then
    if arg1 ~= "player" then return end
    if IsRunning(arg3, arg4) then M.confirm = nil end

    local profession, task = FindTask(arg3, arg4)
    if not profession then return end

    local running = M.running
    if running and running.task == task then
      running.left = running.left - 1
      if running.left <= 0 then
        EndBatch()
      else
        -- the next craft of the batch should follow at once
        M.confirm = GetTime() + CONFIRM_TIME
        driver:Show()
      end
    end

    -- not M.Adjust: that stops the batch when a task is removed, and this one is just done
    task.count = task.count - 1
    if task.count <= 0 then
      local tasks = M.Tasks(profession)
      local i = Position(tasks, task)
      if i then table.remove(tasks, i) end
    end
    Changed()

  elseif event == "UNIT_SPELLCAST_START" then
    if arg1 == "player" and IsRunning(arg3, arg4) then M.confirm = nil end

  elseif event == "UNIT_SPELLCAST_FAILED_QUIET" then
    -- the client was still busy, and says nothing to the player about it
    if arg1 == "player" and M.confirm and IsRunning(arg3, arg4) then
      EndBatch()
      Say("the client was busy, press Start again.")
      Changed()
    end

  elseif event == "UNIT_SPELLCAST_FAILED" or event == "UNIT_SPELLCAST_INTERRUPTED" then
    -- the client has told the player why, if it needed to
    if arg1 == "player" and IsRunning(arg3, arg4) then
      EndBatch()
      Changed()
    end

  elseif event == "TRADE_SKILL_CLOSE" or event == "CRAFT_CLOSE" then
    -- the batch carries on, but the button that would stop it is gone
    EndBatch()
    Changed()

  else
    Changed()
  end
end)

driver:RegisterEvent("UNIT_SPELLCAST_SUCCEEDED")
driver:RegisterEvent("UNIT_SPELLCAST_START")
driver:RegisterEvent("UNIT_SPELLCAST_FAILED")
driver:RegisterEvent("UNIT_SPELLCAST_FAILED_QUIET")
driver:RegisterEvent("UNIT_SPELLCAST_INTERRUPTED")
driver:RegisterEvent("BAG_UPDATE_DELAYED")
driver:RegisterEvent("TRADE_SKILL_CLOSE")
driver:RegisterEvent("CRAFT_CLOSE")
