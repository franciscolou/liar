class_name HumanController
extends Controller
## Forwards every decision to the table UI.

var table: Node


func decide(decision: Decision) -> Variant:
	return await table.request(decision)


func withdraw(decision: Decision) -> void:
	table.withdraw(decision)
