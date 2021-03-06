use "ponytest"
use ".."

class TestPNCounter is UnitTest
  new iso create() => None
  fun name(): String => "crdt.PNCounter"

  fun apply(h: TestHelper) =>
    let a = PNCounter("a".hash64())
    let b = PNCounter("b".hash64())
    let c = PNCounter("c".hash64())

    a.increment(1)
    b.decrement(2)
    c.increment(3)

    h.assert_eq[U64](a.value(), 1)
    h.assert_eq[U64](b.value(), -2)
    h.assert_eq[U64](c.value(), 3)
    h.assert_ne[PNCounter](a, b)
    h.assert_ne[PNCounter](b, c)
    h.assert_ne[PNCounter](c, a)

    h.assert_false(a.converge(a))

    h.assert_true(a.converge(b))
    h.assert_true(a.converge(c))
    h.assert_true(b.converge(c))
    h.assert_true(b.converge(a))
    h.assert_true(c.converge(a))
    h.assert_false(c.converge(b))

    h.assert_eq[U64](a.value(), 2)
    h.assert_eq[U64](b.value(), 2)
    h.assert_eq[U64](c.value(), 2)
    h.assert_eq[PNCounter](a, b)
    h.assert_eq[PNCounter](b, c)
    h.assert_eq[PNCounter](c, a)

    a.increment(9)
    b.increment(8)
    c.decrement(7)

    h.assert_eq[U64](a.value(), 11)
    h.assert_eq[U64](b.value(), 10)
    h.assert_eq[U64](c.value(), -5)
    h.assert_ne[PNCounter](a, b)
    h.assert_ne[PNCounter](b, c)
    h.assert_ne[PNCounter](c, a)

    h.assert_true(a.converge(b))
    h.assert_true(a.converge(c))
    h.assert_true(b.converge(c))
    h.assert_true(b.converge(a))
    h.assert_true(c.converge(a))
    h.assert_false(c.converge(b))

    h.assert_eq[U64](a.value(), 12)
    h.assert_eq[U64](b.value(), 12)
    h.assert_eq[U64](c.value(), 12)
    h.assert_eq[PNCounter](a, b)
    h.assert_eq[PNCounter](b, c)
    h.assert_eq[PNCounter](c, a)

class TestPNCounterDelta is UnitTest
  new iso create() => None
  fun name(): String => "crdt.PNCounter (ẟ)"

  fun apply(h: TestHelper) =>
    let a = PNCounter("a".hash64())
    let b = PNCounter("b".hash64())
    let c = PNCounter("c".hash64())

    var a_delta = a.increment(1)
    var b_delta = b.decrement(2)
    var c_delta = c.increment(3)

    h.assert_eq[U64](a.value(), 1)
    h.assert_eq[U64](b.value(), -2)
    h.assert_eq[U64](c.value(), 3)
    h.assert_ne[PNCounter](a, b)
    h.assert_ne[PNCounter](b, c)
    h.assert_ne[PNCounter](c, a)

    h.assert_false(a.converge(a_delta))

    h.assert_true(a.converge(b_delta))
    h.assert_true(a.converge(c_delta))
    h.assert_true(b.converge(c_delta))
    h.assert_true(b.converge(a_delta))
    h.assert_true(c.converge(a_delta))
    h.assert_true(c.converge(b_delta))

    h.assert_eq[U64](a.value(), 2)
    h.assert_eq[U64](b.value(), 2)
    h.assert_eq[U64](c.value(), 2)
    h.assert_eq[PNCounter](a, b)
    h.assert_eq[PNCounter](b, c)
    h.assert_eq[PNCounter](c, a)

    a_delta = a.increment(9)
    b_delta = b.increment(8)
    c_delta = c.decrement(7)

    h.assert_eq[U64](a.value(), 11)
    h.assert_eq[U64](b.value(), 10)
    h.assert_eq[U64](c.value(), -5)
    h.assert_ne[PNCounter](a, b)
    h.assert_ne[PNCounter](b, c)
    h.assert_ne[PNCounter](c, a)

    h.assert_true(a.converge(b_delta))
    h.assert_true(a.converge(c_delta))
    h.assert_true(b.converge(c_delta))
    h.assert_true(b.converge(a_delta))
    h.assert_true(c.converge(a_delta))
    h.assert_true(c.converge(b_delta))

    h.assert_eq[U64](a.value(), 12)
    h.assert_eq[U64](b.value(), 12)
    h.assert_eq[U64](c.value(), 12)
    h.assert_eq[PNCounter](a, b)
    h.assert_eq[PNCounter](b, c)
    h.assert_eq[PNCounter](c, a)

class TestPNCounterTokens is UnitTest
  new iso create() => None
  fun name(): String => "crdt.PNCounter (tokens)"

  fun apply(h: TestHelper) =>
    let data   = PNCounter[U8]("a".hash64())
    let data'  = PNCounter[U8]("b".hash64())
    let data'' = PNCounter[U8]("c".hash64())

    data.increment(4)
    data'.decrement(5)
    data''.increment(6)

    data.converge(data')
    data.converge(data'')

    let tokens = Tokens .> from(data)
    _TestTokensWellFormed(h, tokens)

    try
      h.assert_eq[PNCounter[U8]](
        data,
        data.create(0) .> from_tokens(tokens.iterator())?
      )
    else
      h.fail("failed to parse token stream")
    end
