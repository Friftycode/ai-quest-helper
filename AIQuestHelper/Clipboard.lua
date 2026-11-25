local _, ns = ...

-- WoW does not let addons write to the clipboard: the text is selected in
-- an off-screen edit box and the player presses Ctrl+C.
local TIMEOUT = 15

local box = CreateFrame("EditBox", "AIQuestHelperBox", UIParent)
box:SetMultiLine(true)
box:SetAutoFocus(false)
box:SetMaxLetters(0)
if box.SetMaxBytes then box:SetMaxBytes(0) end
box:SetFontObject(ChatFontNormal)
box:SetSize(300, 20)
box:SetPoint("TOPLEFT", UIParent, "TOPLEFT", -10000, 10000)
box:SetAlpha(0)
box:SetTextColor(0, 0, 0, 0)
if box.SetHighlightColor then box:SetHighlightColor(0, 0, 0, 0) end
box:EnableMouse(false)
box:Hide()

local pending, owner, timer, feedback

local function setFeedback(button, text, r, g, b)
	if not feedback then
		feedback = UIParent:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
		feedback:SetShadowOffset(1, -1)
	end
	feedback:SetParent(button or UIParent)
	feedback:ClearAllPoints()
	if button then
		feedback:SetPoint("RIGHT", button, "LEFT", -4, 0)
	else
		feedback:SetPoint("TOP", UIParent, "TOP", 0, -140)
	end
	feedback:SetTextColor(r or 1, g or 0.82, b or 0)
	feedback:SetText(text or "")
	feedback:Show()
end

local function clearFeedbackLater(delay, text)
	local f = feedback
	if not f then return end
	C_Timer.After(delay, function() if f:GetText() == text then f:SetText("") end end)
end

local function release(copied)
	if timer then timer:Cancel() timer = nil end
	box:ClearFocus()
	box:SetText("")
	box:Hide()
	if copied then
		setFeedback(owner, "Copied", 0.3, 1, 0.3)
		clearFeedbackLater(1.5, "Copied")
	elseif feedback then
		feedback:SetText("")
	end
	pending, owner = nil, nil
end

function ns.ready(text, button)
	if not text then
		setFeedback(button, "No text", 1, 0.3, 0.3)
		clearFeedbackLater(1.5, "No text")
		return
	end
	pending, owner = text, button
	box:Show()
	box:SetText(text)
	box:SetFocus()
	box:HighlightText()
	setFeedback(button, "Ctrl+C", 1, 0.82, 0)
	if timer then timer:Cancel() end
	timer = C_Timer.NewTimer(TIMEOUT, function() timer = nil release(false) end)
end

box:SetScript("OnKeyDown", function(_, key)
	if key == "C" and IsControlKeyDown() then
		C_Timer.After(0.05, function() release(true) end)
	elseif key == "LCTRL" or key == "RCTRL" or (key == "A" and IsControlKeyDown()) then
		return
	else
		C_Timer.After(0, function() release(false) end)
	end
end)
box:SetScript("OnEscapePressed", function() release(false) end)
box:SetScript("OnEditFocusLost", function() if pending then release(false) end end)
box:SetScript("OnTextChanged", function(self, userInput)
	if userInput and pending then self:SetText(pending) self:HighlightText() end
end)
