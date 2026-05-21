class_name DamageInfo
extends RefCounted

var amount: float = 0.0
var source: Node = null
var damage_type: String = "physical"
var knockback: Vector3 = Vector3.ZERO
var tags: PackedStringArray = PackedStringArray()


static func from_amount(amount: float, source: Node = null) -> DamageInfo:
	var info := DamageInfo.new()
	info.amount = amount
	info.source = source
	return info
