use std = "collections"

class _UJSONNodeBuilder
  let _path: Array[String] val
  let _root: UJSONNode

  new create(path': Array[String] val = [], root': UJSONNode = UJSONNode) =>
    (_path, _root) = (path', root')

  fun root(): this->UJSONNode => _root

  fun ref collect(path': Array[String] val, value': UJSONValue) =>
    if not _UJSONPathEqPrefix((_path, None), (path', None)) then return end
    let path_suffix = path'.trim(_path.size())

    var node = _root
    for path_segment in path_suffix.values() do node = node(path_segment) end
    node.put(value')

class UJSONNode is Equatable[UJSONNode]
  embed _here: std.HashSet[UJSONValue, _UJSONValueHashFn] = _here.create()
  embed _next: std.Map[String, UJSONNode]                 = _next.create()

  fun _here_size(): USize => _here.size()
  fun _next_size(): USize => _next.size()
  fun _here_values(): Iterator[UJSONValue]^ => _here.values()
  fun _next_pairs(): Iterator[(String, UJSONNode box)]^ => _next.pairs()

  new ref create() => None

  new ref from_string(s: String box, errs: Array[String] = [])? =>
    _UJSONParse.into(this, s, errs)?

  fun ref put(value': UJSONValue) => _here.set(value')

  fun ref apply(path_segment': String): UJSONNode =>
    try _next(path_segment')? else
      let node = UJSONNode
      _next(path_segment') = node
      node
    end

  fun is_void(): Bool => (_here.size() == 0) and (_next.size() == 0)

  fun eq(that: UJSONNode box): Bool =>
    if _here        != that._here        then return false end
    if _next.size() != that._next.size() then return false end
    for (key, node) in _next.pairs() do
      if try node != that._next(key)? else true end then return false end
    end
    true

  fun string(): String iso^ => _UJSONShow.show_node(recover String end, this)
