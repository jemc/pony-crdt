use "ponytest"
use ".."

class TestTLog is UnitTest
  new iso create() => None
  fun name(): String => "crdt.TLog"

  fun apply(h: TestHelper)? =>
    let a = TLog[String].>raise_cutoff(4)
    let b = TLog[String].>raise_cutoff(4)
    let c = TLog[String].>raise_cutoff(4)

    a.write("apple", 7)
    b.write("banana", 6)
    c.write("currant", 4)
    a.write("avocado", 5)
    b.write("broccoli", 5)
    c.write("cilantro", 5)
    a.write("alopecia", 4)
    b.write("bronchitis", 3)
    c.write("chickenpox", 2)
    a.write("asparagus", 5)
    b.write("beet", 5)
    c.write("cabbage", 5)

    h.assert_eq[USize](a.size(), 4)
    h.assert_eq[USize](b.size(), 3)
    h.assert_eq[USize](c.size(), 3)
    h.assert_eq[String](a(0)?._1, "apple")
    h.assert_eq[U64](a(0)?._2, 7)
    h.assert_eq[String](a(1)?._1, "avocado")
    h.assert_eq[U64](a(1)?._2, 5)
    h.assert_eq[String](a(2)?._1, "asparagus")
    h.assert_eq[U64](a(2)?._2, 5)
    h.assert_eq[String](a(3)?._1, "alopecia")
    h.assert_eq[U64](a(3)?._2, 4)
    h.assert_eq[String](b(0)?._1, "banana")
    h.assert_eq[U64](b(0)?._2, 6)
    h.assert_eq[String](b(1)?._1, "broccoli")
    h.assert_eq[U64](b(1)?._2, 5)
    h.assert_eq[String](b(2)?._1, "beet")
    h.assert_eq[U64](b(2)?._2, 5)
    h.assert_eq[String](c(0)?._1, "cilantro")
    h.assert_eq[U64](c(0)?._2, 5)
    h.assert_eq[String](c(1)?._1, "cabbage")
    h.assert_eq[U64](c(1)?._2, 5)
    h.assert_eq[String](c(2)?._1, "currant")
    h.assert_eq[U64](c(2)?._2, 4)

    h.assert_false(a.eq(b))
    h.assert_false(b.eq(c))
    h.assert_false(c.eq(a))

    h.assert_true(a.converge(b))
    h.assert_true(a.converge(c))
    h.assert_true(b.converge(c))
    h.assert_true(b.converge(a))
    h.assert_true(c.converge(a))
    h.assert_false(c.converge(b))

    h.assert_eq[USize](10, a.size())
    h.assert_eq[USize](10, b.size())
    h.assert_eq[USize](10, c.size())
    h.assert_eq[String](a(0)?._1, "apple")
    h.assert_eq[U64](a(0)?._2, 7)
    h.assert_eq[String](a(1)?._1, "banana")
    h.assert_eq[U64](a(1)?._2, 6)
    h.assert_eq[String](a(2)?._1, "cilantro")
    h.assert_eq[U64](a(2)?._2, 5)
    h.assert_eq[String](c(3)?._1, "cabbage")
    h.assert_eq[U64](c(3)?._2, 5)
    h.assert_eq[String](a(4)?._1, "broccoli")
    h.assert_eq[U64](a(4)?._2, 5)
    h.assert_eq[String](a(5)?._1, "beet")
    h.assert_eq[U64](a(5)?._2, 5)
    h.assert_eq[String](a(6)?._1, "avocado")
    h.assert_eq[U64](a(6)?._2, 5)
    h.assert_eq[String](a(7)?._1, "asparagus")
    h.assert_eq[U64](a(7)?._2, 5)
    h.assert_eq[String](a(8)?._1, "currant")
    h.assert_eq[U64](a(8)?._2, 4)
    h.assert_eq[String](a(9)?._1, "alopecia")
    h.assert_eq[U64](a(9)?._2, 4)

    h.assert_true(a.eq(b))
    h.assert_true(b.eq(c))
    h.assert_true(a.eq(a))

    h.assert_eq[String](a.string(), b.string())
    h.assert_eq[String](b.string(), c.string())
    h.assert_eq[String](c.string(), a.string())

    a.trim(6)

    h.assert_false(a.converge(b))
    h.assert_false(a.converge(c))
    h.assert_false(b.converge(c))
    h.assert_true(b.converge(a))
    h.assert_true(c.converge(a))
    h.assert_false(c.converge(b))

    h.assert_eq[USize](8, a.size())
    h.assert_eq[USize](8, b.size())
    h.assert_eq[USize](8, c.size())
    h.assert_eq[String](a(0)?._1, "apple")
    h.assert_eq[U64](a(0)?._2, 7)
    h.assert_eq[String](a(1)?._1, "banana")
    h.assert_eq[U64](a(1)?._2, 6)
    h.assert_eq[String](a(2)?._1, "cilantro")
    h.assert_eq[U64](a(2)?._2, 5)
    h.assert_eq[String](c(3)?._1, "cabbage")
    h.assert_eq[U64](c(3)?._2, 5)
    h.assert_eq[String](a(4)?._1, "broccoli")
    h.assert_eq[U64](a(4)?._2, 5)
    h.assert_eq[String](a(5)?._1, "beet")
    h.assert_eq[U64](a(5)?._2, 5)
    h.assert_eq[String](a(6)?._1, "avocado")
    h.assert_eq[U64](a(6)?._2, 5)
    h.assert_eq[String](a(7)?._1, "asparagus")
    h.assert_eq[U64](a(7)?._2, 5)

    h.assert_true(a.eq(b))
    h.assert_true(b.eq(c))
    h.assert_true(a.eq(a))

    h.assert_eq[String](a.string(), b.string())
    h.assert_eq[String](b.string(), c.string())
    h.assert_eq[String](c.string(), a.string())

    a.raise_cutoff(6)

    h.assert_false(a.converge(b))
    h.assert_false(a.converge(c))
    h.assert_false(b.converge(c))
    h.assert_true(b.converge(a))
    h.assert_true(c.converge(a))
    h.assert_false(c.converge(b))

    h.assert_eq[USize](2, a.size())
    h.assert_eq[USize](2, b.size())
    h.assert_eq[USize](2, c.size())
    h.assert_eq[String](a(0)?._1, "apple")
    h.assert_eq[U64](a(0)?._2, 7)
    h.assert_eq[String](a(1)?._1, "banana")
    h.assert_eq[U64](a(1)?._2, 6)

    a.trim(1)

    h.assert_false(a.converge(b))
    h.assert_false(a.converge(c))
    h.assert_false(b.converge(c))
    h.assert_true(b.converge(a))
    h.assert_true(c.converge(a))
    h.assert_false(c.converge(b))

    h.assert_eq[USize](1, a.size())
    h.assert_eq[USize](1, b.size())
    h.assert_eq[USize](1, c.size())
    h.assert_eq[String](a(0)?._1, "apple")
    h.assert_eq[U64](a(0)?._2, 7)

    a.raise_cutoff(100)
    a.raise_cutoff(99) // no effect

    h.assert_false(a.converge(b))
    h.assert_false(a.converge(c))
    h.assert_false(b.converge(c))
    h.assert_true(b.converge(a))
    h.assert_true(c.converge(a))
    h.assert_false(c.converge(b))

    h.assert_eq[U64](100, a.cutoff())
    h.assert_eq[U64](100, b.cutoff())
    h.assert_eq[U64](100, c.cutoff())

    h.assert_eq[USize](0, a.size())
    h.assert_eq[USize](0, b.size())
    h.assert_eq[USize](0, c.size())

