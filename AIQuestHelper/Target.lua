local _, ns = ...

local ICON = "Interface\\Icons\\Ability_Hunter_SniperShot"
-- A normal macro holds 255 characters; longer text cut off the /tm lines.
local MAX_MACRO = 255
-- Quests whose mobs are targeted but never marked:
-- Screecher Spirits, where the screechers and the spirits are the "adds".
local NO_MARK = { [3520] = true }

local btn, names, pending, dirty = nil, {}, false, true
local pnames = {}
local lastParty = false -- the last click was the right button (party)
local QDB, QEH, QLC, ZDB

local call = ns.call
local questIds, isDone = ns.questIds, ns.isQuestDone

local function modules()
	local m = ns.questieModules()
	QDB, QLC, QEH, ZDB = m.db, m.logCache, m.events, m.zones
	return QDB and QDB.GetQuest and ZDB
end

local function zoneOf(m)
	local guard = 0
	while m and guard < 5 do
		local info = C_Map and call(C_Map.GetMapInfo, m)
		if not info then return m end
		if info.mapType ~= 5 or not info.parentMapID or info.parentMapID == 0 then return m end
		m = info.parentMapID
		guard = guard + 1
	end
	return m
end

local zoneCache = {}
local function zoneOfArea(area)
	local z = zoneCache[area]
	if z == nil then
		local m = ns.uiMapOfArea(area)
		z = m and zoneOf(m) or false
		zoneCache[area] = z
	end
	return z or nil
end

local areaNameCache = {}
local function areaName(area)
	local n = areaNameCache[area]
	if n == nil then
		n = (C_Map and C_Map.GetAreaInfo and call(C_Map.GetAreaInfo, area)) or false
		areaNameCache[area] = n
	end
	return n or nil
end

local function spawnsInZone(spawns, zone)
	if type(spawns) ~= "table" then return false end
	local inInstance = IsInInstance and IsInInstance()
	local here = inInstance and GetRealZoneText and GetRealZoneText()
	for area, list in pairs(spawns) do
		if type(list) == "table" and #list > 0 then
			if zone and zoneOfArea(area) == zone then return true end
			if here and here ~= "" and areaName(area) == here then return true end
		end
	end
	return false
end

local function npcName(id)
	return QDB and call(QDB.QueryNPCSingle, id, "name")
end

