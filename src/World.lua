local Archetype = require(script.Parent.Archetype)
local TopoRuntime = require(script.Parent.TopoRuntime)

local ERROR_NO_ENTITY = "Entity doesn't exist, use world:contains to check if needed"
local NoOp = function() end

--[=[
	@class World

	A World contains entities which have components.
	The World is queryable and can be used to get entities with a specific set of components.
	Entities are simply ever-increasing integers.
]=]
local World = {}
World.ClassName = "World"
World.__index = World

--[=[
	@prop Size number
	@within World
	The number of entities currently spawned in the world.
]=]

--[=[
	Creates a new World.
]=]
function World.new()
	return setmetatable({
		-- The total number of active entities in the world
		Size = 0,

		-- Map from entity ID -> archetype string
		Archetypes = {},

		-- Map from archetype string --> entity ID --> entity data
		EntityArchetypes = {},

		-- Cache of the component metatables on each entity. Used for generating archetype.
		-- Map of entity ID -> array
		EntityMetatablesCache = {},

		-- Cache of what query archetypes are compatible with what component archetypes
		QueryCache = {},

		-- The next ID that will be assigned with World:spawn
		NextId = 0,

		-- Storage for `queryChanged`
		ChangedStorage = {},
	}, World)
end

local function NewQueryArchetype(self, QueryArchetype)
	local QueryCache = self.QueryCache
	if QueryCache[QueryArchetype] == nil then
		QueryCache[QueryArchetype] = {}
	else
		return -- Archetype isn't actually new
	end

	for EntityArchetype in pairs(self.Archetypes) do
		if Archetype.AreArchetypesCompatible(QueryArchetype, EntityArchetype) then
			QueryCache[QueryArchetype][EntityArchetype] = true
		end
	end
end

local function TransitionArchetype(self, Id, Components)
	debug.profilebegin("TransitionArchetype")
	local NewArchetype = nil
	local OldArchetype = self.EntityArchetypes[Id]
	local Archetypes = self.Archetypes

	if OldArchetype then
		Archetypes[OldArchetype][Id] = nil
		-- Keep archetypes around because they're likely to exist again in the future
	end

	if Components then
		NewArchetype = Archetype.ArchetypeOf(table.unpack(self.EntityMetatablesCache[Id]))
		local ArchetypeTable = Archetypes[NewArchetype]

		if ArchetypeTable == nil then
			ArchetypeTable = {}
			Archetypes[NewArchetype] = ArchetypeTable

			debug.profilebegin("update query cache")
			for QueryArchetype, CompatibleArchetypes in pairs(self.QueryCache) do
				if Archetype.AreArchetypesCompatible(QueryArchetype, NewArchetype) then
					CompatibleArchetypes[NewArchetype] = true
				end
			end

			debug.profileend()
		end

		Archetypes[NewArchetype][Id] = Components
	end

	self.EntityArchetypes[Id] = NewArchetype
	debug.profileend()
end

local function TrackChanged(self, Metatable, Id, Old, New)
	local ChangedStorage = self.ChangedStorage[Metatable]
	if not ChangedStorage or Old == New then
		return
	end

	local Record = {
		New = New,
		Old = Old,

		-- Compat
		new = New,
		old = Old,
	}

	table.freeze(Record)
	for _, Storage in ipairs(ChangedStorage) do
		Storage[Id] = Record
	end
end

--[=[
	Spawns a new entity in the world with the given components.

	@param ... ComponentInstance -- The component values to spawn the entity with.
	@return number -- The new entity ID.
]=]
function World:Spawn(...)
	local Id = self.NextId
	self.NextId = Id + 1
	self.Size += 1

	local Components = {}
	local Metatables = {}

	for Index = 1, select("#", ...) do
		local NewComponent = select(Index, ...)
		local Metatable = getmetatable(NewComponent)

		if Components[Metatable] then
			error(string.format("Duplicate component type at index %d", Index), 2)
		end

		TrackChanged(self, Metatable, Id, nil, NewComponent)
		Components[Metatable] = NewComponent
		table.insert(Metatables, Metatable)
	end

	self.EntityMetatablesCache[Id] = Metatables
	TransitionArchetype(self, Id, Components)
	return Id
end

