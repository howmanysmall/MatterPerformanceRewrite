local Queue = {}
Queue.ClassName = "Queue"
Queue.__index = Queue

function Queue.new()
	return setmetatable({
		First = 1;
		Length = 0;
	}, Queue)
end

function Queue:Push(Value)
	local Length = self.Length + 1
	self.Length = Length
	Length += self.First - 1

	self[Length] = Value
	return Length
end

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
