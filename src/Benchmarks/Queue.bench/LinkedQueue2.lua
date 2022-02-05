-- This is the optimized version.

local Queue = {}
Queue.ClassName = "Queue"
Queue.__index = Queue

function Queue.new()
	return setmetatable({
		Head = nil;
		Tail = nil;
	}, Queue)
end

function Queue:Push(Value)
	local Entry = {
		Value = Value;
		Next = nil;
	}

	local Tail = self.Tail
	if Tail ~= nil then
		Tail.Next = Entry
	end

	self.Tail = Entry
	if self.Head == nil then
		self.Head = Entry
	end
end

function Queue:Pop()
	local Head = self.Head
	if Head == nil then
		return nil
	end

	local Value = Head.Value
	self.Head = Head.Next
	return Value
end

function Queue:__tostring()
	return "Queue"
end

export type Queue = typeof(Queue.new())
table.freeze(Queue)
return Queue
