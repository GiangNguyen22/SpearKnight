class_name BgLayout
extends RefCounted

# Shared cover/band sizing for menu-style parallax backgrounds.
# config entries:
#   mode "cover": fills the viewport, "offset" is a fraction of the viewport size
#   mode "band":  spans the full width, "height" is a fraction of viewport height,
#                 "bottom" is where its bottom edge sits (1.0 = screen bottom)
static func apply(bg: Node2D, config: Dictionary) -> void:
	var vp := bg.get_viewport_rect().size
	for key in config:
		var layer_name := String(key)
		var cfg: Dictionary = config[layer_name]
		var sprite := bg.get_node_or_null(NodePath(layer_name)) as Sprite2D
		if sprite == null or sprite.texture == null:
			continue
		var tex := sprite.texture.get_size()
		if cfg["mode"] == "cover":
			var cover := maxf(vp.x / tex.x, vp.y / tex.y) * 1.08
			sprite.scale = Vector2(cover, cover)
			sprite.position = vp * 0.5 + (cfg["offset"] as Vector2) * vp
		else:
			var wanted := vp.y * float(cfg["height"])
			var k := maxf(vp.x / tex.x, wanted / tex.y)
			sprite.scale = Vector2(k, k)
			sprite.position = Vector2(vp.x * 0.5, vp.y * float(cfg["bottom"]) - tex.y * k * 0.5)