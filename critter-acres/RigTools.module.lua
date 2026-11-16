-- Critter Acres: RigTools (ServerStorage ModuleScript, edit-time helper only — nothing in the game requires it)
-- Turns generated pet meshes into animated rigs for StarterPlayerScripts.CritterAnimator:
--   RT.findEyes(meshPart, front)   -> finds the painted eyes (dark spots on the face) from the mesh + texture
--   RT.addFace(model, spec)        -> eyes with lids that blink, pupils/shines that follow you, a mouth that opens
--   RT.assemble(tpl, seg, map, opts) -> builds a "Critter" rig from a segmented mesh (Body + Head/Ears/Tail/...)
-- Face parts "ride" another part (attribute Ride = part name); Face = Lid / Pupil / Glint / Mouth tells the
-- animator how to move them. Lids and mouth are stored hidden (Transparency 1) with Alpha = how they look shown.
local AS = game:GetService("AssetService")
local RT = {}

function RT.ellip(parent, name, size, cf, color, props)
	local p = Instance.new("Part")
	p.Name = name
	p.Size = size
	p.CFrame = cf
	p.Color = color
	p.Material = Enum.Material.SmoothPlastic
	p.Anchored, p.CanCollide, p.CanQuery, p.CanTouch, p.CastShadow = true, false, false, false, false
	p.TopSurface, p.BottomSurface = Enum.SurfaceType.Smooth, Enum.SurfaceType.Smooth
	local sm = Instance.new("SpecialMesh")
	sm.MeshType = Enum.MeshType.Sphere
	sm.Parent = p
	for k, v in props or {} do
		if k == "Ride" or k == "Face" or k == "Alpha" then p:SetAttribute(k, v) else p[k] = v end
	end
	p.Parent = parent
	return p
end

