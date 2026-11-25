local _, ns = ...
local opt = ns.opt

local texts = {}   -- [plate] = fontstring

local function healthBar(plate)
	local uf = plate.UnitFrame
	return uf and (uf.healthBar or uf.HealthBar or (uf.HealthBarsContainer and uf.HealthBarsContainer.healthBar))
end

local function textFor(plate)
	local fs = texts[plate]
	if fs then return fs end
	local holder = CreateFrame("Frame", nil, plate)
	holder:SetAllPoints(plate)
	holder:SetFrameLevel(plate:GetFrameLevel() + 20)
	fs = holder:CreateFontString(nil, "OVERLAY")
	fs:SetFont(STANDARD_TEXT_FONT or "Fonts\\FRIZQT__.TTF", 10, "OUTLINE")
	fs:SetJustifyH("RIGHT")
	texts[plate] = fs
	return fs
end

local function place(plate, fs)
	local hb = healthBar(plate)
	local holder = fs:GetParent()
	if hb then
		holder:SetParent(hb)
		holder:SetAllPoints(hb)
		holder:SetFrameLevel(hb:GetFrameLevel() + 10)
		fs:ClearAllPoints()
		fs:SetPoint("TOPRIGHT", hb, "BOTTOMRIGHT", 0, -1)
	else
		holder:SetParent(plate)
		holder:SetAllPoints(plate)
		fs:ClearAllPoints()
		fs:SetPoint("BOTTOMRIGHT", plate, "BOTTOMRIGHT", -4, 2)
	end
	holder:Show()
end

local diag = { calls = 0, noPlate = 0, noPct = 0, shown = 0, lastPct = "-", lastStatus = "-", hb = "-", api = tostring(UnitDetailedThreatSituation ~= nil) }
ns.threatDiag = diag
local function updatePlate(plate, unit)
	diag.calls = diag.calls + 1
	if not plate then diag.noPlate = diag.noPlate + 1 return end
	local fs = texts[plate]
	if not opt("threatPlates") or not unit or not UnitExists(unit) or not UnitCanAttack("player", unit)
		or not UnitDetailedThreatSituation then
		if fs then fs:Hide() end
		return
	end
	-- WoW Forever returns threat as "secret" numbers: addons may display them,
	-- but not compare or do math on them. So only pass them straight to the UI.
	local _, status, pct = UnitDetailedThreatSituation("player", unit)
	diag.lastPct, diag.lastStatus = tostring(pct), tostring(status)
	if type(pct) ~= "number" then
		diag.noPct = diag.noPct + 1
		if fs then fs:Hide() end
		return
	end
	fs = textFor(plate)
	place(plate, fs)
	fs:SetTextColor(0.8, 0.8, 0.8)
	if status ~= nil and GetThreatStatusColor then
		pcall(function() fs:SetTextColor(GetThreatStatusColor(status)) end)
	end
	local ok = pcall(fs.SetFormattedText, fs, "%.0f%%", pct)
	if not ok then fs:SetText(tostring(pct)) end
	fs:Show()
	diag.shown = diag.shown + 1
end

local lastErr
local function updateAll()
	if not C_NamePlate then return end
	for i = 1, 40 do
		local unit = "nameplate" .. i
		if UnitExists(unit) then
			local plate = C_NamePlate.GetNamePlateForUnit(unit)
			local ok, err = pcall(updatePlate, plate, unit)
			if not ok and err ~= lastErr then
				lastErr = err
				diag.err = tostring(err)
			end
		end
	end
end

function ns.threatDebug()
	local u = UnitExists("target") and "target"
	local a, b, c = nil, nil, nil
	if u and UnitDetailedThreatSituation then a, b, c = UnitDetailedThreatSituation("player", u) end
	local plate = C_NamePlate and C_NamePlate.GetNamePlateForUnit("target")
	local fs = plate and texts[plate]
	print(string.format("|cff66ccffAI Quest Helper:|r threat on=%s api=%s target=%s status=%s pct=%s plate=%s hb=%s text=%s error=%s",
		tostring(opt("threatPlates")), tostring(UnitDetailedThreatSituation ~= nil), tostring(u), tostring(b), tostring(c),
		tostring(plate ~= nil), tostring(plate and healthBar(plate) ~= nil), fs and (fs:IsShown() and "shown" or "hidden") or "none", tostring(lastErr)))
end
ns.refreshThreat = updateAll

local f = CreateFrame("Frame")
f:RegisterEvent("NAME_PLATE_UNIT_ADDED")
f:RegisterEvent("NAME_PLATE_UNIT_REMOVED")
f:RegisterEvent("UNIT_THREAT_LIST_UPDATE")
f:RegisterEvent("UNIT_THREAT_SITUATION_UPDATE")
f:RegisterEvent("PLAYER_REGEN_ENABLED")
f:SetScript("OnEvent", function(_, event, unit)
	if event == "NAME_PLATE_UNIT_REMOVED" then
		local plate = C_NamePlate.GetNamePlateForUnit(unit)
		if plate and texts[plate] then texts[plate]:Hide() end
	else
		updateAll()
	end
end)

local acc = 0
f:SetScript("OnUpdate", function(_, e)
	acc = acc + e
	if acc < 0.1 then return end
	acc = 0
	if UnitAffectingCombat("player") then updateAll() end
end)

local saver = CreateFrame("Frame")
saver:RegisterEvent("PLAYER_LOGOUT")
saver:SetScript("OnEvent", function()
	if AIQuestHelperDB then AIQuestHelperDB.threatDiag = diag end
end)
