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
  return pfUITrades_DB
end

-- Task lists are account-wide so that characters can see each other's:
-- pfUITrades_Tasks[realm][character][profession] = { task, ... }
-- By realm alone: this server lets the two factions mail each other.
function M.AccountTasks()
  pfUITrades_Tasks = pfUITrades_Tasks or {}
  local realm = GetRealmName()
  pfUITrades_Tasks[realm] = pfUITrades_Tasks[realm] or {}

  -- lists from when they were also keyed by faction
  for _, faction in ipairs({ "Alliance", "Horde" }) do
    local old = realm .. "|" .. faction
    if pfUITrades_Tasks[old] then
      for name, professions in pairs(pfUITrades_Tasks[old]) do
        pfUITrades_Tasks[realm][name] = professions
      end
      pfUITrades_Tasks[old] = nil
    end
  end
  return pfUITrades_Tasks[realm]
end

function M.MyTasks()
  local account = M.AccountTasks()
  local me = UnitName("player")
  account[me] = account[me] or {}

  -- lists from when they were saved per character
  local db = M.DB()
  if db.tasks then
    for profession, tasks in pairs(db.tasks) do
      if table.getn(tasks) > 0 then account[me][profession] = tasks end
    end
    db.tasks = nil
  end
  return account[me]
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
  local tasks = M.MyTasks()
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

-- Adds crafts to any character's list on this realm; Altoholic's Recipes page uses it to queue
-- work for an alt. The task is shaped like AddSelected's, but what Altoholic doesn't record
-- (the spell ID, how many one craft makes) may be missing or guessed, so it is marked stale and
-- RefreshTasks fills it in from the recipe the next time that character opens the profession.
-- Until then a cast still finds it by name.
function M.QueueFor(character, profession, task, count)
  if not character or not profession or not task or not task.name then return end
  count = count or 1
  local tasks
  if character == UnitName("player") then
    tasks = M.Tasks(profession)
  else
    local account = M.AccountTasks()
    account[character] = account[character] or {}
    account[character][profession] = account[character][profession] or {}
    tasks = account[character][profession]
  end

  for _, existing in ipairs(tasks) do
    if existing.name == task.name then
      existing.count = existing.count + count
      Changed()
      return existing
    end
  end

  task.count = count
  task.reagents = task.reagents or {}
  task.stale = true
  table.insert(tasks, task)
  Changed()
  return task
end

-- How many crafts of a recipe are on a character's list, for Altoholic to show.
function M.QueuedFor(character, profession, name)
  local account = M.AccountTasks()
  local tasks = account[character] and account[character][profession]
  for _, task in ipairs(tasks or {}) do
    if task.name == name then return task.count end
  end
  return 0
end

-- Fills in the tasks QueueFor added from the recipe itself, once its window is open on the
-- character the list belongs to. Only rows already shown are read, so the player's filters and
-- folded headers stay as they are; a hidden recipe is filled in on a later opening.
function M.RefreshTasks(ctx)
  local window = M.windows[ctx]
  if not window or window.Linked() then return end
  local profession = window.Profession()
  local tasks = profession and M.MyTasks()[profession]
  if not tasks then return end
  local changed
  for _, task in ipairs(tasks) do
    if task.stale then
      local i = FindRow(window, task.name)
      local fresh = i and window.Read(i)
      if fresh then
        task.spell, task.icon, task.item = fresh.spell, fresh.icon, fresh.item
        task.made, task.reagents = fresh.made, fresh.reagents
        task.stale = nil
        changed = true
      end
    end
  end
  if changed then Changed() end
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
  M.MyTasks()[profession] = {}
  Changed()
end

function M.SelectTask(ctx, task)
  local window = M.windows[ctx]
  local i = FindRow(window, task.name)
  if i then window.Select(i) end
end

-- [ Materials ]

-- Reads the other characters of this realm, of either faction, since this server lets them mail
-- each other, plus this character's own mail. Their bags and banks only change while they're
-- logged in, and this character's are read live, so its bags and bank are skipped. rawget,
-- because reading a missing entry from Altoholic's database creates it.
local function ReadAltoholic(wanted)
  local found = {}
  if not M.Option("altoholic") then return found, "off" end

  local account = Altoholic and Altoholic.db and Altoholic.db.account
  local data = account and rawget(account, "data")
  if not data then return found, "missing" end

  local me = UnitName("player")
  local useMail = M.Option("mail")
  local alts = 0

  local function Add(id, name, source, amount)
    found[id] = found[id] or {}
    found[id][name] = found[id][name] or { name = name, bags = 0, bank = 0, mail = 0 }
    found[id][name][source] = found[id][name][source] + amount
  end

  local function ReadCharacter(name, c)
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

  for _, faction in pairs(data) do
    local realm = rawget(faction, GetRealmName())
    local chars = realm and rawget(realm, "char")
    for name, c in pairs(chars or {}) do ReadCharacter(name, c) end
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

-- What to take out of the bank for the tasks of every profession, as rows of id, name, take: only
-- what the bags are short of and the bank has.
function M.BankMaterials()
  local needed, order = {}, {}
  for profession in pairs(M.MyTasks()) do
    for _, row in ipairs(M.Plan(profession).materials) do
      if not needed[row.id] then
        needed[row.id] = { id = row.id, name = row.name, need = 0, bags = row.bags, bank = row.bank }
        table.insert(order, needed[row.id])
      end
      needed[row.id].need = needed[row.id].need + row.need
    end
  end

  local rows = {}
  for _, row in ipairs(order) do
    row.take = math.min(row.need - row.bags, row.bank)
    if row.take > 0 then table.insert(rows, row) end
  end
  table.sort(rows, function(a, b) return a.name < b.name end)
  return rows
