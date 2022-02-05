return function()
	local TopoRuntime = require(script.Parent.TopoRuntime)
	describe("TopoRuntime", function()
		it("should restore state", function()
			local function UseHook()
				local Storage = TopoRuntime.UseHookState()
				Storage.Counter = (Storage.Counter or 0) + 1
				return Storage.Counter
			end

			local Node = {
				System = {},
			}

			local RanCount = 0
			local function Function()
				RanCount += 1
				expect(UseHook()).to.equal(RanCount)
			end

			TopoRuntime.Start(Node, Function)
			TopoRuntime.Start(Node, Function)
			expect(RanCount).to.equal(2)
		end)

		it("should cleanup", function()
			local ShouldCleanup = false
			local CleanedUpCount = 0
			local function UseHook()
				local Storage = TopoRuntime.UseHookState(nil, function()
					if ShouldCleanup then
						CleanedUpCount += 1
					else
						return true
					end
				end)

				Storage.Counter = (Storage.Counter or 0) + 1
				return Storage.Counter
			end

			local Node = {
				System = {},
			}

			local ShouldRunHook = true
			local function Function()
				if ShouldRunHook then
					expect(UseHook()).to.equal(1)
				end
			end

			TopoRuntime.Start(Node, Function)
			expect(CleanedUpCount).to.equal(0)

			ShouldRunHook = false
			TopoRuntime.Start(Node, Function)
			expect(CleanedUpCount).to.equal(0)

			ShouldCleanup = true
			TopoRuntime.Start(Node, Function)
			expect(CleanedUpCount).to.equal(1)

			ShouldRunHook = true
			TopoRuntime.Start(Node, Function)
			expect(CleanedUpCount).to.equal(1)
		end)

		it("should allow keying by unique values", function()
			local function UseHook(Unique)
				local Storage = TopoRuntime.UseHookState(Unique)
				Storage.Counter = (Storage.Counter or 0) + 1
				return Storage.Counter
			end

			local Node = {
				System = {},
			}

			local RanCount = 0
			local function Function()
				RanCount += 1
				expect(UseHook("a value")).to.equal(RanCount)
			end

			TopoRuntime.Start(Node, Function)
			TopoRuntime.Start(Node, Function)
			expect(RanCount).to.equal(2)

			TopoRuntime.Start(Node, function()
				Function()
				Function()
			end)

			expect(RanCount).to.equal(4)
		end)
	end)
end
