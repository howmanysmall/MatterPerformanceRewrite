-- This is one of the major performance increases I've made.
-- This is my Queue from the DataStructures repository I have.
-- The performance compared to the original is pretty insane,
-- where the entire thing can run in less time than the original took to insert.
-- See the Queue benchmark in the Benchmarks folder.

local Queue = {}
Queue.ClassName = "Queue"
Queue.__index = Queue

function Queue.new()
	return setmetatable({
		First = 1,
		Length = 0,
	}, Queue)
end

function Queue:Push(Value)
	local Length = self.Length + 1
	self.Length = Length
	Length += self.First - 1

	self[Length] = Value
	return Length
end

-- This is actually slower than the original Queue Pop function, but the the Push function compensates for that small loss.
function Queue:Pop(): any?
	local Length = self.Length
	if Length > 0 then
		local First = self.First
		local Value = self[First]
		self[First] = nil

		self.First = First + 1
		self.Length = Length - 1

		return Value
	end

	return nil
end

function Queue:__tostring()
	return "Queue"
end

export type Queue = typeof(Queue.new())
table.freeze(Queue)
return Queue