end

local function BankReminder()
  if not M.Option("bankreminder") then return end
  local rows = M.BankMaterials()
  if table.getn(rows) == 0 then return end

  UIErrorsFrame:AddMessage("Your bank has materials for your task list", 1, .8, .2)
  Say("take these from the bank for your task list:")
  for _, row in ipairs(rows) do
    DEFAULT_CHAT_FRAME:AddMessage("  " .. row.take .. " x " .. row.name)
  end
end

-- What a character's tasks need overall, by item ID. What a task makes comes off what the
-- same profession's tasks need, as in M.Plan.
local function NetNeeds(professions)
  local needs = {}
  for _, tasks in pairs(professions) do
    local needed, planned = {}, {}
    for _, task in ipairs(tasks) do
      for _, reagent in ipairs(task.reagents) do
        needed[reagent.id] = needed[reagent.id] or { name = reagent.name, need = 0 }
        needed[reagent.id].need = needed[reagent.id].need + task.count * reagent.count
      end
      if task.item then
        planned[task.item] = (planned[task.item] or 0) + task.count * task.made
      end
    end
    for id, row in pairs(needed) do
      local need = row.need - (planned[id] or 0)
      if need > 0 then
        needs[id] = needs[id] or { name = row.name, need = 0 }
        needs[id].need = needs[id].need + need
      end
    end
  end
  return needs
end

-- What this character could send its alts for their task lists, as rows of alt, id, name, send.
-- It keeps what its own tasks need, each item is only offered once, and what an alt already
-- holds comes off, as far as Altoholic knows.
function M.AltMaterials()
  local account = M.AccountTasks()
  local me = UnitName("player")
  local mine = NetNeeds(M.MyTasks())

  local alts, wanted = {}, {}
  for name, professions in pairs(account) do
    if name ~= me then
      local needs = NetNeeds(professions)
      table.insert(alts, { name = name, needs = needs })
      for id in pairs(needs) do wanted[id] = true end
    end
  end
  table.sort(alts, function(a, b) return a.name < b.name end)

  local found = ReadAltoholic(wanted)
  local spare, rows = {}, {}
  for _, alt in ipairs(alts) do
    local sorted = {}
    for id, row in pairs(alt.needs) do
      table.insert(sorted, { id = id, name = row.name, need = row.need })
    end
    table.sort(sorted, function(a, b) return a.name < b.name end)

    for _, row in ipairs(sorted) do
      if not spare[row.id] then
        spare[row.id] = C_Item.GetItemCount(row.id, true) - (mine[row.id] and mine[row.id].need or 0)
      end
      local held = found[row.id] and found[row.id][alt.name]
      local short = row.need - (held and held.bags + held.bank + held.mail or 0)
      local send = math.min(short, spare[row.id])
      if send > 0 then
        spare[row.id] = spare[row.id] - send
        table.insert(rows, { alt = alt.name, id = row.id, name = row.name, send = send })
      end
    end
  end
  return rows
end

-- At the bank and the mailbox, the places these can be fetched and sent from.
local function AltReminder()
  if not M.Option("altreminder") then return end
  local rows = M.AltMaterials()
  if table.getn(rows) == 0 then return end

  UIErrorsFrame:AddMessage("You have materials for an alt's task list", 1, .8, .2)
  Say("you have materials for your alts' task lists:")
  for _, row in ipairs(rows) do
    DEFAULT_CHAT_FRAME:AddMessage("  " .. row.send .. " x " .. row.name .. " for " .. row.alt)
  end
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
  for profession, tasks in pairs(M.MyTasks()) do
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

-- Says what's next once a batch is over, since the next task needs another press.
local function AnnounceNext(profession)
  local plan = M.Plan(profession)
  if table.getn(plan.tasks) == 0 then
    Say("the task list is finished.")
    return
  end
  for _, task in ipairs(plan.tasks) do
    if plan.ready[task] > 0 then
      Say("batch finished. Press Start for " .. task.name .. ".")
      return
    end
  end
  Say("batch finished. The remaining tasks are waiting for materials.")
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
    local finished
    if running and running.task == task then
      running.left = running.left - 1
      if running.left <= 0 then
        EndBatch()
        finished = true
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
    if finished then AnnounceNext(profession) end
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

  elseif event == "PLAYER_LOGIN" then
    M.MyTasks() -- moves an old per-character list across, so alts can see it

  elseif event == "BANKFRAME_OPENED" then
    BankReminder()
    AltReminder()

  elseif event == "MAIL_SHOW" then
    AltReminder()

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

-- tasks queued from Altoholic are filled in once their profession's window has its rows
local refresher = CreateFrame("Frame")
refresher:RegisterEvent("TRADE_SKILL_SHOW")
refresher:RegisterEvent("TRADE_SKILL_UPDATE")
refresher:RegisterEvent("CRAFT_SHOW")
refresher:RegisterEvent("CRAFT_UPDATE")
refresher:SetScript("OnEvent", function()
  local ok, failure = pcall(M.RefreshTasks, string.find(event, "^CRAFT") and "Craft" or "TradeSkill")
  if not ok then Say("couldn't fill in a queued task: " .. tostring(failure)) end
end)
driver:RegisterEvent("PLAYER_LOGIN")
driver:RegisterEvent("BANKFRAME_OPENED")
driver:RegisterEvent("MAIL_SHOW")
driver:RegisterEvent("TRADE_SKILL_CLOSE")
driver:RegisterEvent("CRAFT_CLOSE")
