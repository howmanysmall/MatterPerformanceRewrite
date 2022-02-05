--[=[
	@class Matter

	Matter. It's what everything is made out of.
]=]

--[=[
	@within Matter
	@prop World World
]=]

--[=[
	@within Matter
	@prop Loop Loop
]=]

--[=[
	@within Matter
	@prop None None

	A value should be interpreted as nil when merging dictionaries.

	`Matter.None` is used by [`Component:Patch`](/api/Component#Patch).
]=]

--[=[
	@within Matter
	@function Component
	@param Name? string -- Optional name for debugging purposes
	@return Component -- Your new type of component

	Creates a new type of component. Call the component as a function to create an instance of that component.

	```lua
	-- Component:
	local MyComponent = Matter.Component("My component")

	-- component instance:
	local MyComponentInstance = MyComponent({
		Some = "Data";
	})
	```
]=]

local Loop = require(script.Loop)
local Merge = require(script.Immutable.Merge)
local NewComponent = require(script.NewComponent)
local None = require(script.Immutable.None)
local TopoRuntime = require(script.TopoRuntime)
local UseDeltaTime = require(script.Hooks.UseDeltaTime)
local UseEvent = require(script.Hooks.UseEvent)
local UseThrottle = require(script.Hooks.UseThrottle)
local World = require(script.World)

local Matter = {
	Component = NewComponent,
	Loop = Loop,
	NewComponent = NewComponent,
	World = World,

	-- Use Functions
	UseDeltaTime = UseDeltaTime,
	UseEvent = UseEvent,
	UseHookState = TopoRuntime.UseHookState,
	UseThrottle = UseThrottle,

	-- Llama
	Merge = Merge,
	None = None,

	-- Compat
	component = NewComponent,

	useDeltaTime = UseDeltaTime,
	useEvent = UseEvent,
	useHookState = TopoRuntime.UseHookState,
	useThrottle = UseThrottle,

	merge = Merge,
}

export type Component = NewComponent.Component
export type Loop = Loop.Loop
export type QueryResult = World.QueryResult
export type World = World.World

export type SystemFunction = Loop.SystemFunction
export type SystemTable = Loop.SystemTable
export type System = Loop.System

table.freeze(Matter)
return Matter
