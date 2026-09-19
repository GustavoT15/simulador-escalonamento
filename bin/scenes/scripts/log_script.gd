class_name LogPanel extends PanelContainer
@export var text:RichTextLabel

func clear()->void:
	text.text = ""
func queue_message(msg:String)->void:
	text.text += msg +"\n\n"
