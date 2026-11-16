-- Critter Acres: MobRigBuild (ServerStorage ModuleScript, Studio tool only)
-- Turns a freshly generated mob (generate_mesh with explicit parts incl. "left eye"/"right eye") into an
-- animatable rig in ServerStorage.MobModels.<Land>: parts renamed to the rig layout (Body, Head, Crest, Ear*,
-- Arm*, Wing*, Feet, Tail, Shell ...), JointFrac on every limb, eyes as riders, plus glints, blinking lids
-- (fur coloured) and a mouth. MobAnimator brings the result to life.
-- job = {name, tag (generation tag), map = {{segKey, RigName}, ...} (first match wins; "X*" = X + L/R by side),
--        height, land, attrs = {...}}
local CS = game:GetService("CollectionService")
local AS = game:GetService("AssetService")
local RT = require(game.ServerStorage.RigTools:Clone())

local M = {}

local function clean(n) return (n:lower():gsub('[%[%]"\\]', ""):gsub("_geom", "")) end

-- average texture color of a mesh part's surface near a world point (for eyelids that match the fur)
function M.furNear(part, at, radius)
	local ok, img = pcall(function() return AS:CreateEditableImageAsync(Content.fromUri(part.TextureID)) end)
	if not ok then return Color3.fromRGB(235, 225, 210) end
	local em = AS:CreateEditableMeshAsync(Content.fromUri(part.MeshId))
	local W, H = img.Size.X, img.Size.Y
	local buf = img:ReadPixelsBuffer(Vector2.zero, img.Size)
	local sc = part.Size / part.MeshSize
	local r, g, b, n = 0, 0, 0, 0
	for _, f in em:GetFaces() do
		local vs, uvs = em:GetFaceVertices(f), em:GetFaceUVs(f)
		local c, uv = Vector3.zero, Vector2.zero
		for k, v in vs do c += em:GetPosition(v) * sc uv += em:GetUV(uvs[k]) end
		c /= #vs uv /= #vs
		if (part.CFrame:PointToWorldSpace(c) - at).Magnitude < radius then
			local x = math.clamp(math.floor(uv.X * W), 0, W - 1)
			local y = math.clamp(math.floor(uv.Y * H), 0, H - 1)
			local i = (y * W + x) * 4
			local rr, gg, bb = buffer.readu8(buf, i), buffer.readu8(buf, i + 1), buffer.readu8(buf, i + 2)
			if (rr + gg + bb) / 3 > 90 then r += rr g += gg b += bb n += 1 end
		end
	end
	return n > 0 and Color3.fromRGB(r / n, g / n, b / n) or Color3.fromRGB(235, 225, 210)
end

-- replace `bad` with a copy of `good` mirrored across the body's center plane
local function mirrorInto(m, good, bad, cx)
	local piv = m:GetPivot()
	local gl = piv:ToObjectSpace(good.CFrame)
	local mirrored = CFrame.new(2 * cx - gl.X, gl.Y, gl.Z) * (gl - gl.Position) * CFrame.Angles(0, math.pi, 0)
	local c = good:Clone()
	c.Name = bad.Name
	c.CFrame = piv * mirrored
	c.Parent = bad.Parent
	bad:Destroy()
	return c
end

-- how far the part reaches out along a direction from its center
local function reach(p, dir)
	local c = p.CFrame
	return (math.abs(dir:Dot(c.RightVector)) * p.Size.X + math.abs(dir:Dot(c.UpVector)) * p.Size.Y + math.abs(dir:Dot(c.LookVector)) * p.Size.Z) / 2
end

-- shines, blinking lids and mouth, placed on the front surface of each eye (some generated eyes are deep blobs)
local function eyeExtras(m, rideTo, fur)
	local front = m:GetPivot().LookVector
	local eh, fwd = 0, 0
	for _, s in {"L", "R"} do
		local e = m:FindFirstChild("Eye" .. s)
		local d = math.max(e.Size.X, e.Size.Y) * 1.15
		eh += d / 2
		local out = reach(e, front)
		fwd += out / 2
		local surf = e.Position + front * out
		local cf = CFrame.lookAt(surf, surf + front)
		RT.ellip(m, "Glint" .. s, Vector3.new(d * 0.3, d * 0.3, d * 0.12), cf * CFrame.new(d * 0.16, d * 0.18, -d * 0.03), Color3.new(1, 1, 1), {Ride = e.Name, Face = "Glint", Material = Enum.Material.Neon})
		RT.ellip(m, "Glint2" .. s, Vector3.new(d * 0.15, d * 0.15, d * 0.1), cf * CFrame.new(-d * 0.15, -d * 0.16, -d * 0.03), Color3.new(1, 1, 1), {Ride = e.Name, Face = "Glint", Material = Enum.Material.Neon})
		RT.ellip(m, "Lid" .. s, Vector3.new(d * 1.3, d * 1.3, d * 0.75), cf * CFrame.new(0, 0, d * 0.22), fur, {Ride = rideTo, Face = "Lid", Alpha = 0, Transparency = 1})
	end
	local L, R = m.EyeL, m.EyeR
	local mid = (L.Position + R.Position) / 2 - Vector3.new(0, eh * 1.5, 0) + front * (fwd * 0.7 + 0.02)
	local ms = math.max(0.16, eh * 1.1)
	RT.ellip(m, "Mouth", Vector3.new(ms, ms * 0.8, ms * 0.35), CFrame.lookAt(mid, mid + front), Color3.fromRGB(120, 40, 60), {Ride = rideTo, Face = "Mouth", Alpha = 0, Transparency = 1})
