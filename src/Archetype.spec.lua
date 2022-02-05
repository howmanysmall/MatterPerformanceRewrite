return function()
	local Archetype = require(script.Parent.Archetype)
	local Component = require(script.Parent).Component

	describe("Archetype", function()
		it("should report same sets as same archetype", function()
			local A = Component()
			local B = Component()
			expect(Archetype.ArchetypeOf(A, B)).to.equal(Archetype.ArchetypeOf(B, A))
		end)

		it("should identify compatible archetypes", function()
			local A = Component()
			local B = Component()
			local C = Component()

			local ArchetypeA = Archetype.ArchetypeOf(A, B, C)
			local ArchetypeB = Archetype.ArchetypeOf(A, B)
			local ArchetypeC = Archetype.ArchetypeOf(B, C)

			expect(Archetype.AreArchetypesCompatible(ArchetypeA, ArchetypeB)).to.equal(false)
			expect(Archetype.AreArchetypesCompatible(ArchetypeB, ArchetypeA)).to.equal(true)

			expect(Archetype.AreArchetypesCompatible(ArchetypeC, ArchetypeA)).to.equal(true)
			expect(Archetype.AreArchetypesCompatible(ArchetypeB, ArchetypeC)).to.equal(false)
		end)
	end)
end
