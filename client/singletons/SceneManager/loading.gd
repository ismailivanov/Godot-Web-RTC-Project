extends CanvasLayer


func set_progress(progress : Array):
	$Control/Panel/LoadingProgress.value = floor(progress[0]*100)
