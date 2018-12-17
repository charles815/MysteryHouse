extends Node2D

var gameData
var roomsData
var peopleData
var weaponData

var dynamicButtons = []
var dynamicLabels = []

var showIntro
var isShowingHelp
var currentRoom
var currentRoomName
var bodyId
var killerId
var weaponUsedId

var solveState = 0
var bodyGuess
var killerGuess
var weaponGuess

func _ready():
	randomize()
	showIntro = true
	isShowingHelp = false
	$Solver.hide()
	$Blackboard.show()
	
	setup_game_data()
	randomize_body()
	randomize_killer()
	randomize_weaponUsed()
	randomize_suspects()
	randomize_weapons()
	
	currentRoomName = gameData.startingRoom
	currentRoom = roomsData[currentRoomName]
	setup_current_room()
	showIntro = false

func setup_game_data():
	gameData = get_from_JSON("gameData.json")
	roomsData = gameData.rooms
	peopleData = gameData.people
	weaponData = gameData.weapons
	
	#init rooms
	for i in range(0, roomsData.size()):
		roomsData.values()[i].suspectIds = []
		roomsData.values()[i].weaponIds = []
		roomsData.values()[i].bodyId = -1

func randomize_body():
	bodyId = randi() % peopleData.size()
	var roomIndex = randi() % roomsData.size()
	roomsData.values()[roomIndex].bodyId = bodyId

func randomize_killer():
	killerId = randi() % peopleData.size() - 1
	if killerId == bodyId:
		killerId += 1

func randomize_weaponUsed():
	weaponUsedId = randi() % weaponData.size()

func randomize_suspects():
	var numberOfRooms = roomsData.size()
	for suspectId in range(0, peopleData.size()):
		if suspectId == bodyId || suspectId == killerId:
			continue	# suspect cannot be killer nor body
		
		var roomIndex = randi() % numberOfRooms
		var room = roomsData.values()[roomIndex]
		room.suspectIds.append(suspectId)

func randomize_weapons():
	var numberOfRooms = roomsData.size()
	for weaponId in range(0, weaponData.size()):
		if weaponId == weaponUsedId:
			continue	# don't hide the weapon used
		
		var roomIndex = randi() % numberOfRooms
		var room = roomsData.values()[roomIndex]
		room.weaponIds.append(weaponId)

func setup_current_room():
	if showIntro:
		$Blackboard/MainText.text = gameData.introText + "\n\n"
	else:
		$Blackboard/MainText.clear()
	
	$Blackboard/MainText.text += currentRoom.roomDescription
	var searchables = get_searchables()
	if (searchables.length() == 0):
		searchables = "nothing."
	$Blackboard/MainText.text += "\n\n" + gameData.findText % searchables
	$Blackboard/GoLeft.disabled = !room_has_exit("left")
	$Blackboard/GoRight.disabled = !room_has_exit("right")
	$Blackboard/GoForward.disabled = !room_has_exit("forward")
	$Blackboard/GoBackward.disabled = !room_has_exit("back")
	$Blackboard/GoSteps.disabled = !room_has_exit("steps")
	$Blackboard/Solve.disabled = false

func _on_GoLeft_pressed():
	change_room("left")

func _on_GoRight_pressed():
	change_room("right")

func _on_GoForward_pressed():
	change_room("forward")

func _on_GoBackward_pressed():
	change_room("back")
	
func _on_GoSteps_pressed():
	change_room("steps")

func _on_Help_pressed():
	isShowingHelp =  !isShowingHelp
	if isShowingHelp:
		disable_UI()
		show_help()
	else:
		setup_current_room()

func _on_Solve_pressed():
	solveState = 0
	setup_body_selection()
	$Solver.show()

func setup_body_selection():
	$Solver/MainText.text = "Who was killed?"
	for i in range(0, peopleData.size()):
		var location = Vector2((i % 3) * 320 + 50, (i / 3) * 75 + 50)
		create_button(location, "personId_" + str(i), peopleData[i])

func setup_killer_selection():
	$Solver/MainText.text = "Who was the killer?"
	for i in range(0, peopleData.size()):
		var location = Vector2((i % 3) * 320 + 50, (i / 3) * 75 + 50)
		create_button(location, "suspectId_" + str(i), peopleData[i])

func setup_weapon_selection():
	$Solver/MainText.text = "What weapon was used?"
	for i in range(0, weaponData.size()):
		var location = Vector2((i % 3) * 320 + 50, (i / 3) * 75 + 50)
		create_button(location, "weaponId_" + str(i), weaponData[i])

func create_button(location, name, text):
	var button = $Blackboard/TemplateButton.duplicate()
	button.rect_position = location
	button.name = name
	$Solver.add_child(button)
	dynamicButtons.append(button)
	
	var label = $Blackboard/TemplateLabel.duplicate()
	label.rect_position = location + Vector2(55, 0)
	label.text = text
	label.name = name + "_Label"
	$Solver.add_child(label)
	dynamicLabels.append(label)

func _on_Cancel_pressed():
	free_dynamics()
	$Solver.hide()
	solveState = 0

func _on_Submit_pressed():
	if solveState == 0:
		if (!solve_body()):
			return
	elif solveState == 1:
		if !solve_killer():
			return
	elif solveState == 2:
		if !solve_weapon():
			return
	
	if solveState == 3:
		end_game()
	
	setup_next_solve()

