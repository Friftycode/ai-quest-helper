local _, ns = ...
local call, clean, shown, opt = ns.call, ns.clean, ns.shown, ns.opt
local Q = C_QuestLog or {}

local function numLogEntries()
	if Q.GetNumQuestLogEntries then return (call(Q.GetNumQuestLogEntries)) or 0 end
	return (call(GetNumQuestLogEntries)) or 0
end

local function logEntry(i)
	if Q.GetInfo then
		local info = call(Q.GetInfo, i)
		if type(info) ~= "table" then return end
		return info.title, info.level, info.isHeader, info.questID, info.isHidden
	end
	local title, level, _, isHeader, _, _, _, questID = call(GetQuestLogTitle, i)
	return title, level, isHeader, questID, false
end

local function logIndexFor(questID)
	if Q.GetLogIndexForQuestID then return call(Q.GetLogIndexForQuestID, questID) end
	for i = 1, numLogEntries() do
		local _, _, isHeader, id = logEntry(i)
		if not isHeader and id == questID then return i end
	end
end

local function objectives(questID, logIndex)
	local lines = {}
	local objs = questID and Q.GetQuestObjectives and call(Q.GetQuestObjectives, questID)
	for _, o in ipairs(type(objs) == "table" and objs or {}) do
		if type(o) == "table" and o.text and o.text ~= "" then
			lines[#lines + 1] = (o.finished and "- [x] " or "- [ ] ") .. o.text
		end
	end
	if #lines == 0 and logIndex and GetNumQuestLeaderBoards then
		for i = 1, (call(GetNumQuestLeaderBoards, logIndex) or 0) do
			local text, _, done = call(GetQuestLogLeaderBoard, i, logIndex)
			if text and text ~= "" then lines[#lines + 1] = (done and "[x] " or "[ ] ") .. text end
		end
	end
	return lines
end

local function selectedQuestID()
	local d = QuestMapFrame and QuestMapFrame.DetailsFrame
	if d and shown(d) and type(d.questID) == "number" and d.questID ~= 0 then return d.questID end
	local id = Q.GetSelectedQuest and call(Q.GetSelectedQuest)
	if id and id ~= 0 then return id end
	local idx = call(GetQuestLogSelection)
	if idx and idx > 0 then
		local _, _, isHeader, qid = logEntry(idx)
		if not isHeader then return qid, idx end
	end
end

-- fromLog: rewards of a quest in the log; otherwise the open quest dialog.
function ns.rewardLines(fromLog, questID)
	local lines = {}
	local nChoice = call(fromLog and GetNumQuestLogChoices or GetNumQuestChoices, questID) or 0
	local nReward = call(fromLog and GetNumQuestLogRewards or GetNumQuestRewards, questID) or 0
	local getLink = fromLog and GetQuestLogItemLink or GetQuestItemLink
	local getInfo = fromLog and GetQuestLogRewardInfo or GetQuestItemInfo
	local function count(kind, i)
		local c
		if not fromLog then
			c = select(3, call(getInfo, kind, i))
		elseif kind == "choice" and GetQuestLogChoiceInfo then
			c = select(3, call(GetQuestLogChoiceInfo, i))
		else
			c = select(3, call(getInfo, i, questID))
		end
		return c
	end
	for i = 1, nReward do
		local l = ns.itemLine(call(getLink, "reward", i), count("reward", i))
		if l then lines[#lines + 1] = "- Reward: " .. l end
	end
	for i = 1, nChoice do
		local l = ns.itemLine(call(getLink, "choice", i), count("choice", i))
		if l then lines[#lines + 1] = "- Choose one: " .. l end
	end
	local xp = call(fromLog and GetQuestLogRewardXP or GetRewardXP, questID)
	if xp and xp > 0 then lines[#lines + 1] = "- XP: " .. xp end
	local m = ns.money(call(fromLog and GetQuestLogRewardMoney or GetRewardMoney, questID))
	if m then lines[#lines + 1] = "- Money: " .. m end
	if #lines == 0 then return nil end
	return table.concat(lines, "\n")
end

-- The text and reward APIs read the selected quest, so it is selected briefly.
local function withSelected(questID, logIndex, fn)
	local prevQuest = Q.SetSelectedQuest and questID and call(Q.GetSelectedQuest)
	if Q.SetSelectedQuest and questID then call(Q.SetSelectedQuest, questID) end
	local prevIdx = SelectQuestLogEntry and call(GetQuestLogSelection)
	if SelectQuestLogEntry then call(SelectQuestLogEntry, logIndex) end
	local a, b, c = fn()
	if prevQuest and prevQuest ~= 0 then call(Q.SetSelectedQuest, prevQuest) end
	if prevIdx and prevIdx > 0 then call(SelectQuestLogEntry, prevIdx) end
	return a, b, c
end

local function zoneHeaderOf(logIndex)
	for i = logIndex, 1, -1 do
		local t, _, isHeader = logEntry(i)
		if isHeader then return t end
	end
end

local function fromQuest(questID, logIndex)
	if not questID and not logIndex then return nil end
	logIndex = logIndex or logIndexFor(questID)
	if not logIndex then return nil end
	local title, level = logEntry(logIndex)

	local desc, obj, rewards = withSelected(questID, logIndex, function()
		local d, o = call(GetQuestLogQuestText)
		return d, o, ns.rewardLines(true, questID)
	end)

	local complete = questID and Q.IsComplete and call(Q.IsComplete, questID)
	local giver = questID and ns.db().givers[questID]
	local q = { "## Quest",
		"- Title: " .. (title or "?"),
		"- Quest ID: " .. (questID or "?"),
		"- Quest level: " .. ((level and level > 0) and level or "?"),
		"- Status: " .. (complete and "complete, ready to turn in" or "in progress"),
	}
	if giver then q[#q + 1] = "- Given by: " .. giver end
	local zone = zoneHeaderOf(logIndex)
	if zone then table.insert(q, 3, "- Quest log zone: " .. zone) end

	local qBlock, related = nil, {}
	if opt("exportQuestie") then qBlock, related = ns.questieBlock(questID) end

	local doc = ns.newDoc()
	doc.add(ns.aiHeader("quest"))
	doc.add(ns.playerContext())
	doc.add(table.concat(q, "\n"))
	local lines = objectives(questID, logIndex)
	if #lines > 0 then doc.add(table.concat(lines, "\n"), "### Objective progress ([x] = done)") end
	doc.add(obj, "### Objective text")
	doc.add(desc, "### Quest description")
	doc.add(rewards, "### Rewards (itemID | name | count)")
	doc.add(qBlock)
	if opt("exportBags") then doc.add(ns.bagContext(related)) end
	return doc.result()
end

function ns.fromSelectedQuest()
	return fromQuest(selectedQuestID())
end

function ns.fromWholeLog()
	local lines, n = {}, 0
	if not Q.GetInfo and ExpandQuestHeader then call(ExpandQuestHeader, 0) end
	for i = 1, numLogEntries() do
		local title, level, isHeader, questID, isHidden = logEntry(i)
		if isHeader then
			lines[#lines + 1] = "\n" .. (title or "?")
		elseif questID and questID > 0 and not isHidden then
			n = n + 1
			lines[#lines + 1] = string.format("%d | %s | %d", questID, title or "?", level or 0)
			for _, o in ipairs(objectives(questID, i)) do lines[#lines + 1] = "    " .. o end
		end
	end
	if n == 0 then return nil end
	table.insert(lines, 1, ns.aiHeader("quest log") .. "\n\n" .. ns.playerContext() .. "\n\n## Quest log")
	table.insert(lines, 2, "Format: questID | title | quest level, objectives indented ([x] = done)")
	lines[#lines + 1] = "\n(" .. n .. " quests)"
	return table.concat(lines, "\n") .. (opt("exportBags") and ("\n\n" .. ns.bagContext()) or "")
end

function ns.fromCompleted()
	local ids = {}
	if Q.GetAllCompletedQuestIDs then
		for _, id in ipairs(call(Q.GetAllCompletedQuestIDs) or {}) do ids[#ids + 1] = id end
	elseif GetQuestsCompleted then
		for id in pairs(call(GetQuestsCompleted) or {}) do ids[#ids + 1] = id end
	end
	table.sort(ids)
	if #ids == 0 then return nil end
	return "Completed quest IDs (" .. #ids .. "):\n" .. table.concat(ids, ", ")
end

-- Quests ready to turn in, the ones in the player's zone first.
function ns.readyQuests()
	local out = {}
	for i = 1, numLogEntries() do
		local title, level, isHeader, id = logEntry(i)
		if title and not isHeader and id then
			local done
			if Q.IsComplete then done = call(Q.IsComplete, id) end
			if done == nil then done = select(7, call(GetQuestLogTitle, i)) == 1 end
			if done then
				local e = ns.turnInOf(id) or {}
				e.id, e.title, e.level = id, title, level
				e.xp = call(GetQuestLogRewardXP, id)
				out[#out + 1] = e
			end
		end
	end
	table.sort(out, function(a, b)
		local ah, bh = a.here and true or false, b.here and true or false
		if ah ~= bh then return ah end
		return a.title < b.title
	end)
	return out
end

-- Remembers who offered each quest so the export can say who gave it.
local offered = {}
local events = CreateFrame("Frame")
events:RegisterEvent("QUEST_DETAIL")
events:RegisterEvent("QUEST_ACCEPTED")
events:SetScript("OnEvent", function(_, event, arg1, arg2)
	if event == "QUEST_DETAIL" then
		local qid = call(GetQuestID)
		if qid and qid > 0 and not call(UnitIsPlayer, "questnpc") then
			local name = clean(call(UnitName, "questnpc") or call(UnitName, "npc"))
			local id = ns.npcID("questnpc") or ns.npcID("npc")
			offered[qid] = name and (name .. (id and (" (ID " .. id .. ")") or "")) or nil
		end
	else
		local qid = arg2 or arg1
		if qid and offered[qid] then
			ns.db().givers[qid] = offered[qid]
			offered[qid] = nil
		end
	end
end)
