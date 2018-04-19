use "ponytest"
use ".."

class TestTReg is UnitTest
  new iso create() => None
  fun name(): String => "crdt.TReg"

  fun apply(h: TestHelper) =>
    let a = TRegString.>update("apple", 3)
    let b = TRegString.>update("banana", 2)
    let c = TRegString.>update("currant", 1)

    h.assert_eq[String](a.value(), "apple")
    h.assert_eq[String](b.value(), "banana")
    h.assert_eq[String](c.value(), "currant")
    h.assert_eq[U64](a.timestamp(), 3)
    h.assert_eq[U64](b.timestamp(), 2)
    h.assert_eq[U64](c.timestamp(), 1)

    h.assert_false(a.converge(b))
    h.assert_false(a.converge(c))
    h.assert_false(b.converge(c))
    h.assert_true(b.converge(a))
    h.assert_true(c.converge(a))
    h.assert_false(c.converge(b))

    h.assert_eq[String](a.value(), "apple")
    h.assert_eq[String](b.value(), "apple")
    h.assert_eq[String](c.value(), "apple")
    h.assert_eq[U64](a.timestamp(), 3)
    h.assert_eq[U64](b.timestamp(), 3)
    h.assert_eq[U64](c.timestamp(), 3)

    a.update("apple", 5)
    b.update("banana", 5)
    c.update("currant", 5)

    h.assert_eq[String](a.value(), "apple")
    h.assert_eq[String](b.value(), "banana")
    h.assert_eq[String](c.value(), "currant")
    h.assert_eq[U64](a.timestamp(), 5)
    h.assert_eq[U64](b.timestamp(), 5)
    h.assert_eq[U64](c.timestamp(), 5)

    h.assert_true(a.converge(b))
    h.assert_true(a.converge(c))
    h.assert_true(b.converge(c))
    h.assert_false(b.converge(a))
    h.assert_false(c.converge(a))
    h.assert_false(c.converge(b))

    h.assert_eq[String](a.value(), "currant")
    h.assert_eq[String](b.value(), "currant")
    h.assert_eq[String](c.value(), "currant")
    h.assert_eq[U64](a.timestamp(), 5)
    h.assert_eq[U64](b.timestamp(), 5)
    h.assert_eq[U64](c.timestamp(), 5)

class TestTRegDelta is UnitTest
  new iso create() => None
  fun name(): String => "crdt.TReg (ẟ)"

  fun apply(h: TestHelper) =>
    let a = TRegString.>update("apple", 3)
    let b = TRegString.>update("banana", 2)
    let c = TRegString.>update("currant", 1)

    h.assert_eq[String](a.value(), "apple")
    h.assert_eq[String](b.value(), "banana")
    h.assert_eq[String](c.value(), "currant")
    h.assert_eq[U64](a.timestamp(), 3)
    h.assert_eq[U64](b.timestamp(), 2)
    h.assert_eq[U64](c.timestamp(), 1)

    h.assert_false(a.converge(b))
    h.assert_false(a.converge(c))
    h.assert_false(b.converge(c))
    h.assert_true(b.converge(a))
    h.assert_true(c.converge(a))
    h.assert_false(c.converge(b))

    h.assert_eq[String](a.value(), "apple")
    h.assert_eq[String](b.value(), "apple")
    h.assert_eq[String](c.value(), "apple")
    h.assert_eq[U64](a.timestamp(), 3)
    h.assert_eq[U64](b.timestamp(), 3)
    h.assert_eq[U64](c.timestamp(), 3)

    var a_delta = a.update("apple", 5)
    var b_delta = b.update("banana", 5)
    var c_delta = c.update("currant", 5)

    h.assert_eq[String](a.value(), "apple")
    h.assert_eq[String](b.value(), "banana")
    h.assert_eq[String](c.value(), "currant")
    h.assert_eq[U64](a.timestamp(), 5)
    h.assert_eq[U64](b.timestamp(), 5)
    h.assert_eq[U64](c.timestamp(), 5)

    h.assert_true(a.converge(b_delta))
    h.assert_true(a.converge(c_delta))
    h.assert_true(b.converge(c_delta))
    h.assert_false(b.converge(a_delta))
    h.assert_false(c.converge(a_delta))
    h.assert_false(c.converge(b_delta))

    h.assert_eq[String](a.value(), "currant")
    h.assert_eq[String](b.value(), "currant")
    h.assert_eq[String](c.value(), "currant")
    h.assert_eq[U64](a.timestamp(), 5)
    h.assert_eq[U64](b.timestamp(), 5)
    h.assert_eq[U64](c.timestamp(), 5)

class TestTRegTokens is UnitTest
  new iso create() => None
  fun name(): String => "crdt.TReg (tokens)"

  fun apply(h: TestHelper) =>
    let data = TRegString .> update("apple", 5)

    _TestTokensWellFormed[(String | U64)](h, data.to_tokens())

    try
      h.assert_eq[TRegString](
        data,
        data.from_tokens(data.to_tokens())?
      )
    else
      h.fail("failed to parse token stream")
    end