func _on_Restart_pressed():
	get_tree().reload_current_scene()

func setup_next_solve():
	free_dynamics()
	
	if solveState == 0:
		setup_body_selection()
	elif solveState == 1:
		setup_killer_selection()
	elif solveState == 2:
		setup_weapon_selection()

func solve_body():
	bodyGuess = -1
	for i in range(0, dynamicButtons.size()):
		var button = dynamicButtons[i]
		if button.pressed:
			bodyGuess = int(button.name.substr(9, button.name.length() - 9))
	if bodyGuess >= 0:
		solveState += 1
	return bodyGuess >= 0;

func solve_killer():
	killerGuess = -1
	for i in range(0, dynamicButtons.size()):
		var button = dynamicButtons[i]
		if button.pressed:
			killerGuess = int(button.name.substr(10, button.name.length() - 10))
	if killerGuess >= 0:
		solveState += 1
	return killerGuess >= 0;

func solve_weapon():
	weaponGuess = -1
	for i in range(0, dynamicButtons.size()):
		var button = dynamicButtons[i]
		if button.pressed:
			weaponGuess = int(button.name.substr(9, button.name.length() - 9))
	if weaponGuess >= 0:
		solveState += 1
	return weaponGuess >= 0;

func end_game():
	var solveText = ""
	var correctNames = [peopleData[bodyId], peopleData[killerId], weaponData[weaponUsedId]]
	var guessNames = [peopleData[bodyGuess], peopleData[killerGuess], weaponData[weaponGuess]]
	if (bodyId == bodyGuess && killerId == killerGuess && weaponUsedId == weaponGuess):
		solveText = gameData.guessCorrectText % correctNames
	else:
		solveText = gameData.guessWrongText % (correctNames + guessNames)
	
	$Solver/MainText.text = solveText
	$Solver/Restart.show()
	$Solver/Submit.hide()
	$Solver/Cancel.hide()

func free_dynamics():
	for i in range(0, dynamicButtons.size()):
		dynamicButtons[i].queue_free()
		dynamicLabels[i].queue_free()
	
	dynamicButtons.clear()
	dynamicLabels.clear()

func get_searchables():
	var searchables = []
	
	# suspects
	for i in range(0, currentRoom.suspectIds.size()):
		var suspectId = currentRoom.suspectIds[i]
		var person = peopleData[suspectId]
		searchables.append(person)
	
	# weapons
	for i in range(0, currentRoom.weaponIds.size()):
		var weaponId = currentRoom.weaponIds[i]
		var weapon = weaponData[weaponId]
		searchables.append(weapon)
	
	# body
	if currentRoom.bodyId >= 0:
		var person = peopleData[currentRoom.bodyId]
		searchables.append(person + "'s body")
	
	return array_to_stringList(searchables)

func show_help():
	var suspects = array_to_stringList(peopleData)
	var weapons = array_to_stringList(weaponData)
	var helpText = gameData.helpText % [suspects, weapons]
	$Blackboard/MainText.text = gameData.introText + "\n\n"
	$Blackboard/MainText.text += helpText

func disable_UI():
	$Blackboard/GoLeft.disabled = true
	$Blackboard/GoRight.disabled = true
	$Blackboard/GoForward.disabled = true
	$Blackboard/GoBackward.disabled = true
	$Blackboard/GoSteps.disabled = true
	$Blackboard/Solve.disabled = true

func change_room(exitName):
	var exits = currentRoom.exits
	if !room_has_exit(exitName):
		print("%s doesn't have exit '%s'" % [currentRoomName, exitName])
		return
		
	var roomName = exits[exitName]
	if !roomsData.has(roomName):
		print("%s is not a valid room" % roomName)
		return
		
	currentRoomName = roomName
	currentRoom = roomsData[currentRoomName]
	
	move_suspects()
	setup_current_room()

func move_suspects():
	for j in range(0, roomsData.size()):
		var room = roomsData.values()[j]
		var suspects = room.suspectIds.duplicate()
		for i in range(0, suspects.size()):
			var isMovingRoll = randi() % 3
			if (isMovingRoll == 0):
				move_suspect(suspects[i], room)

func move_suspect(suspectId, room):
	#choose random exit
	var exitRoll = randi() % room.exits.size()
	var roomName = room.exits.values()[exitRoll]
	if !roomsData.has(roomName):
		print("%s is not a valid room" % roomName)
		return
	
	room.suspectIds.erase(suspectId)
	var newRoom = roomsData[roomName]
	newRoom.suspectIds.append(suspectId)

func room_has_exit(exitName):
	var exits = currentRoom.exits
	return exits.has(exitName)

func get_from_JSON(filename):
	var file = File.new()
	file.open(filename, File.READ)
	var text = file.get_as_text()
	var data = parse_json(text)
	file.close()
	return data

func array_to_stringList(arrayData):
	var stringList = ""
	for i in range(0, arrayData.size()):
		if i == 0:
			stringList += arrayData[i]
		elif i < arrayData.size() - 1:
			stringList += ", "  + arrayData[i]
		else:
			stringList += " and " + arrayData[i]
	return stringList

