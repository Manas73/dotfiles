function itemText(item) {
  if (!item) return ""
  return String(item.search || item.label || "")
}

function itemDetail(item) {
  return item ? String(item.detail || "") : ""
}

function filterItems(items, query) {
  var list = Array.isArray(items) ? items : []
  var q = String(query || "").trim().toLowerCase()
  if (!q) return list.slice()
  var out = []
  for (var i = 0; i < list.length; i++) {
    var hay = (itemText(list[i]) + " " + itemDetail(list[i])).toLowerCase()
    if (hay.indexOf(q) !== -1) out.push(list[i])
  }
  return out
}

function clampIndex(index, length, fallback) {
  var count = length || 0
  if (count <= 0) return -1
  var fb = fallback === undefined ? 0 : fallback
  if (fb < 0 || fb >= count) fb = 0
  if (index === undefined || index < 0) return fb
  if (index >= count) return count - 1
  return index
}

if (typeof module !== "undefined") {
  module.exports = {
    itemText: itemText,
    itemDetail: itemDetail,
    filterItems: filterItems,
    clampIndex: clampIndex
  }
}
