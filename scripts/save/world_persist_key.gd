class_name WorldPersistKey
extends RefCounted

const ID_PREFIX := "id:"


## Ключ для сейва: `id:имя` (стабильно при переименовании узла) или путь от корня уровня.
static func make(main: Node, target: Node, persist_id: String = "") -> String:
	var pid := persist_id.strip_edges()
	if not pid.is_empty():
		return ID_PREFIX + pid
	if main == null or target == null:
		return ""
	return str(main.get_path_to(target))


static func is_id_key(key: String) -> bool:
	return key.begins_with(ID_PREFIX)


static func id_from_key(key: String) -> String:
	if not is_id_key(key):
		return ""
	return key.substr(ID_PREFIX.length())


static func find_in_level(main: Node, key: String, group_name: String) -> Node:
	if main == null or key.is_empty():
		return null
	if is_id_key(key):
		var want_id := id_from_key(key)
		for n in main.get_tree().get_nodes_in_group(group_name):
			if not main.is_ancestor_of(n):
				continue
			if n.get("persist_id") != null and str(n.get("persist_id")).strip_edges() == want_id:
				return n
		return null
	return main.get_node_or_null(key)


static func warn_missing(main: Node, category: String, key: String) -> void:
	if key.is_empty():
		return
	push_warning(
		"WorldPersist: на уровне '%s' не найден %s для ключа '%s' (проверьте persist_id или путь узла)."
		% [main.scene_file_path if main else "?", category, key]
	)