-- Painted eyes: the darkest patches on the front half of the mesh, one on each side.
-- front = the model's forward direction (world). Returns {left = info, right = info, faceY, mid} in world space.
function RT.findEyes(part, front, opts)
	opts = opts or {}
	local em = AS:CreateEditableMeshAsync(Content.fromUri(part.MeshId))
	local img = AS:CreateEditableImageAsync(Content.fromUri(part.TextureID))
	local W, H = img.Size.X, img.Size.Y
	local buf = img:ReadPixelsBuffer(Vector2.zero, img.Size)
	local function px(uv)
		local x = math.clamp(math.floor(uv.X * W), 0, W - 1)
		local y = math.clamp(math.floor(uv.Y * H), 0, H - 1)
		local i = (y * W + x) * 4
		return buffer.readu8(buf, i), buffer.readu8(buf, i + 1), buffer.readu8(buf, i + 2)
	end
	local scale = part.Size / part.MeshSize
	local cf = part.CFrame
	local fl = cf:VectorToObjectSpace(front).Unit -- front in part space
	local side = Vector3.yAxis:Cross(fl).Unit -- sideways in part space
	local verts = {}
	local faces = {}
	local maxF = -1e9
	for _, f in em:GetFaces() do
		local vs = em:GetFaceVertices(f)
		local uvs = em:GetFaceUVs(f)
		if #vs >= 3 then
			local a, b, c = em:GetPosition(vs[1]) * scale, em:GetPosition(vs[2]) * scale, em:GetPosition(vs[3]) * scale
			local uv = (em:GetUV(uvs[1]) + em:GetUV(uvs[2]) + em:GetUV(uvs[3])) / 3
			local r, g, bl = px(uv)
			local cen = (a + b + c) / 3
			local n = (b - a):Cross(c - a)
			if n.Magnitude > 0 then n = n.Unit end
			faces[#faces + 1] = {cen, (r + g + bl) / 3, n, (b - a):Cross(c - a).Magnitude / 2, Color3.fromRGB(r, g, bl)}
			maxF = math.max(maxF, cen:Dot(fl))
		end
	end
	for _, v in em:GetVertices() do verts[#verts + 1] = em:GetPosition(v) * scale end
	-- which way the triangles wind: flip normals so they point out of the mesh
	local mid0 = Vector3.zero
	for _, f in faces do mid0 += f[1] end
	mid0 /= math.max(1, #faces)
	local wind = 0
	for _, f in faces do wind += f[3]:Dot(f[1] - mid0) * f[4] end
	if wind < 0 then for _, f in faces do f[3] = -f[3] end end
	local dark = opts.dark or 55
	local minY = opts.minY or (-part.Size.Y * 0.25) -- eyes are never down at the feet
	local sets = {[-1] = {}, [1] = {}}
	for _, f in faces do
		local p = f[1]
		if f[2] < dark and f[3]:Dot(fl) > (opts.facing or 0.3) and p.Y > minY then
			table.insert(sets[p:Dot(side) < 0 and -1 or 1], f)
		end
	end
	local out = {}
	local lim = opts.radius or part.Size.Y * 0.16
	for s, set in sets do
		if #set == 0 then return nil, "no dark faces on side " .. s end
		-- the densest dark spot (most dark area close by) is the eye; take the faces around it
		local best, bestA = set[1][1], -1
		for _, a in set do
			local area = 0
			for _, b in set do if (a[1] - b[1]).Magnitude < lim then area += b[4] end end
			if area > bestA then best, bestA = a[1], area end
		end
		local mn, mx, n = Vector3.one * 1e9, -Vector3.one * 1e9, Vector3.zero
		local c, wsum, cnt = Vector3.zero, 0, 0
		for _, f in set do
			if (f[1] - best).Magnitude < lim * 1.6 then
				mn, mx, n, cnt = mn:Min(f[1]), mx:Max(f[1]), n + f[3] * f[4], cnt + 1
				c += f[1] * f[4] wsum += f[4]
			end
		end
		c /= math.max(wsum, 1e-9)
		if n.Magnitude < 1e-6 then n = fl end
		local ext = mx - mn
		local w = math.abs(ext:Dot(side)) + math.abs(ext:Dot(fl)) * 0.3
		out[s] = {center = cf:PointToWorldSpace(c), normal = cf:VectorToWorldSpace(n.Unit), w = math.max(w, 0.05), h = math.max(ext.Y, 0.05), count = cnt}
	end
	-- mouth spot: below the eyes in the middle, on the surface (the most forward vertex there)
	local le, re = cf:PointToObjectSpace(out[-1].center), cf:PointToObjectSpace(out[1].center)
	local mid = (le + re) / 2
	local eyeH = (out[-1].h + out[1].h) / 2
	local ty = mid.Y - eyeH * (opts.mouthDrop or 0.95)
	local best, bestF = nil, -1e9
	local sw = (re - le).Magnitude
	for _, v in verts do
		if math.abs((v - mid):Dot(side)) < sw * 0.12 and math.abs(v.Y - ty) < eyeH * 0.25 and v:Dot(fl) > bestF then best, bestF = v, v:Dot(fl) end
	end
	out.mouth = best and cf:PointToWorldSpace(best)
	out.left, out.right = out[-1], out[1]
	-- fur color around the eyes (for the eyelids)
	local fr, fg, fb, fn = 0, 0, 0, 0
	for _, f in faces do
		if f[2] > 110 and ((f[1] - le).Magnitude < lim * 3 or (f[1] - re).Magnitude < lim * 3) then
			fr += f[5].R fg += f[5].G fb += f[5].B fn += 1
		end
	end
	out.fur = fn > 0 and Color3.new(fr / fn, fg / fn, fb / fn) or Color3.fromRGB(240, 230, 220)
	return out
end

-- The whole upgrade of one pet: segmented parts + face -> new ReplicatedStorage.PetModels[name]
-- (the old one-piece model is kept in ServerStorage.OldPetModels). o.mirror = "A"/"B" forces using one eye mirrored.
function RT.build(name, seg, map, o)
	o = o or {}
	local pm = game:GetService("ReplicatedStorage").PetModels
	local tpl = pm[name]
	local piv = tpl:GetPivot()
	local front = piv.LookVector
	local orig = (o.eyesPart and seg:FindFirstChild(o.eyesPart, true)) or tpl:FindFirstChild("body_geom") or tpl.PrimaryPart
	local eyes, err = RT.findEyes(orig, front, o.find)
	if not eyes then return nil, "eyes: " .. tostring(err) end
	local A, B = eyes.left, eyes.right
	local la, lb = piv:PointToObjectSpace(A.center), piv:PointToObjectSpace(B.center)
	if o.mirror or math.abs(la.Y - lb.Y) > 0.2 or math.abs(math.abs(la.X) - math.abs(lb.X)) > 0.25 or math.abs(la.Z - lb.Z) > 0.25 then
		local good = (o.mirror == "A" or (o.mirror ~= "B" and la.Y < lb.Y + 0.6 and A.count >= B.count)) and A or B
		local gl = piv:PointToObjectSpace(good.center)
		local nl = piv:VectorToObjectSpace(good.normal)
		A, B = good, {center = piv:PointToWorldSpace(Vector3.new(-gl.X, gl.Y, gl.Z)), normal = piv:VectorToWorldSpace(Vector3.new(-nl.X, nl.Y, nl.Z)),
			w = good.w, h = good.h, count = good.count}
	end
	local m, parts = RT.assemble(tpl, seg, map)
	if not m then return nil, parts end
	for k, v in tpl:GetAttributes() do if k ~= "Rig" then m:SetAttribute(k, v) end end
	local ordered = {A, B}
	table.sort(ordered, function(a, b) return piv:PointToObjectSpace(a.center).X < piv:PointToObjectSpace(b.center).X end)
	local grow = o.eyeGrow or 1.3
	for _, e in ordered do
		local s = math.max(e.w, e.h) * grow
		e.w, e.h = math.max(e.w * grow, s * 0.75), math.max(e.h * grow, s * 0.85)
	end
	local mid = (ordered[1].center + ordered[2].center) / 2
	local eh = (ordered[1].h + ordered[2].h) / 2
	local mouth = eyes.mouth
	if not mouth or piv:PointToObjectSpace(mouth).Z > piv:PointToObjectSpace(mid).Z + 0.15 or (mid - mouth).Magnitude > eh * 3 then
		mouth = mid - Vector3.new(0, eh * 1.1, 0) + front * 0.04
	end
	RT.addFace(m, {rideTo = parts.Head and "Head" or "Body", eyes = ordered, front = front, frontBias = 0.8,
		iris = o.iris or Color3.fromRGB(24, 22, 30), lid = o.lid or eyes.fur, grow = 1, depth = 0.4, sink = 0.2,
		mouth = mouth, mouthSize = math.max(0.16, eh * 0.7)})
	local old = game:GetService("ServerStorage"):FindFirstChild("OldPetModels") or Instance.new("Folder")
	old.Name = "OldPetModels"
	old.Parent = game:GetService("ServerStorage")
	if old:FindFirstChild(name) then old[name]:Destroy() end
	tpl.Parent = old
	m.Parent = pm
	seg:Destroy()
	local names = {}
	for _, p in m:GetChildren() do if p:IsA("BasePart") then names[#names + 1] = p.Name end end
	return m, table.concat(names, ",")
end

-- spec: rideTo (part name), front (world), eyes = {{center, normal, w, h}, {..}}, iris, neon, pupil (size factor or nil),
--       glints, lid (Color3), mouth (world point or nil), mouthSize, sink (0..1 how deep the eye sits), grow (overlay scale)
function RT.addFace(model, spec)
	local ride = model:FindFirstChild(spec.rideTo)
	local up = ride.CFrame.UpVector
	if spec.front then up = (Vector3.yAxis - spec.front * spec.front.Y).Unit end
	local made = {}
	for i, e in spec.eyes do
		local s = i == 1 and "L" or "R"
		local g = spec.grow or 1.1
		local w, h = e.w * g, e.h * g
		local depth = math.min(w, h) * (spec.depth or 0.45)
		local n = e.normal
		if spec.front then n = (n + spec.front * (spec.frontBias or 0.6)).Unit end
		local c = e.center - n * depth * (spec.sink or 0.15)
		local cf = CFrame.lookAt(c, c + n, up)
		local eye = RT.ellip(model, "Eye" .. s, Vector3.new(w, h, depth), cf, spec.iris,
			{Ride = spec.rideTo, Material = spec.neon and Enum.Material.Neon or Enum.Material.SmoothPlastic, Reflectance = spec.neon and 0 or 0.12})
		made[#made + 1] = eye
		if spec.pupil then
			local ps = spec.pupil
			made[#made + 1] = RT.ellip(model, "Pupil" .. s, Vector3.new(w * ps.X, h * ps.Y, depth * 0.4), cf * CFrame.new(0, 0, -depth * 0.36),
				spec.pupilColor or Color3.fromRGB(15, 15, 20), {Ride = eye.Name, Face = "Pupil"})
		end
		if spec.glints ~= false then
			made[#made + 1] = RT.ellip(model, "Glint" .. s, Vector3.new(h * 0.26, h * 0.26, depth * 0.3), cf * CFrame.new(w * 0.18, h * 0.2, -depth * 0.46),
				Color3.new(1, 1, 1), {Ride = eye.Name, Face = "Glint", Material = Enum.Material.Neon})
			made[#made + 1] = RT.ellip(model, "Glint2" .. s, Vector3.new(h * 0.13, h * 0.13, depth * 0.3), cf * CFrame.new(-w * 0.16, -h * 0.2, -depth * 0.46),
				Color3.new(1, 1, 1), {Ride = eye.Name, Face = "Glint", Material = Enum.Material.Neon})
		end
		made[#made + 1] = RT.ellip(model, "Lid" .. s, Vector3.new(w * 1.14, h * 1.14, depth * 1.25), cf * CFrame.new(0, 0, -depth * 0.12), spec.lid,
			{Ride = spec.rideTo, Face = "Lid", Alpha = 0, Transparency = 1})
	end
	if spec.mouth then
		local n = spec.front or ride.CFrame.LookVector
		local ms = spec.mouthSize
		made[#made + 1] = RT.ellip(model, "Mouth", Vector3.new(ms, ms * 0.8, ms * 0.35), CFrame.lookAt(spec.mouth - n * ms * 0.05, spec.mouth + n, up),
			spec.mouthColor or Color3.fromRGB(120, 40, 60), {Ride = spec.rideTo, Face = "Mouth", Alpha = 0, Transparency = 1})
	end
	return made
end

-- Joint = the point of the part's box closest to the body center (where it attaches), as a fraction of its size.
function RT.joint(part, bodyCenter)
	local l = part.CFrame:PointToObjectSpace(bodyCenter)
	local hs = part.Size / 2
	local j = Vector3.new(math.clamp(l.X, -hs.X, hs.X), math.clamp(l.Y, -hs.Y, hs.Y), math.clamp(l.Z, -hs.Z, hs.Z))
	return j / part.Size
end

-- seg: the model segment_mesh made; map: {[segName] = rigName}. Sideways names get L/R from their position.
function RT.assemble(tpl, seg, map, opts)
	opts = opts or {}
	local pivot = tpl:GetPivot()
	local m = Instance.new("Model")
	m.Name = tpl.Name
	local parts = {}
	for _, p in seg:GetDescendants() do
		if p:IsA("BasePart") then
			p.CFrame = pivot * CFrame.Angles(0, math.pi, 0) * pivot:ToObjectSpace(p.CFrame) -- segment_mesh hands its pieces back turned 180°
			local key = p.Name:lower()
			local name = map[key]
			if name then
				if name:sub(-1) == "*" then -- side part: L/R from where it sits
					name = name:sub(1, -2) .. (pivot:PointToObjectSpace(p.Position).X < 0 and "L" or "R")
				end
				if parts[name] then name = name .. "2" end
				p.Name = name
				p.Anchored, p.CanCollide, p.CanTouch = true, false, false
				p.Parent = m
				parts[name] = p
			end
		end
	end
	local body = parts.Body
	if not body then return nil, "no body part" end
	m.PrimaryPart = body
	for name, p in parts do
		if p ~= body then p:SetAttribute("JointFrac", RT.joint(p, body.Position)) end
	end
	m.WorldPivot = pivot
	body.PivotOffset = body.CFrame:ToObjectSpace(pivot) -- the pet's pivot stays where it was (whole-pet center)
	m:SetAttribute("Rig", "Critter")
	return m, parts
end

return RT
