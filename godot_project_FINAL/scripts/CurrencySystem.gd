extends Node
# CurrencySystem.gd — Autoload (Singleton) اسمه "CurrencySystem"
# نظام العملات السبع الرسمي حسب تصميم Asharaya الأصلي:
# حديدية -> نحاسية -> برونزية -> فضية -> ذهبية -> ذهبية ملكية -> ماسية
# كل عملة = 10 من اللي قبلها، ماعدا: الملكية = 100 من الذهبية، الماسية = 300 من الملكية

enum Coin { IRON, COPPER, BRONZE, SILVER, GOLD, ROYAL_GOLD, DIAMOND }

const COIN_ORDER := [
	Coin.IRON, Coin.COPPER, Coin.BRONZE, Coin.SILVER, Coin.GOLD, Coin.ROYAL_GOLD, Coin.DIAMOND
]

const COIN_NAMES_AR := {
	Coin.IRON: "حديدية",
	Coin.COPPER: "نحاسية",
	Coin.BRONZE: "برونزية",
	Coin.SILVER: "فضية",
	Coin.GOLD: "ذهبية",
	Coin.ROYAL_GOLD: "ذهبية ملكية",
	Coin.DIAMOND: "ماسية",
}

const COIN_ICON_COLOR := {
	Coin.IRON: Color(0.55, 0.55, 0.58),
	Coin.COPPER: Color(0.72, 0.45, 0.20),
	Coin.BRONZE: Color(0.80, 0.50, 0.20),
	Coin.SILVER: Color(0.75, 0.75, 0.78),
	Coin.GOLD: Color(1.0, 0.84, 0.0),
	Coin.ROYAL_GOLD: Color(1.0, 0.65, 0.0),
	Coin.DIAMOND: Color(0.7, 0.95, 1.0),
}

# قيمة كل عملة بوحدة "حديدية" (أصغر عملة) — تُستخدم للتحويل والمقارنة والتجارة
# iron=1, copper=10, bronze=100, silver=1000, gold=10000,
# royal_gold = gold * 100 = 1,000,000, diamond = royal_gold * 300 = 300,000,000
const VALUE_IN_IRON := {
	Coin.IRON: 1,
	Coin.COPPER: 10,
	Coin.BRONZE: 100,
	Coin.SILVER: 1000,
	Coin.GOLD: 10000,
	Coin.ROYAL_GOLD: 1000000,
	Coin.DIAMOND: 300000000,
}

signal wallet_changed(wallet: Dictionary)

var wallet: Dictionary = {
	Coin.IRON: 3,
	Coin.COPPER: 0,
	Coin.BRONZE: 0,
	Coin.SILVER: 0,
	Coin.GOLD: 0,
	Coin.ROYAL_GOLD: 0,
	Coin.DIAMOND: 0,
}


func total_in_iron() -> int:
	var total := 0
	for c in COIN_ORDER:
		total += wallet.get(c, 0) * VALUE_IN_IRON[c]
	return total


func add_coins(coin: int, amount: int) -> void:
	if amount == 0:
		return
	wallet[coin] = wallet.get(coin, 0) + amount
	_normalize()
	wallet_changed.emit(wallet)


func add_iron_value(iron_amount: int) -> void:
	# يضيف قيمة بالحديدية الخام ثم يطبّع المحفظة (يحوّلها لأعلى عملة ممكنة تلقائياً)
	wallet[Coin.IRON] = wallet.get(Coin.IRON, 0) + iron_amount
	_normalize()
	wallet_changed.emit(wallet)


# يحاول يخصم مبلغ معين (بوحدة الحديدية) من المحفظة، بيفكّ عملات أعلى لو احتاج
func try_spend_iron_value(iron_amount: int) -> bool:
	if total_in_iron() < iron_amount:
		return false
	# فكّ كل حاجة لحديدية، اخصم، ثم طبّع تاني للأعلى
	var total := total_in_iron() - iron_amount
	for c in COIN_ORDER:
		wallet[c] = 0
	wallet[Coin.IRON] = total
	_normalize()
	wallet_changed.emit(wallet)
	return true


# يحوّل الفكة الصغيرة لعملات أكبر تلقائياً (مثال: 10 حديدية -> نحاسية واحدة)
func _normalize() -> void:
	for i in range(COIN_ORDER.size() - 1):
		var current: int = COIN_ORDER[i]
		var next_coin: int = COIN_ORDER[i + 1]
		var rate: int = _rate_between(current, next_coin)
		while wallet.get(current, 0) >= rate:
			wallet[current] -= rate
			wallet[next_coin] = wallet.get(next_coin, 0) + 1


# النسبة بين عملة والي بعدها مباشرة (10 عادي، إلا استثناءين محددين في التصميم)
func _rate_between(lower_coin: int, higher_coin: int) -> int:
	if higher_coin == Coin.ROYAL_GOLD:
		return 100  # الذهبية الملكية = 100 ذهبية
	if higher_coin == Coin.DIAMOND:
		return 300  # الماسية = 300 ذهبية ملكية
	return 10


func get_display_string() -> String:
	var parts: Array = []
	for c in COIN_ORDER:
		if wallet.get(c, 0) > 0:
			parts.append("%d %s" % [wallet[c], COIN_NAMES_AR[c]])
	if parts.is_empty():
		return "0 حديدية"
	return " - ".join(parts)


func save_state() -> Dictionary:
	var out := {}
	for c in COIN_ORDER:
		out[str(c)] = wallet.get(c, 0)
	return out


func load_state(data: Dictionary) -> void:
	for c in COIN_ORDER:
		wallet[c] = int(data.get(str(c), wallet.get(c, 0)))  # JSON بيرجّع float
	wallet_changed.emit(wallet)
