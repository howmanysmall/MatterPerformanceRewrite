return function()
	local NewComponent = require(script.Parent.NewComponent)
	local None = require(script.Parent.Immutable.None)

	describe("Component", function()
		it("should create components", function()
			local A = NewComponent()
			local B = NewComponent()

			expect(getmetatable(A)).to.be.ok()
			expect(getmetatable(A)).to.never.equal(getmetatable(B))
			expect(typeof(A.new)).to.equal("function")
		end)

		it("should allow calling the table to construct", function()
			local A = NewComponent()
			expect(getmetatable(A())).to.equal(getmetatable(A.new()))
		end)

		it("should allow patching into a new component", function()
			local A = NewComponent()
			local ComponentA = A({
				Foo = "Bar",
				Unset = true,
			})

			local ComponentA2 = ComponentA:Patch({
				Baz = "Qux",
				Unset = None,
			})

			expect(ComponentA2.Foo).to.equal("Bar")
			expect(ComponentA2.Unset).to.equal(nil)
			expect(ComponentA2.Baz).to.equal("Qux")
		end)
	end)
end
