extends RefCounted
## Rigid, faceted equipment at metre scale; no garment or skin vertices attached.
static func sprayer_tank() -> ArrayMesh:
	var brass := Color(0.56,0.36,0.13)
	var bamboo := Color(0.62,0.44,0.23)
	var leather := Color(0.12,0.075,0.04)
	var parts: Array = [[LowPoly._cyl(.115,.115,.36,8),LowPoly._at(Vector3.ZERO),bamboo],
		[LowPoly._cyl(.119,.119,.025,8),LowPoly._at(Vector3(0,.13,0)),leather],
		[LowPoly._cyl(.119,.119,.025,8),LowPoly._at(Vector3(0,-.13,0)),leather],
		[LowPoly._cyl(.075,.114,.035,8),LowPoly._at(Vector3(0,.195,0)),brass],
		[LowPoly._cyl(.032,.032,.025,6),LowPoly._at(Vector3(0,.225,0)),leather],
		[LowPoly._cyl(.018,.018,.32,6),LowPoly._at(Vector3(.137,0,0)),brass]]
	for x in [-.075,.075]:
		parts.append([LowPoly._box(Vector3(.022,.36,.018)),LowPoly._at(Vector3(x,0,.11)),leather])
	var result := LowPoly.compose(parts)
	result.surface_set_material(0,LowPoly.vertex_color_material())
	return result