end

local function rig(m, map)
	local raw = {}
	for _, p in m:GetDescendants() do if p:IsA("BasePart") then raw[#raw + 1] = p end end
	local bodyKey
	for _, k in map do if k[2] == "Body" then bodyKey = k[1] end end
	local bodyPart
	for _, p in raw do if clean(p.Name):find(bodyKey, 1, true) then bodyPart = p end end
	local ref = bodyPart and bodyPart.Position or m:GetBoundingBox().Position
	local rot = m:GetPivot() - m:GetPivot().Position
	local parts = {}
	for _, p in raw do
		local low = clean(p.Name)
		local name
		for _, k in map do if low == k[1] or low:find(k[1], 1, true) then name = k[2] break end end
		if name then
			if name:sub(-1) == "*" then name = name:sub(1, -2) .. ((rot:VectorToObjectSpace(p.Position - ref)).X < 0 and "L" or "R") end
			if parts[name] then
				-- two of a side: the one further out keeps it, the other takes the free side if there is one
				local other = name:sub(-1) == "L" and name:sub(1, -2) .. "R" or (name:sub(-1) == "R" and name:sub(1, -2) .. "L")
				if other and not parts[other] then name = other else name ..= "2" end
			end
			p.Name = name
			p.Anchored, p.CanCollide, p.CanTouch = true, false, false
			p:SetAttribute("Ride", nil)
			p:SetAttribute("JointFrac", nil)
			parts[name] = p
		end
	end
	for _, p in parts do p.Parent = m end
	for _, c in m:GetChildren() do if c:IsA("Model") or (c:IsA("BasePart") and not parts[c.Name]) then c:Destroy() end end
	local body = parts.Body
	if not body then return nil, "no body part" end
	m.PrimaryPart = body
	-- eyes: if one came out much bigger/odd, mirror the cleaner one onto the other side
	if parts.EyeL and parts.EyeR then
		local a, b = parts.EyeL, parts.EyeR
		local va, vb = a.Size.X * a.Size.Y * a.Size.Z, b.Size.X * b.Size.Y * b.Size.Z
		local ratio = math.max(va, vb) / math.max(math.min(va, vb), 1e-4)
		if ratio > 2 then
			local cx = m:GetPivot():PointToObjectSpace(body.Position).X
			local good, bad = (va < vb) and a or b, (va < vb) and b or a
			parts[bad.Name] = mirrorInto(m, good, bad, cx)
		end
	end
	local rideTo = parts.Head and "Head" or "Body"
	for n, p in parts do
		if n == "EyeL" or n == "EyeR" then p:SetAttribute("Ride", rideTo) p.CanQuery = false
		elseif p ~= body then p:SetAttribute("JointFrac", RT.joint(p, body.Position)) end
	end
	body.PivotOffset = body.CFrame:ToObjectSpace(CFrame.new(m:GetBoundingBox().Position) * rot)
	m:SetAttribute("Rig", "Critter")
	return parts, rideTo
end

local function finish(m, height)
	local _, sz = m:GetBoundingBox()
	m:ScaleTo(m:GetScale() * height / sz.Y)
	local _, sz2 = m:GetBoundingBox()
	m:PivotTo(CFrame.new(0, sz2.Y / 2, 0))
	return sz2
end

-- redo the shines/lids/mouth of an already-built mob (keeps its lid colour)
function M.reface(m)
	local fur = m:FindFirstChild("LidL") and m.LidL.Color or Color3.fromRGB(235, 225, 210)
	local rideTo = m:FindFirstChild("Head") and "Head" or "Body"
	for _, c in m:GetChildren() do if c:GetAttribute("Face") then c:Destroy() end end
	eyeExtras(m, rideTo, fur)
	return m.Name
end

function M.build(job)
	local m = CS:GetTagged(job.tag)[1]
	if not m then return job.name .. ": generation not found" end
	for _, t in CS:GetTags(m) do CS:RemoveTag(m, t) end
	m.Name = job.name
	for _, c in m:GetChildren() do if c:GetAttribute("Face") then c:Destroy() end end
	local parts, rideTo = rig(m, job.map)
	if not parts then return job.name .. ": " .. tostring(rideTo) end
	if parts.EyeL and parts.EyeR then
		eyeExtras(m, rideTo, M.furNear(parts[rideTo], (parts.EyeL.Position + parts.EyeR.Position) / 2, math.max(parts.EyeL.Size.X, 0.3) * 3))
	end
	for k, v in job.attrs or {} do m:SetAttribute(k, v) end
	local sz = finish(m, job.height)
	local store = game.ServerStorage.MobModels:FindFirstChild(job.land)
	if store:FindFirstChild(job.name) and store[job.name] ~= m then store[job.name]:Destroy() end
	m.Parent = store
	local names = {}
	for _, p in m:GetChildren() do if p:IsA("BasePart") and not p:GetAttribute("Face") then names[#names + 1] = p.Name end end
	table.sort(names)
	return ("%s/%s %.1fx%.1fx%.1f (d/w %.2f): %s"):format(job.land, job.name, sz.X, sz.Y, sz.Z,
		math.min(sz.X, sz.Z) / math.max(sz.X, sz.Z), table.concat(names, ","))
end

return M
