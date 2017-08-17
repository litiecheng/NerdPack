local _, NeP 			= ...
NeP.Healing 			= {}
local Roster 			= {}
local maxDistance = 40

-- Local stuff for speed
local UnitExists              = ObjectExists or UnitExists
local UnitHealth              = UnitHealth
local UnitGUID                = UnitGUID
local UnitHealthMax           = UnitHealthMax
local UnitGetTotalHealAbsorbs = UnitGetTotalHealAbsorbs
local UnitGetIncomingHeals    = UnitGetIncomingHeals
local UnitGroupRolesAssigned  = UnitGroupRolesAssigned
local UnitIsDeadOrGhost       = UnitIsDeadOrGhost
local UnitInParty             = UnitInParty
local UnitIsUnit              = UnitIsUnit
local strsplit                = strsplit
local UnitInPhase             = UnitInPhase
local C_Timer                 = C_Timer

local function Clean()
	for GUID, Obj in pairs(Roster) do
		if not Obj
		or not UnitExists(Obj.key)
		or not UnitInPhase(Obj.key)
		or Obj.distance > maxDistance
		or UnitIsDeadOrGhost(Obj.key)
		or GUID ~= UnitGUID(Obj.key) then
			Roster[GUID] = nil
		end
	end
end

local function GetPredictedHealth(unit)
	return UnitHealth(unit)+(UnitGetTotalHealAbsorbs(unit) or 0)+(UnitGetIncomingHeals(unit) or 0)
end

local function GetPredictedHealth_Percent(unit)
	return math.floor((GetPredictedHealth(unit)/UnitHealthMax(unit))*100)
end

local function healthPercent(unit)
	return math.floor((UnitHealth(unit)/UnitHealthMax(unit))*100)
end

-- This Add's more index to the Obj in the OM table
local function Add(Obj)
	local healthRaw = UnitHealth(Obj.key)
	local maxHealth = UnitHealthMax(Obj.key)
	Obj.predicted = GetPredictedHealth_Percent(Obj.key)
	Obj.predicted_Raw = GetPredictedHealth(Obj.key)
	Obj.health = healthPercent(Obj.key)
	Obj.healthRaw = healthRaw
	Obj.healthMax = maxHealth
	Obj.role = UnitGroupRolesAssigned(Obj.key)
	Roster[Obj.guid] = Obj
end

local function Refresh(GUID, Obj)
	local temp = Roster[GUID]
	temp.health = healthPercent(Obj.key)
	temp.healthRaw = UnitHealth(temp.key)
	temp.predicted = GetPredictedHealth_Percent(Obj.key)
	temp.predicted_Raw = GetPredictedHealth(Obj.key)
	temp.role = UnitGroupRolesAssigned(Obj.key)
end

function NeP.Healing.GetRoster()
	Clean()
	return Roster
end

C_Timer.NewTicker(0.1, (function()
	-- Add refresh
	for GUID, Obj in pairs(NeP.OM:Get('Friendly')) do
		if UnitInParty(Obj.key)
		or UnitIsUnit('player', Obj.key) then
			if Roster[GUID] then
				Refresh(GUID, Obj)
			elseif Obj.distance < maxDistance then
				Add(Obj)
			end
		end
	end
end), nil)

NeP.DSL:Register("health", function(target)
	return healthPercent(target)
end)

NeP.DSL:Register("health.actual", function(target)
	return UnitHealth(target)
end)

NeP.DSL:Register("health.max", function(target)
	return UnitHealthMax(target)
end)

NeP.DSL:Register("health.predicted", function(target)
	return GetPredictedHealth_Percent(target)
end)

NeP.DSL:Register("health.predicted.actual", function(target)
	return GetPredictedHealth(target)
end)

-- USAGE: UNIT.area(DISTANCE, HEALTH).heal >= #
NeP.DSL:Register("area.heal", function(unit, args)
	local total = 0
	if not UnitExists(unit) then return total end
	local distance, health = strsplit(",", args, 2)
	for _,Obj in pairs(NeP.Healing:GetRoster()) do
		local unit_dist = NeP.Protected.Distance(unit, Obj.key)
		if unit_dist < (tonumber(distance) or 20)
		and Obj.health < (tonumber(health) or 100) then
			total = total + 1
		end
	end
	return total
end)

-- USAGE: UNIT.area(DISTANCE, HEALTH).heal.infront >= #
NeP.DSL:Register("area.heal.infront", function(unit, args)
	local total = 0
	if not UnitExists(unit) then return total end
	local distance, health = strsplit(",", args, 2)
	for _,Obj in pairs(NeP.Healing:GetRoster()) do
		local unit_dist = NeP.Protected.Distance(unit, Obj.key)
		if unit_dist < (tonumber(distance) or 20)
		and Obj.health < (tonumber(health) or 100)
		and NeP.Protected.Infront(unit, Obj.key) then
			total = total + 1
		end
	end
	return total
end)

NeP.Globals.OM.GetRoster = NeP.Healing.GetRoster
