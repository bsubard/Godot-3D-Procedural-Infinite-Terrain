// NOTE: Shader automatically converted from Godot Engine 4.4.stable's StandardMaterial3D.
shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_back, diffuse_burley, specular_schlick_ggx;
uniform vec4 albedo : source_color;
uniform sampler2D texture_albedo : source_color, filter_linear_mipmap, repeat_enable;
uniform ivec2 albedo_texture_size;
uniform float point_size : hint_range(0.1, 128.0, 0.1);
uniform float roughness : hint_range(0.0, 1.0);
uniform sampler2D texture_metallic : hint_default_white, filter_linear_mipmap, repeat_enable;
uniform vec4 metallic_texture_channel;
uniform sampler2D texture_roughness : hint_roughness_r, filter_linear_mipmap, repeat_enable;
uniform float specular : hint_range(0.0, 1.0, 0.01);
uniform float metallic : hint_range(0.0, 1.0, 0.01);
uniform sampler2D texture_normal : hint_roughness_normal, filter_linear_mipmap, repeat_enable;
uniform float normal_scale : hint_range(-16.0, 16.0);
uniform vec3 uv1_scale;
uniform vec3 uv1_offset;
uniform vec3 uv2_scale;
uniform vec3 uv2_offset;
uniform float time_scale : hint_range(0.1, 5.0) = 1.0;
uniform float normal_contrast_min : hint_range(0.01, 5.0) = 0.3; 
uniform float normal_contrast_max : hint_range(0.01, 5.0) = 0.3; 

void vertex() {
	UV = UV * uv1_scale.xy + uv1_offset.xy;
}

void fragment() {
	// Base UV coordinates
	vec2 base_uv = UV;
	
	// Moving UV - only using sine for vertical movement
	vec2 moving_uv = base_uv + vec2(0.0, TIME * time_scale * 0.02);
	
	// Get normal map from texture
	vec3 normal_map_value = texture(texture_normal, moving_uv).rgb;
	
	// Manipulate the normal map "heights" by changing contrast over time
	// This will make the bumps appear more pronounced and then flatter in a cycle
	float contrast = mix(normal_contrast_min, normal_contrast_max, (sin(TIME * time_scale) + 1.0) * 0.5);
	
	// Apply contrast to normal map (convert from 0-1 to -1 to 1 space, apply contrast, convert back)
	vec2 xy = normal_map_value.xy * 2.0 - 1.0; // Convert from 0-1 to -1 to 1 space
	xy = xy * contrast; // Apply contrast
	xy = clamp(xy, -1.0, 1.0); // Clamp to valid range
	xy = xy * 0.5 + 0.5; // Convert back to 0-1 space
	
	// Recalculate z component to maintain unit normal
	float z = sqrt(1.0 - dot(xy * 2.0 - 1.0, xy * 2.0 - 1.0));
	z = z * 0.5 + 0.5; // Convert to 0-1 space
	
	// Construct final normal map value
	normal_map_value = vec3(xy, z);
	
	// Apply the basic material properties
	vec4 albedo_tex = texture(texture_albedo, base_uv);
	ALBEDO = albedo.rgb * albedo_tex.rgb;
	float metallic_tex = dot(texture(texture_metallic, base_uv), metallic_texture_channel);
	METALLIC = metallic_tex * metallic;
	SPECULAR = specular;
	vec4 roughness_texture_channel = vec4(1.0, 0.0, 0.0, 0.0);
	float roughness_tex = dot(texture(texture_roughness, base_uv), roughness_texture_channel);
	ROUGHNESS = roughness_tex * roughness;
	
	// Apply animated normal map
	NORMAL_MAP = normal_map_value;
	NORMAL_MAP_DEPTH = normal_scale;
}