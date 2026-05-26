class_name MagicCastBurstVfx
extends Node3D
## Устарело — используйте `MagicCastVfx.play_shoot`.


static func play_at(pos: Vector3, forward: Vector3, settings: MagicProjectileSettings) -> void:
	MagicCastVfx.play_shoot(pos, forward, settings)
