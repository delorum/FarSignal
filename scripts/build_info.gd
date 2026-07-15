extends RefCounted

const VERSION_SETTING := "application/config/version"
const BUILD_SHA_SETTING := "application/config/build_sha"


static func display_text() -> String:
	var version := str(ProjectSettings.get_setting(VERSION_SETTING, "0.0.0"))
	var build_sha := str(ProjectSettings.get_setting(BUILD_SHA_SETTING, ""))
	if build_sha.is_empty() and not OS.has_feature("web"):
		build_sha = _local_git_sha()
	if build_sha.is_empty():
		return TranslationServer.translate("Версия %s") % version
	return TranslationServer.translate("Версия %s · %s") % [version, build_sha]


static func _local_git_sha() -> String:
	var repository_path := (
		ProjectSettings.globalize_path("res://")
		if OS.has_feature("editor")
		else OS.get_executable_path().get_base_dir()
	)
	var status_output: Array = []
	var status_exit_code := OS.execute(
		"git",
		PackedStringArray([
			"-C",
			repository_path,
			"status",
			"--porcelain",
		]),
		status_output,
		true
	)
	if status_exit_code != 0 \
			or not "".join(status_output).strip_edges().is_empty():
		return ""

	var output: Array = []
	var exit_code := OS.execute(
		"git",
		PackedStringArray([
			"-C",
			repository_path,
			"rev-parse",
			"--short=7",
			"HEAD",
		]),
		output,
		true
	)
	if exit_code != 0 or output.is_empty():
		return ""
	return str(output[0]).strip_edges()
