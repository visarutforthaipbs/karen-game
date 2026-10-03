class_name L10n
extends RefCounted

## Keep Thai source text on Controls. Godot translates it when drawing and
## refreshes it automatically on language changes, including already-open UI.
## Formats/compositions register a matching English sentence before display.
const CATALOG = "res://localization/messages.json"
const SUPPORTED_LOCALES = ["th", "en"]
static var _loaded: bool = false
static var _english: Dictionary = {}
static var _english_translation: Translation
static var _thai_translation: Translation

static func initialize() -> void:
	if _loaded:
		return
	_loaded = true
	_english_translation = Translation.new()
	_english_translation.locale = "en"
	_thai_translation = Translation.new()
	_thai_translation.locale = "th"
	var entries = JSON.parse_string(FileAccess.get_file_as_string(CATALOG))
	if not entries is Array:
		push_error("Localization catalog could not be loaded: " + CATALOG)
		return
	for entry in entries:
		if entry is Dictionary and entry.has("th") and entry.has("en"):
			register_message(str(entry.th), str(entry.en))
	TranslationServer.add_translation(_english_translation)
	TranslationServer.add_translation(_thai_translation)

static func validated_locale(value: String) -> String:
	return value if value in SUPPORTED_LOCALES else "th"

static func set_locale(value: String) -> void:
	initialize()
	var locale = validated_locale(value)
	if TranslationServer.get_locale() != locale:
		TranslationServer.set_locale(locale)

static func register_message(source: String, translated: String) -> void:
	if source.is_empty() or _english.get(source) == translated:
		return
	_english[source] = translated
	_english_translation.add_message(source, translated)
	_thai_translation.add_message(source, source)

## Resolve a source phrase regardless of the current locale. Non-catalog text,
## numbers, key names and player-entered strings pass through unchanged.
static func english(source: String) -> String:
	initialize()
	return str(_english.get(source, source))

## translate_args=false protects player-entered names/other user content.
## Pass numeric arguments as numbers, preserving all native printf formats.
static func format(template: String, values: Variant, translate_args: bool = true) -> String:
	initialize()
	var translated_values: Variant = values
	if translate_args:
		if values is Array:
			translated_values = []
			for value in values:
				translated_values.append(english(str(value)) if value is String or value is StringName else value)
		elif values is String or values is StringName:
			translated_values = english(str(values))
	var source = template % values
	register_message(source, english(template) % translated_values)
	return source

static func join(parts: Variant, separator: String = "\n") -> String:
	initialize()
	var sources = PackedStringArray()
	var translations = PackedStringArray()
	for part in parts:
		sources.append(str(part))
		translations.append(english(str(part)))
	var source = separator.join(sources)
	register_message(source, english(separator).join(translations))
	return source

static func concat(parts: Variant) -> String:
	return join(parts, "")

## Release runtime resources with the autoload at application shutdown.
static func shutdown() -> void:
	if _english_translation:
		TranslationServer.remove_translation(_english_translation)
	if _thai_translation:
		TranslationServer.remove_translation(_thai_translation)
	_english_translation = null
	_thai_translation = null
	_english.clear()
	_loaded = false
