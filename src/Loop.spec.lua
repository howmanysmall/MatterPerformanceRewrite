return function()
	local Loop = require(script.Parent.Loop)
	local BindableEvent = Instance.new("BindableEvent")

	describe("Loop", function()
		it("should call systems", function()
			local NewLoop = Loop.new(1, 2, 3)

			local CallCount = 0
			NewLoop:ScheduleSystem(function(A, B, C)
				CallCount += 1
				expect(A).to.equal(1)
				expect(B).to.equal(2)
				expect(C).to.equal(3)
			end)

			local Connection = NewLoop:Begin({Default = BindableEvent.Event})
			expect(CallCount).to.equal(0)
			BindableEvent:Fire()
			expect(CallCount).to.equal(1)
			Connection.Default:Disconnect()
			expect(CallCount).to.equal(1)
		end)

		it("should call systems in order", function()
			local NewLoop = Loop.new()
			local Order = {}
			local SystemA = {
				After = {},
				System = function()
					table.insert(Order, "a")
				end,
			}

			local SystemB = {
				After = {SystemA},
				System = function()
					table.insert(Order, "b")
				end,
			}

			local SystemC = {
				After = {SystemA, SystemB},
				System = function()
					table.insert(Order, "c")
				end,
			}

			NewLoop:ScheduleSystems({SystemC, SystemB, SystemA})

			local Connection = NewLoop:Begin({Default = BindableEvent.Event})
			expect(#Order).to.equal(0)
			BindableEvent:Fire()

			expect(#Order).to.equal(3)
			expect(Order[1]).to.equal("a")
			expect(Order[2]).to.equal("b")
			expect(Order[3]).to.equal("c")

			Connection.Default:Disconnect()
		end)

		it("should call systems with priority in order", function()
			local NewLoop = Loop.new()
			local Order = {}

			local function CleanupStartReplication()
				table.insert(Order, "e")
			end

			local function ReplicateEnemies()
				table.insert(Order, "d")
			end

			local function SpawnSwords()
				table.insert(Order, "c")
			end

			local function SpawnEnemies()
				table.insert(Order, "b")
			end

			local function Neutral()
				table.insert(Order, "a")
			end

			NewLoop:ScheduleSystems({
				{
					System = SpawnEnemies,
					Priority = 0,
				},

				Neutral,
				{
					System = ReplicateEnemies,
					Priority = 100,
				},

				{
					System = SpawnSwords,
					Priority = 1,
				},

				{
					System = CleanupStartReplication,
					Priority = 5000,
				},
			})

			local Connection = NewLoop:Begin({Default = BindableEvent.Event})
			expect(#Order).to.equal(0)
			BindableEvent:Fire()

			expect(#Order).to.equal(5)
			expect(Order[1]).to.equal("a")
			expect(Order[2]).to.equal("b")
			expect(Order[3]).to.equal("c")
			expect(Order[4]).to.equal("d")
			expect(Order[5]).to.equal("e")

			Connection.Default:Disconnect()
		end)

		it("should call middleware", function()
			local NewLoop = Loop.new(1, 2, 3)

			local Called = {}
			NewLoop:AddMiddleware(function(NextFunction)
				return function()
					table.insert(Called, 2)
					NextFunction()
				end
			end):AddMiddleware(function(NextFunction)
				return function()
					table.insert(Called, 1)
					NextFunction()
				end
			end):ScheduleSystem(function()
				table.insert(Called, 3)
			end)

			local Connection = NewLoop:Begin({Default = BindableEvent.Event})

			expect(#Called).to.equal(0)
			BindableEvent:Fire()
			expect(#Called).to.equal(3)
			expect(Called[1]).to.equal(1)
			expect(Called[2]).to.equal(2)
			expect(Called[3]).to.equal(3)
			Connection.Default:Disconnect()
		end)
	end)
end
