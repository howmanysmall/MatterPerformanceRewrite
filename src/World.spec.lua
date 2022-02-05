local function DeepEquals(A, B)
	if type(A) ~= "table" or type(B) ~= "table" then
		return A == B
	end

	for Key, ValueA in next, A do
		local ValueB = B[Key]
		if type(ValueA) == "table" and type(ValueB) == "table" then
			local Result = DeepEquals(ValueA, ValueB)
			if not Result then
				return false
			end
		elseif ValueA ~= ValueB then
			return false
		end
	end

	-- extra keys in b
	for Key in next, B do
		if A[Key] == nil then
			return false
		end
	end

	return true
end

local function AssertDeepEqual(A, B)
	if not DeepEquals(A, B) then
		print("EXPECTED:", B)
		print("GOT:", A)
		error("Tables were not deep-equal")
	end
end

return function()
	local Component = require(script.Parent).Component
	local Loop = require(script.Parent.Loop)
	local World = require(script.Parent.World)

	describe("World", function()
		it("should have correct size", function()
			local NewWorld = World.new()
			NewWorld:Spawn()
			NewWorld:Spawn()
			NewWorld:Spawn()

			local Id = NewWorld:Spawn()
			NewWorld:Despawn(Id)

			expect(NewWorld.Size).to.equal(3)
			NewWorld:Clear()
			expect(NewWorld.Size).to.equal(0)
		end)

		it("should report contains correctly", function()
			local NewWorld = World.new()
			local Id = NewWorld:Spawn()

			expect(NewWorld:Contains(Id)).to.equal(true)
			expect(NewWorld:Contains(1234124124124124124124)).to.equal(false)
		end)

		it("should allow inserting and removing components from existing entities", function()
			local NewWorld = World.new()

			local HealthComponent = Component()
			local PlayerComponent = Component()
			local PoisonComponent = Component()

			local Id = NewWorld:Spawn(PlayerComponent(), PoisonComponent())

			expect(NewWorld:Query(PlayerComponent):Next()).to.be.ok()
			expect(NewWorld:Query(HealthComponent):Next()).to.never.be.ok()

			NewWorld:Insert(Id, HealthComponent())

			expect(NewWorld:Query(PlayerComponent):Next()).to.be.ok()
			expect(NewWorld:Query(HealthComponent):Next()).to.be.ok()
			expect(NewWorld.Size).to.equal(1)

			local Player, Poison = NewWorld:Remove(Id, PlayerComponent, PoisonComponent)

			expect(getmetatable(Player)).to.equal(PlayerComponent)
			expect(getmetatable(Poison)).to.equal(PoisonComponent)

			expect(NewWorld:Query(PlayerComponent):Next()).to.never.be.ok()
			expect(NewWorld:Query(HealthComponent):Next()).to.be.ok()
			expect(NewWorld.Size).to.equal(1)
		end)

		it("should be queryable", function()
			local NewWorld = World.new()

			local HealthComponent = Component()
			local PlayerComponent = Component()
			local PoisonComponent = Component()

			local One = NewWorld:Spawn(PlayerComponent({
				Name = "Alice",
			}), HealthComponent({
				Value = 100,
			}), PoisonComponent())

			NewWorld:Spawn( -- Spawn something we don't want to get back
				Component(),
				Component()
			)

			local Two = NewWorld:Spawn(PlayerComponent({
				Name = "Bob",
			}), HealthComponent({
				Value = 99,
			}))

			local Found = {}
			local FoundCount = 0

			for EntityId, Player, Health in NewWorld:Query(PlayerComponent, HealthComponent) do
				FoundCount += 1
				Found[EntityId] = {
					[PlayerComponent] = Player,
					[HealthComponent] = Health,
				}
			end

			expect(FoundCount).to.equal(2)

			expect(Found[One]).to.be.ok()
			expect(Found[One][PlayerComponent].Name).to.equal("Alice")
			expect(Found[One][HealthComponent].Value).to.equal(100)

			expect(Found[Two]).to.be.ok()
			expect(Found[Two][PlayerComponent].Name).to.equal("Bob")
			expect(Found[Two][HealthComponent].Value).to.equal(99)

			local Count = 0
			for Id, Player in NewWorld:Query(PlayerComponent) do
				expect(type(Player.Name)).to.equal("string")
				expect(type(Id)).to.equal("number")
				Count += 1
			end

			expect(Count).to.equal(2)
			local WithoutCount = 0
			for _ in NewWorld:Query(PlayerComponent):Without(PoisonComponent) do
				WithoutCount += 1
			end

			expect(WithoutCount).to.equal(1)
		end)

		it("should allow getting single components", function()
			local NewWorld = World.new()

			local PlayerComponent = Component()
			local HealthComponent = Component()
			local OtherComponent = Component()

			local Id = NewWorld:Spawn(OtherComponent({A = 1}), PlayerComponent({B = 2}), HealthComponent({C = 3}))

			expect(NewWorld:Get(Id, PlayerComponent).B).to.equal(2)
			expect(NewWorld:Get(Id, HealthComponent).C).to.equal(3)

			local One, Two = NewWorld:Get(Id, HealthComponent, PlayerComponent)

			expect(One.C).to.equal(3)
			expect(Two.B).to.equal(2)
		end)

		it("should track changes", function()
			local NewWorld = World.new()
			local NewLoop = Loop.new(NewWorld)

			local A = Component()
			local B = Component()
			local C = Component()

			local ExpectedResults = {
				nil,
				{
					0,
					{
						New = {Generation = 1},
						new = {Generation = 1},
					},
				},

				{
					1,
					{
						New = {Generation = 1},
						new = {Generation = 1},
					},
				},

				{
					0,
					{
						New = {Generation = 2},
						Old = {Generation = 1},
						new = {Generation = 2},
						old = {Generation = 1},
					},
				},

				nil,
				{
					1,
					{
						Old = {Generation = 1},
						old = {Generation = 1},
					},
				},

				{
					0,
					{
						Old = {Generation = 2},
						old = {Generation = 2},
					},
				},
			}

			local ResultIndex = 0
			local AdditionalQuery = C
			NewLoop:ScheduleSystem(function(SystemWorld)
				local Ran = false
				for EntityId, Record in SystemWorld:QueryChanged(A, AdditionalQuery) do
					Ran = true
					ResultIndex += 1

					expect(EntityId).to.equal(ExpectedResults[ResultIndex][1])
					AssertDeepEqual(Record, ExpectedResults[ResultIndex][2])
				end

				if not Ran then
					ResultIndex += 1
					expect(ExpectedResults[ResultIndex]).to.equal(nil)
				end
			end)

			local InfrequentCount = 0
			NewLoop:ScheduleSystem({
				Event = "Infrequent",
				System = function(SystemWorld)
					InfrequentCount += 1

					local Count = 0
					local Results = {}
					for EntityId, Record in SystemWorld:QueryChanged(A) do
						Count += 1
						Results[EntityId] = Record
					end

					if Count == 0 then
						expect(InfrequentCount).to.equal(1)
					else
						expect(InfrequentCount).to.equal(2)
						expect(Count).to.equal(2)

						expect(Results[0].Old.Generation).to.equal(2)
						expect(Results[1].Old.Generation).to.equal(1)
					end
				end,
			})

			local DefaultBindable = Instance.new("BindableEvent")
			local InfrequentBindable = Instance.new("BindableEvent")

			local Connections = NewLoop:Begin({
				Default = DefaultBindable.Event,
				Infrequent = InfrequentBindable.Event,
			})

			DefaultBindable:Fire()
			InfrequentBindable:Fire()

			local EntityId = NewWorld:Spawn(A({
				Generation = 1,
			}), C())

			DefaultBindable:Fire()
			AdditionalQuery = nil
			NewWorld:Insert(EntityId, A({
				Generation = 2,
			}))

			NewWorld:Insert(EntityId, B({
				Foo = "Bar",
			}))

			local SecondEntityId = NewWorld:Spawn(A({
				Generation = 1,
			}), C())

			DefaultBindable:Fire()
			DefaultBindable:Fire()

			NewWorld:Replace(SecondEntityId, B())
			NewWorld:Despawn(EntityId)

			DefaultBindable:Fire()
			InfrequentBindable:Fire()

			Connections.Default:Disconnect()
			Connections.Infrequent:Disconnect()
		end)
	end)
end