class TestTLogDelta is UnitTest
  new iso create() => None
  fun name(): String => "crdt.TLog (ẟ)"

  fun apply(h: TestHelper)? =>
    let a = TLog[String].>raise_cutoff(4)
    let b = TLog[String].>raise_cutoff(4)
    let c = TLog[String].>raise_cutoff(4)

    a.write("apple", 7)
    b.write("banana", 6)
    c.write("currant", 4)
    a.write("avocado", 5)
    b.write("broccoli", 5)
    c.write("cilantro", 5)

    h.assert_true(a.converge(b))
    h.assert_true(a.converge(c))
    h.assert_true(b.converge(c))
    h.assert_true(b.converge(a))
    h.assert_true(c.converge(a))
    h.assert_false(c.converge(b))

    var a_delta = a.write("alopecia", 4)
    var b_delta = b.write("bronchitis", 3)
    var c_delta = c.write("chickenpox", 2)
    a_delta = a.write("asparagus", 5, a_delta)
    b_delta = b.write("beet", 5, b_delta)
    c_delta = c.write("cabbage", 5, c_delta)

    h.assert_true(a.converge(b_delta))
    h.assert_true(a.converge(c_delta))
    h.assert_true(b.converge(c_delta))
    h.assert_true(b.converge(a_delta))
    h.assert_true(c.converge(a_delta))
    h.assert_true(c.converge(b_delta))

    h.assert_eq[USize](10, a.size())
    h.assert_eq[USize](10, b.size())
    h.assert_eq[USize](10, c.size())
    h.assert_eq[String](a(0)?._1, "apple")
    h.assert_eq[U64](a(0)?._2, 7)
    h.assert_eq[String](a(1)?._1, "banana")
    h.assert_eq[U64](a(1)?._2, 6)
    h.assert_eq[String](a(2)?._1, "cilantro")
    h.assert_eq[U64](a(2)?._2, 5)
    h.assert_eq[String](c(3)?._1, "cabbage")
    h.assert_eq[U64](c(3)?._2, 5)
    h.assert_eq[String](a(4)?._1, "broccoli")
    h.assert_eq[U64](a(4)?._2, 5)
    h.assert_eq[String](a(5)?._1, "beet")
    h.assert_eq[U64](a(5)?._2, 5)
    h.assert_eq[String](a(6)?._1, "avocado")
    h.assert_eq[U64](a(6)?._2, 5)
    h.assert_eq[String](a(7)?._1, "asparagus")
    h.assert_eq[U64](a(7)?._2, 5)
    h.assert_eq[String](a(8)?._1, "currant")
    h.assert_eq[U64](a(8)?._2, 4)
    h.assert_eq[String](a(9)?._1, "alopecia")
    h.assert_eq[U64](a(9)?._2, 4)

    h.assert_true(a.eq(b))
    h.assert_true(b.eq(c))
    h.assert_true(a.eq(a))

    h.assert_eq[String](a.string(), b.string())
    h.assert_eq[String](b.string(), c.string())
    h.assert_eq[String](c.string(), a.string())

    a_delta = a.trim(6)

    h.assert_false(a.converge(b_delta))
    h.assert_false(a.converge(c_delta))
    h.assert_false(b.converge(c_delta))
    h.assert_true(b.converge(a_delta))
    h.assert_true(c.converge(a_delta))
    h.assert_false(c.converge(b_delta))

    h.assert_eq[USize](8, a.size())
    h.assert_eq[USize](8, b.size())
    h.assert_eq[USize](8, c.size())
    h.assert_eq[String](a(0)?._1, "apple")
    h.assert_eq[U64](a(0)?._2, 7)
    h.assert_eq[String](a(1)?._1, "banana")
    h.assert_eq[U64](a(1)?._2, 6)
    h.assert_eq[String](a(2)?._1, "cilantro")
    h.assert_eq[U64](a(2)?._2, 5)
    h.assert_eq[String](c(3)?._1, "cabbage")
    h.assert_eq[U64](c(3)?._2, 5)
    h.assert_eq[String](a(4)?._1, "broccoli")
    h.assert_eq[U64](a(4)?._2, 5)
    h.assert_eq[String](a(5)?._1, "beet")
    h.assert_eq[U64](a(5)?._2, 5)
    h.assert_eq[String](a(6)?._1, "avocado")
    h.assert_eq[U64](a(6)?._2, 5)
    h.assert_eq[String](a(7)?._1, "asparagus")
    h.assert_eq[U64](a(7)?._2, 5)

    h.assert_true(a.eq(b))
    h.assert_true(b.eq(c))
    h.assert_true(a.eq(a))

    h.assert_eq[String](a.string(), b.string())
    h.assert_eq[String](b.string(), c.string())
    h.assert_eq[String](c.string(), a.string())

    a_delta = a.raise_cutoff(6)

    h.assert_false(a.converge(b_delta))
    h.assert_false(a.converge(c_delta))
    h.assert_false(b.converge(c_delta))
    h.assert_true(b.converge(a_delta))
    h.assert_true(c.converge(a_delta))
    h.assert_false(c.converge(b_delta))

    h.assert_eq[USize](2, a.size())
    h.assert_eq[USize](2, b.size())
    h.assert_eq[USize](2, c.size())
    h.assert_eq[String](a(0)?._1, "apple")
    h.assert_eq[U64](a(0)?._2, 7)
    h.assert_eq[String](a(1)?._1, "banana")
    h.assert_eq[U64](a(1)?._2, 6)

    a_delta = a.trim(1)

    h.assert_false(a.converge(b_delta))
    h.assert_false(a.converge(c_delta))
    h.assert_false(b.converge(c_delta))
    h.assert_true(b.converge(a_delta))
    h.assert_true(c.converge(a_delta))
    h.assert_false(c.converge(b_delta))

    h.assert_eq[USize](1, a.size())
    h.assert_eq[USize](1, b.size())
    h.assert_eq[USize](1, c.size())
    h.assert_eq[String](a(0)?._1, "apple")
    h.assert_eq[U64](a(0)?._2, 7)

    a_delta = a.trim(0)

    h.assert_false(a.converge(b_delta))
    h.assert_false(a.converge(c_delta))
    h.assert_false(b.converge(c_delta))
    h.assert_true(b.converge(a_delta))
    h.assert_true(c.converge(a_delta))
    h.assert_false(c.converge(b_delta))

    h.assert_eq[USize](0, a.size())
    h.assert_eq[USize](0, b.size())
    h.assert_eq[USize](0, c.size())

class TestTLogTokens is UnitTest
  new iso create() => None
  fun name(): String => "crdt.TLog (tokens)"

  fun apply(h: TestHelper) =>
    let data = TLog[String]
      .> write("apple", 7)
      .> write("banana", 6)
      .> write("currant", 4)

    let tokens = Tokens .> from(data)
    _TestTokensWellFormed(h, tokens)

    try
      h.assert_eq[TLog[String]](
        data,
        data.create() .> from_tokens(tokens.iterator())?
      )
    else
      h.fail("failed to parse token stream")
    end
