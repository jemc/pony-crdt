use "ponytest"
use ".."

class TestRWORSet is UnitTest
  new iso create() => None
  fun name(): String => "crdt.RWORSet"

  fun apply(h: TestHelper) =>
    let a = RWORSet[String]("a".hash64())
    let b = RWORSet[String]("b".hash64())
    let c = RWORSet[String]("c".hash64())

    a.set("apple")
    b.set("banana")
    c.set("currant")

    h.assert_eq[USize](a.size(), 1)
    h.assert_eq[USize](b.size(), 1)
    h.assert_eq[USize](b.size(), 1)
    h.assert_ne[RWORSet[String]](a, b)
    h.assert_ne[RWORSet[String]](b, c)
    h.assert_ne[RWORSet[String]](c, a)

    h.assert_false(a.converge(a))

    h.assert_true(a.converge(b))
    h.assert_true(a.converge(c))
    h.assert_true(b.converge(c))
    h.assert_true(b.converge(a))
    h.assert_true(c.converge(a))
    h.assert_false(c.converge(b))

    h.assert_eq[USize](a.size(), 3)
    h.assert_eq[USize](b.size(), 3)
    h.assert_eq[USize](b.size(), 3)
    h.assert_eq[RWORSet[String]](a, b)
    h.assert_eq[RWORSet[String]](b, c)
    h.assert_eq[RWORSet[String]](c, a)

    c.unset("currant")

    h.assert_true(a.converge(c))
    h.assert_true(b.converge(c))
    h.assert_false(a.converge(b))

    h.assert_eq[USize](a.size(), 2)
    h.assert_eq[USize](b.size(), 2)
    h.assert_eq[USize](b.size(), 2)
    h.assert_eq[RWORSet[String]](a, b)
    h.assert_eq[RWORSet[String]](b, c)
    h.assert_eq[RWORSet[String]](c, a)

    c.unset("apple")
    c.unset("banana")
    c.set("currant")

    h.assert_true(a.converge(c))
    h.assert_true(b.converge(c))
    h.assert_false(a.converge(b))

    h.assert_true(a.contains("currant"))
    h.assert_eq[USize](a.size(), 1)
    h.assert_eq[USize](b.size(), 1)
    h.assert_eq[USize](b.size(), 1)
    h.assert_eq[RWORSet[String]](a, b)
    h.assert_eq[RWORSet[String]](b, c)
    h.assert_eq[RWORSet[String]](c, a)

    a.set("dewberry")
    a.unset("dewberry")
    b.set("dewberry")

    h.assert_true(a.converge(b))
    h.assert_false(a.converge(c))
    h.assert_false(b.converge(c))
    h.assert_true(b.converge(a))
    h.assert_true(c.converge(a))
    h.assert_false(c.converge(b))

    h.assert_false(c.contains("dewberry")) // remove wins
    h.assert_eq[USize](a.size(), 1)
    h.assert_eq[USize](b.size(), 1)
    h.assert_eq[USize](b.size(), 1)
    h.assert_eq[RWORSet[String]](a, b)
    h.assert_eq[RWORSet[String]](b, c)
    h.assert_eq[RWORSet[String]](c, a)

class TestRWORSetDelta is UnitTest
  new iso create() => None
  fun name(): String => "crdt.RWORSet (ẟ)"

  fun apply(h: TestHelper) =>
    let a = RWORSet[String]("a".hash64())
    let b = RWORSet[String]("b".hash64())
    let c = RWORSet[String]("c".hash64())

    var a_delta = a.set("apple")
    var b_delta = b.set("banana")
    var c_delta = c.set("currant")

    h.assert_eq[USize](a.size(), 1)
    h.assert_eq[USize](b.size(), 1)
    h.assert_eq[USize](b.size(), 1)
    h.assert_ne[RWORSet[String]](a, b)
    h.assert_ne[RWORSet[String]](b, c)
    h.assert_ne[RWORSet[String]](c, a)

    h.assert_false(a.converge(a_delta))

    h.assert_true(a.converge(b_delta))
    h.assert_true(a.converge(c_delta))
    h.assert_true(b.converge(c_delta))
    h.assert_true(b.converge(a_delta))
    h.assert_true(c.converge(a_delta))
    h.assert_true(c.converge(b_delta))

    h.assert_eq[USize](a.size(), 3)
    h.assert_eq[USize](b.size(), 3)
    h.assert_eq[USize](b.size(), 3)
    h.assert_eq[RWORSet[String]](a, b)
    h.assert_eq[RWORSet[String]](b, c)
    h.assert_eq[RWORSet[String]](c, a)

    c_delta = c.unset("currant")

    h.assert_true(a.converge(c_delta))
    h.assert_true(b.converge(c_delta))
    h.assert_false(c.converge(c_delta))

    h.assert_eq[USize](a.size(), 2)
    h.assert_eq[USize](b.size(), 2)
    h.assert_eq[USize](b.size(), 2)
    h.assert_eq[RWORSet[String]](a, b)
    h.assert_eq[RWORSet[String]](b, c)
    h.assert_eq[RWORSet[String]](c, a)

    c_delta = c.unset("banana")
    c_delta = c.unset("apple", consume c_delta)
    c_delta = c.set("currant", consume c_delta)

    h.assert_true(a.converge(c_delta))
    h.assert_true(b.converge(c_delta))
    h.assert_false(c.converge(c_delta))

    h.assert_true(a.contains("currant"))
    h.assert_eq[USize](a.size(), 1)
    h.assert_eq[USize](b.size(), 1)
    h.assert_eq[USize](b.size(), 1)
    h.assert_eq[RWORSet[String]](a, b)
    h.assert_eq[RWORSet[String]](b, c)
    h.assert_eq[RWORSet[String]](c, a)

    a_delta = a.set("dewberry")
    a_delta = a.unset("dewberry", consume a_delta)
    b_delta = b.set("dewberry")

    h.assert_true(a.converge(b_delta))
    h.assert_true(b.converge(a_delta))
    h.assert_true(c.converge(a_delta))
    h.assert_true(c.converge(b_delta))

    h.assert_false(a.contains("dewberry")) // remove wins
    h.assert_eq[USize](a.size(), 1)
    h.assert_eq[USize](b.size(), 1)
    h.assert_eq[USize](b.size(), 1)
    h.assert_eq[RWORSet[String]](a, b)
    h.assert_eq[RWORSet[String]](b, c)
    h.assert_eq[RWORSet[String]](c, a)

class TestRWORSetTokens is UnitTest
  new iso create() => None
  fun name(): String => "crdt.RWORSet (tokens)"

  fun apply(h: TestHelper) =>
    let data   = RWORSet[String]("a".hash64())
    let data'  = RWORSet[String]("b".hash64())
    let data'' = RWORSet[String]("c".hash64())

    data.set("apple")
    data'.unset("apple")
    data''.set("banana")

    data.converge(data')
    data.converge(data'')

    let tokens = Tokens .> from(data)
    _TestTokensWellFormed(h, tokens)

    try
      h.assert_eq[RWORSet[String]](
        data,
        data.create(0) .> from_tokens(tokens.iterator())?
      )
    else
      h.fail("failed to parse token stream")
    end