local function collectAll()
	local out, seen = {}, {}
	local pMap = C_Map and call(C_Map.GetBestMapForUnit, "player")
	local zone = zoneOf(pMap)
	if not zone and not (IsInInstance and IsInInstance()) then return out end
	local curId
	local function add(name, quest)
		if type(name) ~= "string" or name == "" or seen[name] then return end
		seen[name] = true
		out[#out + 1] = { name = name, quest = quest, noMark = NO_MARK[curId] or false }
	end
	local haveQuestie = modules()

	for _, id in ipairs(questIds()) do
		curId = id
		if not isDone(id) then
			local quest = haveQuestie and call(QDB.GetQuest, id)
			local qname = (type(quest) == "table" and quest.name) or ("Quest " .. id)
			local found = false
			if type(quest) == "table" then
				for _, list in ipairs({ quest.Objectives or {}, quest.SpecialObjectives or {} }) do
					for _, o in pairs(list) do
						if type(o) == "table" and not o.Completed and type(o.spawnList) == "table" then
							for sid, sd in pairs(o.spawnList) do
								if type(sd) == "table" and sd.Name and spawnsInZone(sd.Spawns, zone) then
									found = true
									if npcName(sid) == sd.Name then add(sd.Name, qname) end
								end
							end
						end
					end
				end
			end
			if haveQuestie and not found then
				local obj = call(QDB.QueryQuestSingle, id, "objectives")
				if type(obj) == "table" then
					local function npc(n)
						if spawnsInZone(call(QDB.QueryNPCSingle, n, "spawns"), zone) then add(npcName(n), qname) end
					end
					for _, o in ipairs(obj[1] or {}) do if o[1] then npc(o[1]) end end
					for _, o in ipairs(obj[3] or {}) do
						for _, n in ipairs(o[1] and call(QDB.QueryItemSingle, o[1], "npcDrops") or {}) do npc(n) end
					end
					for _, o in ipairs(obj[5] or {}) do
						for _, n in ipairs(type(o[1]) == "table" and o[1] or {}) do npc(n) end
					end
				end
			end
			local objs = C_QuestLog and call(C_QuestLog.GetQuestObjectives, id)
			local K = type(AIQuestHelperDB) == "table" and AIQuestHelperDB.kills or {}
			local inside = IsInInstance and IsInInstance()
			if type(objs) == "table" then
				for _, o in ipairs(objs) do
					if type(o) == "table" and not o.finished and type(o.text) == "string" then
						local t = o.text:gsub("^%s*%d+%s*/%s*%d+%s*", "")
						local mob = t:match("^(.-) slain") or t:match("^(.-) drept")
						if mob and inside then add(mob, qname) end
						local e = mob and K[mob]
						if e and type(e.points) == "table" then
							for _, p in ipairs(e.points) do
								if zone and zoneOf(p[1]) == zone then add(mob, qname) break end
							end
						end
					end
				end
			end
		end
	end
	return out
end

local QC
local function collectParty()
	local out = collectAll()
	local seen = {}
	for _, e in ipairs(out) do seen[e.name] = true end
	if not modules() then return out end
	QC = QC or call(QuestieLoader.ImportModule, QuestieLoader, "QuestieComms")
	local logs = type(QC) == "table" and QC.remoteQuestLogs
	if type(logs) ~= "table" then return out end
	local zone = zoneOf(C_Map and call(C_Map.GetBestMapForUnit, "player"))
	if not zone and not (IsInInstance and IsInInstance()) then return out end
	local function add(name, label)
		if type(name) == "string" and name ~= "" and not seen[name] then
			seen[name] = true
			out[#out + 1] = { name = name, quest = label, noMark = false }
		end
	end
	for qid, players in pairs(logs) do
		local q = call(QDB.GetQuest, qid)
		local qname = type(q) == "table" and q.name or ("Quest " .. qid)
		for pname, objs in pairs(type(players) == "table" and players or {}) do
			local label = qname .. " (" .. tostring(pname):gsub("%-.*", "") .. ")"
			local function npc(n)
				if spawnsInZone(call(QDB.QueryNPCSingle, n, "spawns"), zone) then add(npcName(n), label) end
			end
			for _, o in pairs(type(objs) == "table" and objs or {}) do
				if type(o) == "table" and not o.finished and o.id then
					if o.type == "m" then npc(o.id)
					elseif o.type == "i" then
						for _, n in ipairs(call(QDB.QueryItemSingle, o.id, "npcDrops") or {}) do npc(n) end
					end
				end
			end
		end
	end
	return out
end

local function collect(party)
	local list = party and collectParty() or collectAll()
	local near = {}
	if C_NamePlate and C_NamePlate.GetNamePlates then
		for _, p in ipairs(call(C_NamePlate.GetNamePlates) or {}) do
			local u = p.namePlateUnitToken or (p.UnitFrame and p.UnitFrame.unit)
			local n = u and call(UnitName, u)
			if n and not call(UnitIsDead, u) then near[n] = (near[n] or 0) + 1 end
		end
	end
	for i, e in ipairs(list) do e.order = i end
	table.sort(list, function(a, b)
		local na, nb = near[a.name] or 0, near[b.name] or 0
		if (na > 0) ~= (nb > 0) then return na > 0 end
		if na ~= nb then return na > nb end
		return a.order < b.order
	end)
	return list
end

local function tail()
	local n = 0
	if (ns.opt("questTargetMarker") or 0) > 0 then n = n + 5 + 1 + 5 + 1 end
	return n
end

local function buildMacro(list)
	local lines = { "/cleartarget" }
	local used, len = {}, #lines[1]
	local first = true
	local function put(e)
		-- /targetexact, never /tar: /tar takes the closest partial match, so
		-- "Gordunni Brute" could pick a Gordunni Battlemaster that is not on a quest.
		local line = (first and "/targetexact " or "/targetexact [noexists] ") .. e.name .. "\n/cleartarget [dead]"
		if len + #line + 1 + tail() > MAX_MACRO then return false end
		lines[#lines + 1] = line
		len = len + #line + 1
		used[#used + 1] = e
		first = false
		return true
	end
	for _, e in ipairs(list) do if not e.noMark and not put(e) then break end end
	local m = ns.opt("questTargetMarker") or 0
	if m > 0 then
		lines[#lines + 1] = "/tm 0"
		lines[#lines + 1] = "/tm " .. m
	end
	for _, e in ipairs(list) do if e.noMark and not put(e) then break end end
	-- No fallback to the nearest enemy, ever: only quest mobs.
	return table.concat(lines, "\n"), used
end

local function fill(b, list, n)
	local text, used = buildMacro(list)
	b:SetAttribute("macrotext" .. n, #used > 0 and text or "")
	return used
end

local function apply()
	if not btn then return end
	if InCombatLockdown() then pending = true return end
	pending = false
	names = fill(btn, collect(false), 1)
	pnames = fill(btn, collect(true), 2)
	btn.names, btn.pnames = names, pnames
	local any = #names > 0 or #pnames > 0
	btn.icon:SetDesaturated(not any)
	btn.icon:SetAlpha(any and 1 or 0.5)
	btn.count:SetText(#names > 0 and #names or "")
end

local function savePosition(f)
	local point, _, rel, x, y = f:GetPoint(1)
	ns.db().targetButton = { point = point, rel = rel, x = x, y = y }
end

local BIND = "CLICK AIQuestHelperTarget:LeftButton"
local BINDP = "CLICK AIQuestHelperTarget:RightButton"
local promptMouse = "LeftButton" -- which click the keybind prompt is for

local function shortKey(k)
	if not k then return "" end
	k = k:gsub("SHIFT%-", "S-"):gsub("CTRL%-", "C-"):gsub("ALT%-", "A-")
	k = k:gsub("BUTTON", "M"):gsub("MOUSEWHEELUP", "MwU"):gsub("MOUSEWHEELDOWN", "MwD")
	k = k:gsub("NUMPAD", "N"):gsub("SPACE", "Spc")
	return k
end

local function updateHotkey()
	if btn then btn.hotkey:SetText(shortKey(GetBindingKey and GetBindingKey(BIND))) end
	if ns.onBindChange then ns.onBindChange() end
end

function ns.bindText(party)
	local k = GetBindingKey and GetBindingKey(party and BINDP or BIND)
	return k or "Not set"
end

local function flash(ok)
	if not btn then return end
	if ok == "tapped" then
		btn.flash:SetVertexColor(1, 0.55, 0)
	else
		btn.flash:SetVertexColor(ok and 0.2 or 1, ok and 1 or 0.2, 0.2)
	end
	btn.flashAnim:Stop()
	btn.flashAnim:Play()
end

local prompt
local MODS = { LSHIFT = 1, RSHIFT = 1, LCTRL = 1, RCTRL = 1, LALT = 1, RALT = 1, UNKNOWN = 1 }
local function setKey(key)
	if InCombatLockdown() then return end
	for _, k in ipairs({ GetBindingKey("CLICK AIQuestHelperTarget:" .. promptMouse) }) do SetBinding(k) end
	if key then SetBindingClick(key, "AIQuestHelperTarget", promptMouse) end
	SaveBindings(GetCurrentBindingSet())
	updateHotkey()
end
local function combo(key)
	local m = ""
	if IsAltKeyDown() then m = m .. "ALT-" end
	if IsControlKeyDown() then m = m .. "CTRL-" end
	if IsShiftKeyDown() then m = m .. "SHIFT-" end
	return m .. key
end
local function showPrompt(forName)
	if InCombatLockdown() then return end
	promptMouse = forName or "LeftButton"
	if not prompt then
		prompt = CreateFrame("Frame", "AIQuestHelperBindPrompt", UIParent, BackdropTemplateMixin and "BackdropTemplate" or nil)
		prompt:SetSize(260, 64)
		prompt:SetPoint("CENTER", 0, 120)
		prompt:SetFrameStrata("FULLSCREEN_DIALOG")
		if prompt.SetBackdrop then
			prompt:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8X8", edgeFile = "Interface\\Buttons\\WHITE8X8", edgeSize = 1 })
			prompt:SetBackdropColor(0.06, 0.06, 0.08, 0.95)
			prompt:SetBackdropBorderColor(1, 0.82, 0, 1)
		end
		local t = prompt:CreateFontString(nil, "OVERLAY", "GameFontNormal")
		t:SetPoint("TOP", 0, -12)
		prompt.title = t
		local s = prompt:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
		s:SetPoint("TOP", t, "BOTTOM", 0, -6)
		s:SetText("Esc: cancel   Backspace: remove key")
		prompt:EnableKeyboard(true)
		prompt:EnableMouse(true)
		if prompt.SetPropagateKeyboardInput then prompt:SetPropagateKeyboardInput(false) end
		prompt:SetScript("OnKeyDown", function(self, key)
			if MODS[key] then return end
			self:Hide()
			if key == "ESCAPE" then return end
			if key == "BACKSPACE" then setKey(nil) return end
			setKey(combo(key))
		end)
		prompt:SetScript("OnMouseDown", function(self, button)
			if button == "LeftButton" or button == "RightButton" then self:Hide() return end
			self:Hide()
			setKey(combo((button == "MiddleButton") and "BUTTON3" or button:upper()))
		end)
		prompt:SetScript("OnMouseWheel", function(self, d)
			self:Hide()
			setKey(combo(d > 0 and "MOUSEWHEELUP" or "MOUSEWHEELDOWN"))
		end)
	end
	prompt.title:SetText(promptMouse == "RightButton" and "Press a key for Party" or "Press a key for Mine")
	prompt:Show()
end
ns.showBindPrompt = function(party) showPrompt(party and "RightButton" or "LeftButton") end

function ns.tarJudge()
	ns.tarJudged = true
	local got = UnitExists("target") and not UnitIsDead("target")
	if got then
		local n = UnitName("target")
		got = false
		for _, e in ipairs(lastParty and pnames or names) do if e.name == n then got = true break end end
	end
	local tapped = got and UnitIsTapDenied and UnitIsTapDenied("target")
	if got and not tapped and ns.opt("questTargetFullHp") then
		local hp, max = UnitHealth("target"), UnitHealthMax("target")
		local mine = UnitThreatSituation and UnitThreatSituation("player", "target") ~= nil
		if max and max > 0 and hp < max and not mine then tapped = true end
	end
	ns.tarLast = not UnitExists("target") and "no target found"
		or not got and ("target is not a quest mob here: " .. tostring(UnitName("target")))
		or tapped and "tagged or already hurt"
		or "ok"
	if tapped then flash("tapped") else flash(got) end
	if UnitExists("target") and not UnitIsDead("target") and PlaySound then pcall(PlaySound, 8959) end
end

local function build()
	local f = CreateFrame("Button", "AIQuestHelperTarget", UIParent, "SecureActionButtonTemplate")
	f:SetSize(40, 40)
	f.names, f.pnames = {}, {}
	local mover = f
	local p = ns.db().targetButton
	if type(p) == "table" and p.point then
		f:SetPoint(p.point, UIParent, p.rel or p.point, p.x or 0, p.y or 0)
	else
		f:SetPoint("TOP", UIParent, "TOP", 0, -220)
	end
	f:SetClampedToScreen(true)
	f:SetMovable(true)
	local down = GetCVarBool and GetCVarBool("ActionButtonUseKeyDown")
	if down then f:RegisterForClicks("LeftButtonDown", "RightButtonDown") else f:RegisterForClicks("LeftButtonUp", "RightButtonUp") end
	f:SetAttribute("type", "macro")
	f:SetAttribute("macrotext1", "")
	f:SetAttribute("macrotext2", "")
	f:RegisterForDrag("LeftButton")
	f:SetScript("OnDragStart", function(self)
		if not ns.opt("questTargetLock") and not InCombatLockdown() then self.moving = true; mover:StartMoving() end
	end)
	f:SetScript("OnDragStop", function(self)
		if self.moving and not InCombatLockdown() then mover:StopMovingOrSizing(); savePosition(mover) end
		C_Timer.After(0, function() self.moving = nil end)
	end)

	local icon = f:CreateTexture(nil, "BACKGROUND")
	icon:SetAllPoints()
	icon:SetTexture(ICON)
	icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)
	f.icon = icon
	f:SetNormalTexture("Interface\\Buttons\\UI-Quickslot2")
	local nt = f:GetNormalTexture()
	nt:ClearAllPoints()
	nt:SetPoint("TOPLEFT", -15, 15)
	nt:SetPoint("BOTTOMRIGHT", 15, -15)
	f:SetPushedTexture("Interface\\Buttons\\UI-Quickslot-Depress")
	f:SetHighlightTexture("Interface\\Buttons\\ButtonHilight-Square", "ADD")

	local fl = f:CreateTexture(nil, "OVERLAY")
	fl:SetTexture("Interface\\Buttons\\UI-ActionButton-Border")
	fl:SetBlendMode("ADD")
	fl:SetPoint("CENTER")
	fl:SetSize(72, 72)
	fl:SetAlpha(0)
	f.flash = fl
	local ag = fl:CreateAnimationGroup()
	local a1 = ag:CreateAnimation("Alpha"); a1:SetFromAlpha(0); a1:SetToAlpha(1); a1:SetDuration(0.08); a1:SetOrder(1)
	local a2 = ag:CreateAnimation("Alpha"); a2:SetFromAlpha(1); a2:SetToAlpha(0); a2:SetDuration(0.45); a2:SetOrder(2)
	f.flashAnim = ag

	local hotkey = f:CreateFontString(nil, "OVERLAY", "NumberFontNormalSmallGray")
	hotkey:SetPoint("TOPRIGHT", -2, -3)
	hotkey:SetJustifyH("RIGHT")
	f.hotkey = hotkey
	local count = f:CreateFontString(nil, "OVERLAY", "NumberFontNormal")
	count:SetPoint("BOTTOMRIGHT", -2, 2)
	f.count = count

	f:SetScript("PreClick", function(self, button)
		self.party = button == "RightButton"
		if self.moving and not InCombatLockdown() then self:SetAttribute("type", nil) end
	end)
	f:SetScript("PostClick", function(self)
		if not InCombatLockdown() and self:GetAttribute("type") == nil then
			self:SetAttribute("type", "macro")
			return
		end
		if not InCombatLockdown() then
			self:SetButtonState("PUSHED")
			C_Timer.After(0.12, function() if not InCombatLockdown() then self:SetButtonState("NORMAL") end end)
		end
		-- The new target is not always set yet when PostClick runs: judge it when
		-- PLAYER_TARGET_CHANGED arrives, or a moment later if the target is the same.
		lastParty = self.party and true or false
		ns.tarClickTime = GetTime()
		ns.tarJudged = false
		C_Timer.After(0.15, function() if not ns.tarJudged then ns.tarJudge() end end)
		if ns.snapshot then C_Timer.After(0.3, ns.snapshot) end
	end)

	f:SetScript("OnEnter", function(self)
		GameTooltip:SetOwner(self, "ANCHOR_BOTTOM")
		GameTooltip:AddLine("Target quest mob")
		if #self.names == 0 then
			GameTooltip:AddLine("No unfinished quest mobs in this zone.", 1, 1, 1, true)
		else
			for _, e in ipairs(self.names) do GameTooltip:AddDoubleLine(e.name, e.quest, 1, 1, 1, 0.6, 0.6, 0.6) end
		end
		if IsInGroup and IsInGroup() and #self.pnames > #self.names then
			GameTooltip:AddLine("Party: " .. #self.pnames .. " mobs", 0.6, 0.8, 1)
		end
		local k, kp = GetBindingKey(BIND), GetBindingKey(BINDP)
		GameTooltip:AddLine(" ")
		GameTooltip:AddLine("Left" .. (k and (" / " .. k) or "") .. ": mine  ·  Right" .. (kp and (" / " .. kp) or "") .. ": party", 0.6, 0.6, 0.6)
		GameTooltip:AddLine("Green ok  ·  Orange taken  ·  Red none", 0.6, 0.6, 0.6)
		GameTooltip:Show()
	end)
	f:SetScript("OnLeave", function() GameTooltip:Hide() end)
	return f
end

function ns.refreshTarget()
	if InCombatLockdown() then pending = true return end
	local on = ns.opt("questTarget")
	if on and not btn then btn = build() end
	if btn then
		btn:SetShown(on and true or false)
		if on then apply(); updateHotkey() end
	end
end

function ns.targetDebug()
	local list = collect()
	local text = buildMacro(list)
	DEFAULT_CHAT_FRAME:AddMessage("AI Quest Helper /tar: " .. #list .. " mob(s) in this zone, macro " .. #text .. "/" .. MAX_MACRO .. " characters. Last click: " .. tostring(ns.tarLast or "none"))
	for line in text:gmatch("[^\n]+") do DEFAULT_CHAT_FRAME:AddMessage("  " .. line) end
end

local ev = CreateFrame("Frame")
local wait = 0
ev:RegisterEvent("PLAYER_LOGIN")
ev:RegisterEvent("PLAYER_ENTERING_WORLD")
ev:RegisterEvent("ZONE_CHANGED_NEW_AREA")
ev:RegisterEvent("ZONE_CHANGED")
ev:RegisterEvent("ZONE_CHANGED_INDOORS")
ev:RegisterEvent("BAG_UPDATE_DELAYED")
ev:RegisterEvent("NAME_PLATE_UNIT_ADDED")
ev:RegisterEvent("QUEST_LOG_UPDATE")
ev:RegisterEvent("PLAYER_REGEN_ENABLED")
ev:RegisterEvent("UPDATE_BINDINGS")
ev:RegisterEvent("PLAYER_TARGET_CHANGED")
ev:RegisterEvent("GROUP_ROSTER_UPDATE")
C_Timer.NewTicker(10, function() if IsInGroup and IsInGroup() and not dirty then wait = 1; dirty = true end end)
ev:SetScript("OnEvent", function(_, event)
	if event == "PLAYER_LOGIN" then
		local old = GetBindingKey and GetBindingKey("CLICK AIQuestHelperTargetParty:LeftButton")
		if old and not InCombatLockdown() then
			SetBinding(old)
			if not GetBindingKey(BINDP) then SetBindingClick(old, "AIQuestHelperTarget", "RightButton") end
			SaveBindings(GetCurrentBindingSet())
		end
		C_Timer.After(5, function() pcall(ns.refreshTarget) end)
		return
	end
	if event == "UPDATE_BINDINGS" then updateHotkey() return end
	if event == "PLAYER_TARGET_CHANGED" then
		if ns.tarClickTime and not ns.tarJudged and UnitExists("target") and GetTime() - ns.tarClickTime < 0.5 then ns.tarJudge() end
		return
	end
	if event == "PLAYER_REGEN_ENABLED" and not pending then return end
	if not dirty then wait = 1 end
	dirty = true
end)
ev:SetScript("OnUpdate", function(_, elapsed)
	if not dirty then return end
	wait = wait - elapsed
	if wait > 0 or InCombatLockdown() then return end
	dirty = false
	pcall(ns.refreshTarget)
end)
