use std = "collections"

class _UJSONNodeBuilder
  let _path: Array[String] val
  let _root: UJSONNode = _root.create()
  
  new create(path': Array[String] val) => _path = path'
  
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
  
  new ref create() => None
  
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
  
  fun tag _show_string(buf: String iso, s: String box): String iso^ =>
    // TODO: proper escaping
    (consume buf).>push('"').>append(s.string()).>push('"')
  
  fun tag _show_value(buf: String iso, value': UJSONValue): String iso^ =>
    match value'
    | let value: None   => (consume buf).>append("null")
    | let value: Bool   => (consume buf).>append(value.string())
    | let value: I64    => (consume buf).>append(value.string())
    | let value: F64    => (consume buf).>append(value.string())
    | let value: String => _show_string(consume buf, value)
    end
  
  fun tag _show_set(
    buf': String iso,
    set': std.HashSet[UJSONValue, _UJSONValueHashFn] box,
    close_bracket: Bool = true)
  : String iso^ =>
    var buf = consume buf'
    buf.push('[')
    let iter = set'.values()
    for value in iter do
      buf = _show_value(consume buf, value)
      if iter.has_next() then buf.push(',') end
    end
    if close_bracket then buf.push(']') end
    consume buf
  
  fun tag _show_map(
    buf': String iso,
    map': std.Map[String, UJSONNode] box)
  : String iso^ =>
    var buf = consume buf'
    buf.push('{')
    let iter = map'.pairs()
    for (key, node) in iter do
      buf = _show_string(consume buf, key)
      buf.push(':')
      buf = node._show(consume buf)
      if iter.has_next() then buf.push(',') end
    end
    buf.push('}')
    consume buf
  
  fun _show(buf': String iso): String iso^ =>
    var buf = consume buf'
    if _next.size() == 0 then
      if _here.size() == 0 then
        buf
      elseif _here.size() == 1 then
        _show_value(consume buf, try _here.index(0)? end)
      else
        _show_set(consume buf, _here)
      end
    else
      if _here.size() > 0 then
        buf = _show_set(consume buf, _here, false)
        buf.push(',')
        buf = _show_map(consume buf, _next)
        buf.push(']')
        buf
      else
        _show_map(consume buf, _next)
      end
    end
  
  fun string(): String iso^ => _show(recover String end)
