class_name VisualMaterialFactory
extends RefCounted

# VisualMaterialFactory
# High-fidelity procedural PBR textures & materials for monsters and environmental props.
# Eliminates flat untextured "AI block threejs" plastic aesthetics using procedural normal maps,
# organic subsurface scattering, micro-roughness variations, and atmospheric rim lighting.

static var _cached_organic_normal: NoiseTexture2D = null
static var _cached_chitin_normal: NoiseTexture2D = null
static var _cached_cloth_normal: NoiseTexture2D = null
static var _cached_stone_normal: NoiseTexture2D = null
static var _cached_bone_normal: NoiseTexture2D = null
static var _cached_flesh_roughness: NoiseTexture2D = null

static func get_organic_normal() -> NoiseTexture2D:
	if _cached_organic_normal:
		return _cached_organic_normal
	var fnl = FastNoiseLite.new()
	fnl.noise_type = FastNoiseLite.TYPE_SIMPLEX
	fnl.frequency = 0.035
	fnl.fractal_octaves = 4
	fnl.fractal_gain = 0.65
	var tex = NoiseTexture2D.new()
	tex.width = 256
	tex.height = 256
	tex.noise = fnl
	tex.as_normal_map = true
	tex.bump_strength = 3.6
	_cached_organic_normal = tex
	return tex

static func get_chitin_normal() -> NoiseTexture2D:
	if _cached_chitin_normal:
		return _cached_chitin_normal
	var fnl = FastNoiseLite.new()
	fnl.noise_type = FastNoiseLite.TYPE_CELLULAR
	fnl.frequency = 0.045
	fnl.cellular_distance_function = FastNoiseLite.DISTANCE_EUCLIDEAN
	fnl.cellular_return_type = FastNoiseLite.RETURN_CELL_VALUE
	var tex = NoiseTexture2D.new()
	tex.width = 256
	tex.height = 256
	tex.noise = fnl
	tex.as_normal_map = true
	tex.bump_strength = 2.8
	_cached_chitin_normal = tex
	return tex

static func get_cloth_normal() -> NoiseTexture2D:
	if _cached_cloth_normal:
		return _cached_cloth_normal
	var fnl = FastNoiseLite.new()
	fnl.noise_type = FastNoiseLite.TYPE_PERLIN
	fnl.frequency = 0.09
	fnl.fractal_octaves = 3
	var tex = NoiseTexture2D.new()
	tex.width = 256
	tex.height = 256
	tex.noise = fnl
	tex.as_normal_map = true
	tex.bump_strength = 2.2
	_cached_cloth_normal = tex
	return tex

static func get_stone_normal() -> NoiseTexture2D:
	if _cached_stone_normal:
		return _cached_stone_normal
	var fnl = FastNoiseLite.new()
	fnl.noise_type = FastNoiseLite.TYPE_PERLIN
	fnl.frequency = 0.05
	fnl.fractal_octaves = 4
	fnl.fractal_gain = 0.7
	var tex = NoiseTexture2D.new()
	tex.width = 256
	tex.height = 256
	tex.noise = fnl
	tex.as_normal_map = true
	tex.bump_strength = 3.8
	_cached_stone_normal = tex
	return tex

static func get_bone_normal() -> NoiseTexture2D:
	if _cached_bone_normal:
		return _cached_bone_normal
	var fnl = FastNoiseLite.new()
	fnl.noise_type = FastNoiseLite.TYPE_SIMPLEX
	fnl.frequency = 0.06
	var tex = NoiseTexture2D.new()
	tex.width = 256
	tex.height = 256
	tex.noise = fnl
	tex.as_normal_map = true
	tex.bump_strength = 2.4
	_cached_bone_normal = tex
	return tex

static func get_flesh_roughness() -> NoiseTexture2D:
	if _cached_flesh_roughness:
		return _cached_flesh_roughness
	var fnl = FastNoiseLite.new()
	fnl.noise_type = FastNoiseLite.TYPE_PERLIN
	fnl.frequency = 0.04
	var tex = NoiseTexture2D.new()
	tex.width = 256
	tex.height = 256
	tex.noise = fnl
	_cached_flesh_roughness = tex
	return tex

