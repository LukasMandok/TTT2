local base = "scalable_hud_element"

DEFINE_BASECLASS(base)

HUDELEMENT.Base = base

HUDELEMENT.ElementList = {}

function HUDELEMENT:Draw()
    local running_y = self.pos.y

    for k, el in ipairs(self.ElementList) do
        self:DrawElement(k, self.pos.x, running_y, self.size.w, el.h)
        running_y = running_y + el.h + self.margin
    end

    local totalHeight = running_y - self.pos.y
    self:SetSize(self.size.w, -totalHeight)
end

--[[----------------------------------------------------------------------------
	Name: DrawElement(number i, number x, number y, number w, number h)
	Desc: Override this function to determine how your element i will be drawn,
          given a position and size
--]]-----------------------------------------------------------------------------
function HUDELEMENT:DrawElement(i, x, y, w, h)

end