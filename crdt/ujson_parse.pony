use json = "jason"

primitive UJSONParse
  fun _into(node': UJSONNode, source: String box, errs: Array[String])? =>
    let builder = _UJSONNodeBuilder([], node')
    let parser  = json.Parser
    let notify  = _UJSONParserNotify({(path, value)(builder) =>
      // TODO: Fix ponyc to allow iso clone for arrays with #share elements.
      let path' = recover Array[String](path.size()) end
      for segment in path.values() do path'.push(segment) end
      builder.collect(consume path', value)
    })
    try
      parser.parse(source, notify)?
    else
      errs.push(parser.describe_error())
      error
    end

  fun value(source: String box, errs: Array[String] = []): UJSONValue? =>
    let register = Array[UJSONValue]
    let parser   = json.Parser
    let notify   =
      _UJSONParserNotifySingle({(value)(register) => register.push(value) })
    try
      parser.parse(source, notify)?
      register.pop()?
    else
      errs.push(parser.describe_error())
      error
    end

  fun node(source: String box, errs: Array[String] = []): UJSONNode? =>
    let out = UJSONNode
    _into(out, source, errs)?
    out

class _UJSONParserNotify is json.ParserNotify
  let _fn: {ref(Array[String] box, UJSONValue)} ref
  let _path: Array[String] = []

  new ref create(fn': {ref(Array[String] box, UJSONValue)} ref) => _fn = fn'

  fun ref apply(parser: json.Parser, token: json.Token) =>
    match token
    | json.TokenNull    => _fn(_path, None)
    | json.TokenTrue    => _fn(_path, true)
    | json.TokenFalse   => _fn(_path, false)
    | json.TokenNumber  => _fn(_path, parser.last_number)
    | json.TokenString  => _fn(_path, parser.last_string)
    | json.TokenKey     => _path.push(parser.last_string)
    | json.TokenPairPost => try _path.pop()? end
    end

class _UJSONParserNotifySingle is json.ParserNotify
  let _fn: {ref(UJSONValue)} ref

  new ref create(fn': {ref(UJSONValue)} ref) => _fn = fn'

  fun ref apply(parser: json.Parser, token: json.Token) =>
    match token
    | json.TokenNull        => _fn(None)
    | json.TokenTrue        => _fn(true)
    | json.TokenFalse       => _fn(false)
    | json.TokenNumber      => _fn(parser.last_number)
    | json.TokenString      => _fn(parser.last_string)
    | json.TokenObjectStart => parser.abort()
    | json.TokenArrayStart  => parser.abort()
    end
