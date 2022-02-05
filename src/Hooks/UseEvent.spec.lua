return function()
	local TopoRuntime = require(script.Parent.Parent.TopoRuntime)
	local UseEvent = require(script.Parent.UseEvent)

	describe("UseEvent", function()
		it("should queue up events until useEvent is called again", function()
			local Node = {System = {}}

			local BindableEvent = Instance.new("BindableEvent")

			local A, B, C
			local ShouldCall = true
			local ShouldCount = 0
			local function Function()
				if ShouldCall then
					local Count = 0
					for Index, ValueA, ValueB, ValueC in UseEvent(BindableEvent, BindableEvent.Event) do
						expect(Index).to.equal(Count + 1)
						Count += 1
						A = ValueA
						B = ValueB
						C = ValueC
					end

					expect(Count).to.equal(ShouldCount)
				end
			end

			TopoRuntime.Start(Node, Function)
			BindableEvent:Fire(3, 4, 5)

			ShouldCount = 1
			TopoRuntime.Start(Node, Function)

			expect(A).to.equal(3)
			expect(B).to.equal(4)
			expect(C).to.equal(5)

			ShouldCount = 3

			BindableEvent:Fire()
			BindableEvent:Fire()
			BindableEvent:Fire()

			TopoRuntime.Start(Node, Function)

			ShouldCount = 0

			TopoRuntime.Start(Node, Function)

			BindableEvent:Fire()
			BindableEvent:Fire()

			ShouldCall = false

			TopoRuntime.Start(Node, Function)

			ShouldCall = true
			TopoRuntime.Start(Node, Function)
		end)

		it("should cleanup if the event changes", function()
			local Node = {System = {}}

			local BindableEventA = Instance.new("BindableEvent")
			local BindableEventB = Instance.new("BindableEvent")

			local Event = BindableEventA
			local ShouldCount = 0
			local function Function()
				local Count = 0
				for _ in UseEvent(Event, "Event") do
					Count += 1
				end

				expect(Count).to.equal(ShouldCount)
			end

			TopoRuntime.Start(Node, Function)

			BindableEventA:Fire()
			BindableEventA:Fire()

			ShouldCount = 2
			TopoRuntime.Start(Node, Function)

			BindableEventA:Fire()
			BindableEventA:Fire()
			Event = BindableEventB

			ShouldCount = 0
			TopoRuntime.Start(Node, Function)

			BindableEventB:Fire()

			ShouldCount = 1
			TopoRuntime.Start(Node, Function)
		end)
	end)
end