--[=[
	Replaces a given entity by ID with an entirely new set of components.
	Equivalent to removing all components from an entity, and then adding these ones.

	@param Id number -- The entity ID
	@param ... ComponentInstance -- The component values to spawn the entity with.
]=]
function World:Replace(Id: number, ...)
	local EntityArchetype = self.EntityArchetypes[Id]
	if EntityArchetype == nil then
		error(ERROR_NO_ENTITY, 2)
	end

	local Components = {}
	local Metatables = {}
	local ExistingComponents = self.Archetypes[EntityArchetype][Id]

	for Index = 1, select("#", ...) do
		local NewComponent = select(Index, ...)
		local Metatable = getmetatable(NewComponent)

		if Components[Metatable] then
			error(string.format("Duplicate component type at index %d", Index), 2)
		end

		TrackChanged(self, Metatable, Id, ExistingComponents[Metatable], NewComponent)
		Components[Metatable] = NewComponent
		table.insert(Metatables, Metatable)
	end

	for Metatable, Component in pairs(ExistingComponents) do
		if not Components[Metatable] then
			TrackChanged(self, Metatable, Id, Component, nil)
		end
	end

	self.EntityMetatablesCache[Id] = Metatables
	TransitionArchetype(self, Id, Components)
end

--[=[
	Despawns a given entity by ID, removing it and all its components from the world entirely.

	@param Id number -- The entity ID
]=]
function World:Despawn(Id: number)
	local ExistingComponents = self.Archetypes[self.EntityArchetypes[Id]][Id]
	for Metatable, Component in pairs(ExistingComponents) do
		TrackChanged(self, Metatable, Id, Component, nil)
	end

	self.EntityMetatablesCache[Id] = nil
	TransitionArchetype(self, Id, nil)
	self.Size -= 1
end

--[=[
	Removes all entities from the world.

	:::warning
	Removing entities in this way is not reported by `QueryChanged`.
	:::
]=]
function World:Clear()
	self.EntityArchetypes = {}
	self.Archetypes = {}
	self.EntityMetatablesCache = {}
	self.Size = 0
end

--[=[
	Checks if the given entity ID is currently spawned in this world.

	@param Id number -- The entity ID
	@return bool -- `true` if the entity exists
]=]
function World:Contains(Id: number)
	return self.EntityArchetypes[Id] ~= nil
end

--[=[
	Gets a specific component (or set of components) from a specific entity in this world.

	@param Id number -- The entity ID
	@param ... Component -- The components to fetch
	@return ... -- Returns the component values in the same order they were passed in
]=]
function World:Get(Id: number, ...)
	local EntityArchetype = self.EntityArchetypes[Id]
	if EntityArchetype == nil then
		error(ERROR_NO_ENTITY, 2)
	end

	local Entity = self.Archetypes[EntityArchetype][Id]
	local Length = select("#", ...)
	if Length == 1 then
		return Entity[...]
	end

	local Components = table.create(Length)
	for Index = 1, Length do
		Components[Index] = Entity[select(Index, ...)]
	end

	return table.unpack(Components, 1, Length)
end

