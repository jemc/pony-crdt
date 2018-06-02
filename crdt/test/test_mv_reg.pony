use "ponytest"
use ".."

class TestMVReg is UnitTest
  new iso create() => None
  fun name(): String => "crdt.MVReg"

  fun apply(h: TestHelper) =>
    let a = MVReg[String]("a".hash64())
    let b = MVReg[String]("b".hash64())
    let c = MVReg[String]("c".hash64())

    a.update("apple")
    b.update("banana")
    c.update("currant")

    h.assert_eq[USize](a.size(), 1)
    h.assert_eq[USize](b.size(), 1)
    h.assert_eq[USize](b.size(), 1)
    h.assert_ne[MVReg[String]](a, b)
    h.assert_ne[MVReg[String]](b, c)
    h.assert_ne[MVReg[String]](c, a)

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
    h.assert_eq[MVReg[String]](a, b)
    h.assert_eq[MVReg[String]](b, c)
    h.assert_eq[MVReg[String]](c, a)

    c.update("currant")

    h.assert_true(a.converge(c))
    h.assert_true(b.converge(c))
    h.assert_false(a.converge(b))

    h.assert_true(a.contains("currant"))
    h.assert_eq[USize](a.size(), 1)
    h.assert_eq[USize](b.size(), 1)
    h.assert_eq[USize](b.size(), 1)
    h.assert_eq[MVReg[String]](a, b)
    h.assert_eq[MVReg[String]](b, c)
    h.assert_eq[MVReg[String]](c, a)

class TestMVRegDelta is UnitTest
  new iso create() => None
  fun name(): String => "crdt.MVReg (ẟ)"

  fun apply(h: TestHelper) =>
    let a = MVReg[String]("a".hash64())
    let b = MVReg[String]("b".hash64())
    let c = MVReg[String]("c".hash64())

    var a_delta = a.update("apple")
    var b_delta = b.update("banana")
    var c_delta = c.update("currant")

    h.assert_eq[USize](a.size(), 1)
    h.assert_eq[USize](b.size(), 1)
    h.assert_eq[USize](b.size(), 1)
    h.assert_ne[MVReg[String]](a, b)
    h.assert_ne[MVReg[String]](b, c)
    h.assert_ne[MVReg[String]](c, a)

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
    h.assert_eq[MVReg[String]](a, b)
    h.assert_eq[MVReg[String]](b, c)
    h.assert_eq[MVReg[String]](c, a)

    c_delta = c.update("currant")

    h.assert_true(a.converge(c_delta))
    h.assert_true(b.converge(c_delta))
    h.assert_false(c.converge(c_delta))

    h.assert_true(a.contains("currant"))
    h.assert_eq[USize](a.size(), 1)
    h.assert_eq[USize](b.size(), 1)
    h.assert_eq[USize](b.size(), 1)
    h.assert_eq[MVReg[String]](a, b)
    h.assert_eq[MVReg[String]](b, c)
    h.assert_eq[MVReg[String]](c, a)

class TestMVRegTokens is UnitTest
  new iso create() => None
  fun name(): String => "crdt.MVReg (tokens)"

  fun apply(h: TestHelper) =>
    let data   = MVReg[String]("a".hash64())
    let data'  = MVReg[String]("b".hash64())
    let data'' = MVReg[String]("c".hash64())

    data.update("apple")
    data'.update("banana")
    data''.update("currant")

    data.converge(data')
    data.converge(data'')

    let tokens = Tokens .> from(data)
    _TestTokensWellFormed(h, tokens)

    try
      h.assert_eq[MVReg[String]](
        data,
        data.create(0) .> from_tokens(tokens.iterator())?
      )
    else
      h.fail("failed to parse token stream")
    end
