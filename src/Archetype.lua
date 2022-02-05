local Archetype = {}

local ArchetypeCache = {}
local CompatibilityCache = {}
local NextValueId = 0
local ValueIds = {}

function Archetype.ArchetypeOf(...)
	debug.profilebegin("ArchetypeOf")
	local Length = select("#", ...)
	local CurrentNode = ArchetypeCache

	for Index = 1, Length do
		local Value = select(Index, ...)
		local NextNode = CurrentNode[Value]

		if not NextNode then
			NextNode = {}
			CurrentNode[Value] = NextNode
		end

		CurrentNode = NextNode
	end

	local ListArchetype = CurrentNode.Archetype
	if ListArchetype then
		debug.profileend()
		return ListArchetype
	end

	local List = table.create(Length)
	for Index = 1, Length do
		local Value = select(Index, ...)
		local ValueId = ValueIds[Value]
		if ValueId == nil then
			ValueIds[Value] = NextValueId
			ValueId = NextValueId
			NextValueId += 1
		end

		List[Index] = ValueId
	end

	table.sort(List)
	ListArchetype = table.concat(List, "_")
	CurrentNode.Archetype = ListArchetype

	debug.profileend()
	return ListArchetype
end

function Archetype.AreArchetypesCompatible(QueryArchetype, TargetArchetype)
	local Key = QueryArchetype .. "-" .. TargetArchetype
	local CachedCompatibility = CompatibilityCache[Key]
	if CachedCompatibility ~= nil then
		return CachedCompatibility
	end

	debug.profilebegin("AreArchetypesCompatible")
	local QueryIds = string.split(QueryArchetype, "_")
	local TargetIds = {}
	for _, Value in ipairs(string.split(TargetArchetype, "_")) do
		TargetIds[Value] = true
	end

	for _, QueryId in ipairs(QueryIds) do
		if TargetIds[QueryId] == nil then
			CompatibilityCache[Key] = false
			debug.profileend()
			return false
		end
	end

	CompatibilityCache[Key] = true
	debug.profileend()
	return true
end

table.freeze(Archetype)
return Archetype
