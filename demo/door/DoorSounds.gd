extends Spatial

func _on_door_opened(door):
	$DoorOpened.play()


func _on_door_closed(door):
	$DoorClosed.play()
