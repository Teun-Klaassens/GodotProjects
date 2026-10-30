extends RefCounted
## Shared inventory transfer and display limits; bags may contain multiple 100-item stacks.
const STACK_LIMIT: int = 100
static func get_stacks(amount: int) -> int:
    return ceili(float(maxi(amount,0)) / float(STACK_LIMIT))

static func stack_summary(bag: Dictionary, sort_by_amount: bool = false) -> String:
    var keys: Array = bag.keys()
    if sort_by_amount:
        keys.sort_custom(func(a,b): return int(bag[a]) > int(bag[b]))
    else:
        keys.sort()
    var lines: Array[String] = []
    var total: int = 0
    for key in keys:
        var amount: int = int(bag[key])
        if amount <= 0:
            continue
        total += amount
        lines.append("%s  ×%d  (%d stacks)" % [str(key).replace("_"," ").capitalize(),amount,get_stacks(amount)])
    lines.push_front("%d items  /  %d unique types
" % [total,maxi(lines.size(),0)])
    return "
".join(PackedStringArray(lines))
