extends MenuPanel
## Credits screen: developer, engine, tools, third-party assets and data sources.

@onready var _back: Button = %BackButton


func _ready() -> void:
	_back.pressed.connect(close)
