local Merge = require(script.Parent.Immutable.Merge)

--[=[
	@class Component

	A component is a named piece of data that exists on an entity.
	Components are created and removed in the [World](/api/World).

	In the docs, the terms "Component" and "ComponentInstance" are used:
	- **"Component"** refers to the base class of a specific type of component you've created.
		This is what [`Matter.Component`](/api/Matter#Component) returns.
	- **"Component Instance"** refers to an actual piece of data that can exist on an entity.
		The metatable of a component instance table is its respective Component table.

	Component instances are *plain-old data*: they do not contain behaviors or methods.

	Since component instances are immutable, one helper function exists on all component instances, `patch`,
	which allows reusing data from an existing component instance to make up for the ergonomic loss of mutations.
]=]

--[=[
	@within Component
	@type ComponentInstance {}

	The `ComponentInstance` type refers to an actual piece of data that can exist on an entity.
	The metatable of the component instance table is set to its particular Component table.

	A component instance can be created by calling the Component table:

	```lua
	-- Component:
	local MyComponent = Matter.Component("My component")

	-- component instance:
	local MyComponentInstance = MyComponent({
		Some = "Data";
	})

	print(getmetatable(MyComponentInstance) == MyComponent) --> true
	```
]=]
local function NewComponent(Name: string?)
	local TrueName = Name or debug.info(2, "s") .. "@" .. debug.info(2, "l")

	local Component = {}
	Component.ClassName = TrueName
	Component.__index = Component

	function Component.new(Data)
		local self = setmetatable(Data or {}, Component)
		table.freeze(self)
		return self
	end

	--[=[
	@within Component

	```lua
	for Id, Target in World:Query(Target) do
		if ShouldChangeTarget(Target) then
			World:Insert(Id, Target:Patch({ -- modify the existing component
				CurrentTarget = GetNewTarget();
			}))
		end
	end
	```

	A utility function used to immutably modify an existing component instance. Key/value pairs from the passed table
	will override those of the existing component instance.

	As all components are immutable and frozen, it is not possible to modify the existing component directly.

	You can use the `Matter.None` constant to remove a value from the component instance:

	```lua
	Target:Patch({
		CurrentTarget = Matter.None; -- sets currentTarget to nil
	})
	```

	@param PartialNewData {} -- The table to be merged with the existing component data.
	@return ComponentInstance -- A copy of the component instance with values from `partialNewData` overriding existing values.
	]=]
	function Component:Patch(PartialNewData)
		debug.profilebegin("Patch")
		local Metatable = getmetatable(self)
		local Patch = Metatable.new(Merge(self, PartialNewData))
		debug.profileend()
		return Patch
	end

	Component.patch = Component.Patch

	return setmetatable(Component, {
		__call = function(_, ...)
			return Component.new(...)
		end,

		__tostring = function()
			return TrueName
		end,
	})
end

export type Component = typeof(NewComponent("TypeDefinition"))
return NewComponent
