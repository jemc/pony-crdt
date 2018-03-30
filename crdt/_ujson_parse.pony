use "debug"

primitive _UJSONParse
  fun into(node: UJSONNode, source: String box, errs: Array[String])? =>
    let builder = _UJSONNodeBuilder([], node)
    let parser  = _UJSONParser
    try
      parser.parse(source, {(path, value)(builder) =>
        // TODO: Fix ponyc to allow iso clone for arrays with #share elements.
        let path' = recover Array[String](path.size()) end
        for segment in path.values() do path'.push(segment) end
        builder.collect(consume path', value)
      })?
    else
      errs.push(parser.describe_error())
      error
    end

class _UJSONParser
  var _source: String box = ""
  var _offset: USize = 0
  let _path: Array[String] = []
  var _fn: {ref(Array[String] box, UJSONValue)} ref = {(_, _) => _ }

  new ref create() => None

  fun ref parse(
    source': String box,
    fn': {ref(Array[String] box, UJSONValue)} ref)
  ? =>
    (_source, _fn) = (source', fn')
    if detect_empty() then return end
    emit_data()?
    verify_final()?

  fun describe_error(): String =>
    if _offset < _source.size()
    then "invalid JSON at byte offset: " + _offset.string()
    else "unfinished JSON; stream ends at byte: " + _source.size().string()
    end

  fun ref has_next(): Bool => _offset < _source.size()

  fun ref next(): U8? => let b = peek()?; advance(); b

  fun ref emit(v: UJSONValue) => _fn(_path, v)

  fun peek(): U8? => _source(_offset)?

  fun peek_softly(): U8 => try _source(_offset)? else ' ' end

  fun ref eat(b: U8)? => if b != _source(_offset)? then error end; advance()

  fun ref advance(n: USize = 1) => _offset = _offset + n

  fun ref rewind(n: USize = 1) => _offset = _offset - n

  fun ref skip_whitespace() =>
    while has_next() do
      match peek_softly() | ' ' | '\r' | '\t' | '\n' => advance()
      else return
      end
    end

  fun ref detect_empty(): Bool =>
    skip_whitespace()
    not has_next()

  fun ref verify_final()? =>
    skip_whitespace()
    if has_next() then error end

  fun ref emit_data()? =>
    skip_whitespace()
    match peek()?
    | 'n' => advance(); eat('u')?; eat('l')?; eat('l')?;            emit(None)
    | 't' => advance(); eat('r')?; eat('u')?; eat('e')?;            emit(true)
    | 'f' => advance(); eat('a')?; eat('l')?; eat('s')?; eat('e')?; emit(false)
    | '"' => emit_string()?
    | '{' => emit_map()?
    | '[' => emit_set()?
    | '-' => advance(); emit(read_number(-1)?)
    | let b: U8 if (b >= '0') and (b <= '9') => emit(read_number()?)
    else error
    end

  fun ref emit_set()? =>
    advance() // past the opening bracket
    skip_whitespace()
    if peek()? == ']' then advance(); return end

    while true do
      emit_data()?; skip_whitespace()
      match next()?
      | ',' => skip_whitespace()
      | ']' => break
      else error
      end
    end

  fun ref emit_map()? =>
    advance() // past the opening bracket
    skip_whitespace()
    if peek()? == '}' then advance(); return end

    while true do
      eat('"')?; rewind(1); _path.push(read_string()?); skip_whitespace()
      eat(':')?; emit_data()?; skip_whitespace()
      _path.pop()?
      match next()?
      | ',' => skip_whitespace()
      | '}' => break
      else error
      end
    end

  fun ref read_number(sign': I64 = 1): (I64 | F64)? =>
    let integer = read_number_digits()?

    var dot: F64 = 0
    let has_dot = (peek_softly() == '.')
    if has_dot then advance(); dot = read_number_digits_as_fractional()? end

    var exp: I64 = 0
    let has_exp = match peek_softly() | 'e' | 'E' => true else false end
    if has_exp then
      advance()
      let exp_negative =
        match peek()?
        | '+' => advance(); false
        | '-' => advance(); true
        else false
        end
      exp = read_number_digits()?
      if exp_negative then exp = -exp end
    else 0
    end

    if has_dot or has_exp
    then sign'.f64() * (integer.f64() + dot) * (F64(10).pow(exp.f64()))
    else sign' * integer
    end

  fun ref read_number_digits_as_fractional(): F64? =>
    let orig_offset = _offset
    let integer = read_number_digits()?
    (integer.f64() / F64(10).pow((_offset - orig_offset).f64()))

  fun ref read_number_digits(): I64? =>
    var value: I64 = 0
    var byte = peek()?
    while is_number_digit(byte) do
      value = (value * 10) + (byte - '0').i64()
      advance()
      byte = peek_softly()
    end
    value

  fun tag is_number_digit(b: U8): Bool => (b >= '0') and (b <= '9')

  fun ref emit_string()? => emit(read_string()?)

  fun ref read_string(): String? =>
    advance() // past the opening quote
    var buf = recover String end
    while true do
      match next()?
      | '"'  => break
      | '\\' => buf = push_escape_seq(consume buf)?
      | let b: U8 => buf.push(b)
      end
    end
    consume buf

  fun ref push_escape_seq(buf: String iso): String iso^? =>
    match next()?
    | '"'  => (consume buf).>push('"')
    | '\\' => (consume buf).>push('\\')
    | '/'  => (consume buf).>push('/')
    | 'b'  => (consume buf).>push(0x08)
    | 't'  => (consume buf).>push(0x09)
    | 'n'  => (consume buf).>push(0x0a)
    | 'f'  => (consume buf).>push(0x0c)
    | 'r'  => (consume buf).>push(0x0d)
    | 'u'  => (consume buf).>append(read_unicode_seq()?)
    else error
    end

  fun ref read_unicode_seq(): String? =>
    // We've already read the initial "\u" bytes, so start reading the digits.
    let value = read_unicode_value()?

    if (value < 0xD800) or (value >= 0xE000) then
      // If the value we read is a valid single UTF-16 value, return it now.
      recover String.from_utf32(value) end
    else
      // Otherwise, it is half of a surrogate pair, so we expect another half,
      // in another unicode escape sequence immediately following this one.
      eat('\\')?; eat('u')?
      let value_2 = read_unicode_value()?

      if (value < 0xDC00) and (value_2 >= 0xDC00) and (value_2 < 0xE000) then
        // If the two values make a valid pair, return the combined value.
        let combined = 0x10000 + ((value and 0x3FF) << 10) + (value_2 and 0x3FF)
        recover String.from_utf32(combined) end
      else
        // The two are an invalid pair. Backtrack to show the error position.
        rewind(4)
        error
      end
    end

  fun ref read_unicode_value(): U32? =>
    var value: U32 = 0
    var count: U8  = 0

    while (count = count + 1) < 4 do
      var b = next()?
      let digit =
        if     (b >= '0') and (b <= '9') then b - '0'
        elseif (b >= 'a') and (b <= 'f') then (b - 'a') + 10
        elseif (b >= 'A') and (b <= 'F') then (b - 'A') + 10
        else error
        end

      value = (value * 16) + digit.u32()
    end

    value
