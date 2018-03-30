primitive _UJSONShow
  fun show_string(buf: String iso, s: String box): String iso^ =>
    // TODO: proper escaping
    (consume buf).>push('"').>append(s.string()).>push('"')

  fun show_value(buf: String iso, value': UJSONValue): String iso^ =>
    match value'
    | let value: None   => (consume buf).>append("null")
    | let value: Bool   => (consume buf).>append(value.string())
    | let value: I64    => (consume buf).>append(value.string())
    | let value: F64    => (consume buf).>append(value.string())
    | let value: String => show_string(consume buf, value)
    end

  fun show_set(
    buf': String iso,
    iter': Iterator[UJSONValue],
    close_bracket: Bool = true)
  : String iso^ =>
    var buf = consume buf'
    buf.push('[')
    for value in iter' do
      buf = show_value(consume buf, value)
      if iter'.has_next() then buf.push(',') end
    end
    if close_bracket then buf.push(']') end
    consume buf

  fun show_map(
    buf': String iso,
    iter': Iterator[(String, UJSONNode box)])
  : String iso^ =>
    var buf = consume buf'
    buf.push('{')
    for (key, node) in iter' do
      buf = show_string(consume buf, key)
      buf.push(':')
      buf = show_node(consume buf, node)
      if iter'.has_next() then buf.push(',') end
    end
    buf.push('}')
    consume buf

  fun show_node(buf': String iso, node': UJSONNode box): String iso^ =>
    var buf = consume buf'
    if node'._next_size() == 0 then
      if node'._here_size() == 0 then
        buf
      elseif node'._here_size() == 1 then
        show_value(consume buf, try node'._here_values().next()? end)
      else
        show_set(consume buf, node'._here_values())
      end
    else
      if node'._here_size() > 0 then
        buf = show_set(consume buf, node'._here_values(), false)
        buf.push(',')
        buf = show_map(consume buf, node'._next_pairs())
        buf.push(']')
        buf
      else
        show_map(consume buf, node'._next_pairs())
      end
    end