--[=[
	@class QueryResult

	A result from the [`World:Query`](/api/World#Query) function.

	Calling the table or the `Next` method allows iteration over the results. Once all results have been returned, the
	QueryResult is exhausted and is no longer useful.

	```lua
	for Id, Enemy, Charge, Model in World:Query(Components.Enemy, Components.Charge, Components.Model) do
		-- Do something
	end
	```
]=]
local QueryResult = {}
QueryResult.ClassName = "QueryResult"
QueryResult.__index = QueryResult

function QueryResult._new()
	return setmetatable({
		_Expand = NoOp,
		_Next = NoOp,
	}, QueryResult)
end

function QueryResult:__call()
	return self._Expand(self._Next())
end

--[=[
	Returns the next set of values from the query result. Once all results have been returned, the
	QueryResult is exhausted and is no longer useful.

	:::info
	This function is equivalent to calling the QueryResult as a function. When used in a for loop, this is implicitly
	done by the language itself.
	:::

	```lua
	-- Using world:Query in this position will make Lua invoke the table as a function. This is conventional.
	for Id, Enemy, Charge, Model in World:Query(Components.Enemy, Components.Charge, Components.Model) do
		-- Do something
	end
	```

	If you wanted to iterate over the QueryResult without a for loop, it's recommended that you call `Next` directly
	instead of calling the QueryResult as a function.
	```lua
	local Id, Enemy, Charge, Model = World:Query(Components.Enemy, Components.Charge, Components.Model):Next()
	local Id, Enemy, Charge, Model = World:Query(Components.Enemy, Components.Charge, Components.Model)() -- Possible, but unconventional
	```

	@return Id -- Entity ID
	@return ...ComponentInstance -- The requested component values
]=]
function QueryResult:Next()
	return self._Expand(self._Next())
end

--[=[
	Returns an iterator that will skip any entities that also have the given components.

	:::tip
	This is essentially equivalent to querying normally, using `World:Get` to check if a component is present,
	and using Lua's `continue` keyword to skip this iteration (though, using `:Without` is faster).

	This means that you should avoid queries that return a very large amount of results only to filter them down
	to a few with `:Without`. If you can, always prefer adding components and making your query more specific.
	:::

	@param ... Component -- The component types to filter against.
	@return () -> (Id, ...ComponentInstance) -- Iterator of entity ID followed by the requested component values

	```lua
	for Id in World:Query(Components.Target):Without(Components.Model) do
		-- Do something
	end
	```
]=]
function QueryResult:Without(...)
	local Metatables = {...}
	local Expand = self._Expand
	local Next = self._Next

	return function()
		while true do
			local EntityId, EntityData = Next()
			if not EntityId then
				break
			end

			local Skip = false
			for _, Metatable in ipairs(Metatables) do
				if EntityData[Metatable] then
					Skip = true
					break
				end
			end

			if Skip then
				continue
			end

			return Expand(EntityId, EntityData)
		end
	end
end

function QueryResult:__tostring()
	return "QueryResult"
end

local QueryResultSingleton = QueryResult._new()

--[=[
	Performs a query against the entities in this World. Returns a [QueryResult](/api/QueryResult), which iterates over
	the results of the query.

	```lua
	for Id, Enemy, Charge, Model in World:Query(Components.Enemy, Components.Charge, Components.Model) do
		-- Do something
	end

	for Id in World:Query(Components.Target):Without(Components.Model) do
		-- Again, with feeling
	end
	```

	&nbsp;

	:::danger Modifying the World while iterating
	- **Do not insert new components or spawn entities that would then match the query while iterating.** The iteration
	behavior is undefined if the World is changed while iterating so that additional results would be returned.

	- **Removing components during iteration may cause the iterator to return the same entity multiple times**,
	*if* the component would still meet the requirements of the query. It is safe to remove components
	during iteration *if and only if* the entity would no longer meet the query requirements.
	:::

	To mitigate against these limitations, simply build up a queue of actions to take after iteration, and then do them
	after your iteration loop. **Inserting existing components** and **despawning entities** during iteration is safe,
	however.

	@param ... Component -- The component types to query. Only entities with *all* of these components will be returned.
	@return QueryResult -- See [QueryResult](/api/QueryResult) docs.
]=]
function World:Query(...)
	debug.profilebegin("World:Query")
	local Metatables = {...}
	local QueryLength = select("#", ...)

	local ListArchetype = Archetype.ArchetypeOf(...)
	if self.QueryCache[ListArchetype] == nil then
		NewQueryArchetype(self, ListArchetype)
	end

	local CompatibleArchetypes = self.QueryCache[ListArchetype]
	debug.profileend()

	if next(CompatibleArchetypes) == nil then
		-- If there are no compatible storages avoid creating our complicated iterator
		return QueryResultSingleton
	end

	local QueryOutput = table.create(QueryLength)
	local function Expand(EntityId, EntityData)
		if not EntityId then
			return
		end

		for Index, Metatable in ipairs(Metatables) do
			QueryOutput[Index] = EntityData[Metatable]
		end

		return EntityId, table.unpack(QueryOutput, 1, QueryLength)
	end

	local Archetypes = self.Archetypes
	local CompatibleArchetype = next(CompatibleArchetypes)
	local LastEntityId
	local function NextItem()
		local EntityId, EntityData = next(Archetypes[CompatibleArchetype], LastEntityId)

		while EntityId == nil do
			CompatibleArchetype = next(CompatibleArchetypes, CompatibleArchetype)
			if CompatibleArchetype == nil then
				return
			end

			EntityId, EntityData = next(Archetypes[CompatibleArchetype])
		end

		LastEntityId = EntityId
		return EntityId, EntityData
	end

	return setmetatable({
		_Expand = Expand,
		_Next = NextItem,
	}, QueryResult)
end

--[=[
	@interface ChangeRecord
	@within World
	.New? ComponentInstance -- The new value of the component. Nil if just removed.
	.Old? ComponentInstance -- The former value of the component. Nil if just added.
]=]

--[=[
	:::info Topologically-aware function
	This function is only usable if called within the context of [`Loop:Begin`](/api/Loop#Begin).
	:::

	Queries for components that have changed **since the last time your system ran `QueryChanged`**.

	Only one changed record is returned per entity, even if the same entity changed multiple times. The order
	in which changed records are returned is not guaranteed to be the order that the changes occurred in.

	It should be noted that `QueryChanged` does not have the same iterator invalidation limitations as `World:query`.

	:::caution
	The first time your system runs (i.e., on the first frame), no results are returned. Results only begin to be
	tracked after the first time your system calls this function.
	:::

	:::info
	Calling this function from your system creates storage internally for your system. Then, changes meeting your
	criteria are pushed into your storage. Calling `QueryChanged` again each frame drains this storage.

	If you do not call `QueryChanged` each frame, or your system isn't called every frame, the storage will continually
	fill up and does not empty unless you drain it. It is assumed that you will call `QueryChanged` unconditionally,
	every frame, **until the end of time**.
	:::

	### Arguments

	The first argument to `QueryChanged` is the component for which you want to track changes.
	Further arguments are optional, and if passed, are an additional filter on what entities will be returned.

	:::caution
	Additional query arguments are checked against *at the time of iteration*, not when the change ocurred.
	This has the additional implication that entities that have been despawned will never be returned from
	`QueryChanged` if additional query arguments are passed, because the entity will have no components, so cannot
	possibly pass any additional query.
	:::

	If no additional query arguments are passed, all changes (including despawns) will be tracked and returned.

	### Returns
	`QueryChanged` returns an iterator function, so you call it in a for loop just like `World:query`.

	The iterator returns the entity ID, followed by a [`ChangeRecord`](#ChangeRecord), followed by the component
	instance values of any additional query arguments that were passed (as discussed above).

	The ChangeRecord type is a table that contains two fields, `new` and `old`, respectively containing the new
	component instance, and the old component instance. `new` and `old` will never be the same value.

	`new` will be nil if the component was removed (or the entity was despawned), and `old` will be nil if the
	component was just added.

	The ChangeRecord table is given to all systems tracking changes for this component, and cannot be modified.

	```lua
	for Id, ModelRecord, Enemy in World:QueryChanged(Components.Model, Components.Enemy) do
		if
			ModelRecord.New == nil -- Model was removed
			and Enemy.Type == "this is a made up example"
		then
			World:Remove(Id, Enemy)
		end
	end
	```

	&nbsp;

	:::info
	It's conventional to end the name you assign the record with "-Record", to make clear it is a different shape than
	a regular component instance. The ChangeValue is a table with `new` and `old` fields, but additional returns for the
	additional query arguments are regular component instances.
	:::

	@param ComponentToTrack Component -- The component you want to listen to changes for.
	@param ...? Component -- Additional query components. Checked at time of iteration, not time of change.
	@return () -> (Id, ChangeRecord, ...ComponentInstance) -- Iterator of entity ID followed by the requested component values, in order
]=]
function World:QueryChanged(ComponentToTrack, ...)
	local HookState = TopoRuntime.UseHookState(ComponentToTrack)
	if not HookState.Storage then
		if not self.ChangedStorage[ComponentToTrack] then
			self.ChangedStorage[ComponentToTrack] = {}
		end

		local Storage = {}
		HookState.Storage = Storage

		table.insert(self.ChangedStorage[ComponentToTrack], Storage)
	end

	local QueryLength = select("#", ...)
	local QueryOutput = table.create(QueryLength)
	local QueryMetatables = {...}

	if #QueryMetatables == 0 then
		return function()
			local EntityId, Component = next(HookState.Storage)

			if EntityId then
				HookState.Storage[EntityId] = nil
				return EntityId, Component
			end
		end
	end

	local EntityArchetypes = self.EntityArchetypes
	local function QueryIterator()
		local EntityId, Component = next(HookState.Storage)

		if EntityId then
			HookState.Storage[EntityId] = nil

			-- If the entity doesn't currently contain the requested components, don't return anything
			if EntityArchetypes[EntityId] == nil then
				return QueryIterator()
			end

			for Index, QueryMetatable in ipairs(QueryMetatables) do
				local QueryComponent = self:Get(EntityId, QueryMetatable)
				if not QueryComponent then
					return QueryIterator()
				end

				QueryOutput[Index] = QueryComponent
			end

			return EntityId, Component, table.unpack(QueryOutput, 1, QueryLength)
		end
	end

	return QueryIterator
end

--[=[
	Inserts a component (or set of components) into an existing entity.

	If another instance of a given component already exists on this entity, it is replaced.

	```lua
	World:Insert(
		EntityId,
		Components.ComponentA({
			Foo = "bar";
		}),

		Components.ComponentB({
			Baz = "qux";
		})
	)
	```

	@param Id number -- The entity ID
	@param ... ComponentInstance -- The component values to insert
]=]
function World:Insert(Id: number, ...)
	debug.profilebegin("Insert")
	local EntityArchetype = self.EntityArchetypes[Id]
	if EntityArchetype == nil then
		error(ERROR_NO_ENTITY, 2)
	end

	local EntityMetatablesCache = self.EntityMetatablesCache
	local ExistingComponents = self.Archetypes[EntityArchetype][Id]

	local WasNew = false
	for Index = 1, select("#", ...) do
		local NewComponent = select(Index, ...)
		local Metatable = getmetatable(NewComponent)
		local OldComponent = ExistingComponents[Metatable]

		if not OldComponent then
			WasNew = true
			table.insert(EntityMetatablesCache[Id], Metatable)
		end

		TrackChanged(self, Metatable, Id, OldComponent, NewComponent)
		ExistingComponents[Metatable] = NewComponent
	end

	if WasNew then -- wasNew
		TransitionArchetype(self, Id, ExistingComponents)
	end

	debug.profileend()
end

--[=[
	Removes a component (or set of components) from an existing entity.

	```lua
	local RemovedA, RemovedB = World:Remove(EntityId, Components.ComponentA, Components.ComponentB)
	```

	@param Id number -- The entity ID
	@param ... Component -- The components to remove
	@return ...ComponentInstance -- Returns the component instance values that were removed in the order they were passed.
]=]
function World:Remove(Id: number, ...)
	local EntityArchetype = self.EntityArchetypes[Id]
	if EntityArchetype == nil then
		error(ERROR_NO_ENTITY, 2)
	end

	local ExistingComponents = self.Archetypes[EntityArchetype][Id]
	local Length = select("#", ...)
	local Removed = {}

	for Index = 1, Length do
		local Metatable = select(Index, ...)
		local OldComponent = ExistingComponents[Metatable]
		Removed[Index] = OldComponent

		TrackChanged(self, Metatable, Id, OldComponent, nil)
		ExistingComponents[Metatable] = nil
	end

	-- Rebuild entity metatable cache
	local Metatables = {}
	for Metatable in pairs(ExistingComponents) do
		table.insert(Metatables, Metatable)
	end

	self.EntityMetatablesCache[Id] = Metatables
	TransitionArchetype(self, Id, ExistingComponents)
	return table.unpack(Removed, 1, Length)
end

--[=[
	Returns the number of entities currently spawned in the world.
	@deprecated v2 -- Reference `World.Size` directly.
	@return number
]=]
function World:GetSize()
	return self.Size
end

function World:__tostring()
	return "World<" .. self.Size .. ">"
end

export type QueryResult = typeof(QueryResult._new())
export type World = typeof(World.new())

World.clear = World.Clear
World.contains = World.Contains
World.despawn = World.Despawn
World.get = World.Get
World.getSize = World.GetSize
World.insert = World.Insert
World.query = World.Query
World.queryChanged = World.QueryChanged
World.remove = World.Remove
World.replace = World.Replace
World.size = World.GetSize
World.spawn = World.Spawn

QueryResult.next = QueryResult.Next
QueryResult.without = QueryResult.Without

table.freeze(QueryResult)
table.freeze(World)
return World