# Procedural Flesh / Predator Skin Material
static func create_flesh_material(base_color: Color, wet: bool = true, bump_multiplier: float = 1.0) -> StandardMaterial3D:
	var mat = StandardMaterial3D.new()
	mat.albedo_color = base_color
	mat.normal_enabled = true
	mat.normal_texture = get_organic_normal()
	mat.roughness_texture = get_flesh_roughness()
	mat.roughness_texture_channel = BaseMaterial3D.TEXTURE_CHANNEL_RED
	mat.roughness = 0.28 if wet else 0.55
	
	if wet:
		mat.clearcoat_enabled = true
		mat.clearcoat = 0.75
		mat.clearcoat_roughness = 0.18
	
	mat.subsurf_scatter_enabled = true
	mat.subsurf_scatter_strength = 0.35
	mat.subsurf_scatter_skin_mode = true
	
	mat.rim_enabled = true
	mat.rim = 0.65
	mat.rim_tint = 0.4
	return mat

# Chitin Carapace Material (Crawler, Hunter Spikes)
static func create_chitin_material(base_color: Color, metallic: float = 0.22, roughness: float = 0.26) -> StandardMaterial3D:
	var mat = StandardMaterial3D.new()
	mat.albedo_color = base_color
	mat.metallic = metallic
	mat.roughness = roughness
	mat.normal_enabled = true
	mat.normal_texture = get_chitin_normal()
	
	mat.clearcoat_enabled = true
	mat.clearcoat = 0.55
	mat.clearcoat_roughness = 0.2
	
	mat.rim_enabled = true
	mat.rim = 0.8
	mat.rim_tint = 0.5
	return mat

# Ghost Silk / Spectral Veil Material (Cloak)
static func create_spectral_silk(is_hostile: bool = false) -> StandardMaterial3D:
	var mat = StandardMaterial3D.new()
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mat.normal_enabled = true
	mat.normal_texture = get_cloth_normal()
	
	if not is_hostile:
		# Luminous pearlescent translucent white silk
		mat.albedo_color = Color(0.92, 0.94, 0.98, 0.92)
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		mat.roughness = 0.52
		mat.rim_enabled = true
		mat.rim = 0.95
		mat.rim_tint = 0.65
		mat.emission_enabled = true
		mat.emission = Color(0.25, 0.35, 0.55)
		mat.emission_energy_multiplier = 0.22
	else:
		# Terrifying Dark Void Wraith: Obsidian shadow cloth with glowing crimson soul fire
		mat.albedo_color = Color(0.07, 0.03, 0.05, 0.98)
		mat.roughness = 0.42
		mat.rim_enabled = true
		mat.rim = 1.0
		mat.rim_tint = 0.85
		mat.emission_enabled = true
		mat.emission = Color(0.55, 0.04, 0.09)
		mat.emission_energy_multiplier = 0.72
	return mat

# Cultist Robe Fabric
static func create_robe_fabric(base_color: Color, emission_tint: Color = Color(0, 0, 0)) -> StandardMaterial3D:
	var mat = StandardMaterial3D.new()
	mat.albedo_color = base_color
	mat.roughness = 0.78
	mat.normal_enabled = true
	mat.normal_texture = get_cloth_normal()
	mat.rim_enabled = true
	mat.rim = 0.6
	mat.rim_tint = 0.4
	if emission_tint != Color(0, 0, 0):
		mat.emission_enabled = true
		mat.emission = emission_tint
		mat.emission_energy_multiplier = 0.5
	return mat

# Bone / Talon / Spine Material
static func create_bone_material(base_color: Color = Color(0.82, 0.78, 0.70)) -> StandardMaterial3D:
	var mat = StandardMaterial3D.new()
	mat.albedo_color = base_color
	mat.roughness = 0.44
	mat.normal_enabled = true
	mat.normal_texture = get_bone_normal()
	mat.subsurf_scatter_enabled = true
	mat.subsurf_scatter_strength = 0.22
	return mat

# Weathered Stone / Granite Material (Statue)
static func create_stone_material(base_color: Color = Color(0.35, 0.34, 0.33)) -> StandardMaterial3D:
	var mat = StandardMaterial3D.new()
	mat.albedo_color = base_color
	mat.roughness = 0.86
	mat.normal_enabled = true
	mat.normal_texture = get_stone_normal()
	mat.ao_enabled = true
	return mat
