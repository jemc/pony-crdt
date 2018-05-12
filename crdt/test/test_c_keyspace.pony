use "ponytest"
use ".."

class TestCKeyspace is UnitTest
  new iso create() => None
  fun name(): String => "crdt.CKeyspace"

  fun apply(h: TestHelper) =>
    let a = CKeyspace[String, CCounter]("a".hash64())
    let b = CKeyspace[String, CCounter]("b".hash64())
    let c = CKeyspace[String, CCounter]("c".hash64())

    a.at("apple").increment(4)
    b.at("apple").decrement(5)
    c.at("apple").increment(6)

    b.at("banana").decrement(7)
    c.at("currant").increment(8)

    h.assert_true(a.converge(b))
    h.assert_true(a.converge(c))
    h.assert_true(b.converge(c))
    h.assert_true(b.converge(a))
    h.assert_true(c.converge(a))
    h.assert_false(c.converge(b))

    h.assert_eq[U64](a.at("apple").value(), 5)
    h.assert_eq[U64](a.at("banana").value(), -7)
    h.assert_eq[U64](a.at("currant").value(), 8)
    h.assert_eq[U64](try a("date")?.value() else 0xDEAD end, 0xDEAD)
    h.assert_eq[String](a.string(), b.string())
    h.assert_eq[String](b.string(), c.string())
    h.assert_eq[String](c.string(), a.string())

    a.at("date").increment(9)
    b.remove("date")
    c.remove("currant")
    a.remove("banana")
    b.at("banana").increment(10)

    h.assert_true(a.converge(b))
    h.assert_true(a.converge(c))
    h.assert_true(b.converge(c))
    h.assert_true(b.converge(a))
    h.assert_true(c.converge(a))
    h.assert_false(c.converge(b))

    h.assert_eq[U64](a.at("apple").value(), 5)
    h.assert_eq[U64](a.at("banana").value(), 3)
    h.assert_eq[U64](try a("currant")?.value() else 0xDEAD end, 0xDEAD)
    h.assert_eq[U64](a.at("date").value(), 9)
    h.assert_eq[String](a.string(), b.string())
    h.assert_eq[String](b.string(), c.string())
    h.assert_eq[String](c.string(), a.string())

    a.clear()

    h.assert_eq[U64](try a("apple")?.value() else 0xDEAD end, 0xDEAD)
    h.assert_eq[U64](try a("banana")?.value() else 0xDEAD end, 0xDEAD)
    h.assert_eq[U64](try a("currant")?.value() else 0xDEAD end, 0xDEAD)
    h.assert_eq[U64](try a("date")?.value() else 0xDEAD end, 0xDEAD)

class TestCKeyspaceDelta is UnitTest
  new iso create() => None
  fun name(): String => "crdt.CKeyspace (ẟ)"

  fun apply(h: TestHelper) =>
    let a = CKeyspace[String, CCounter]("a".hash64())
    let b = CKeyspace[String, CCounter]("b".hash64())
    let c = CKeyspace[String, CCounter]("c".hash64())

    var a_delta = CKeyspace[String, CCounter](0)
    var b_delta = CKeyspace[String, CCounter](0)
    var c_delta = CKeyspace[String, CCounter](0)

    a.at("apple").increment(4, a_delta.at("apple"))
    b.at("apple").decrement(5, b_delta.at("apple"))
    c.at("apple").increment(6, c_delta.at("apple"))

    b.at("banana").decrement(7, b_delta.at("banana"))
    c.at("currant").increment(8, c_delta.at("currant"))

    h.assert_true(a.converge(b_delta))
    h.assert_true(a.converge(c_delta))
    h.assert_true(b.converge(c_delta))
    h.assert_true(b.converge(a_delta))
    h.assert_true(c.converge(a_delta))
    h.assert_true(c.converge(b_delta))

    h.assert_eq[U64](a.at("apple").value(), 5)
    h.assert_eq[U64](a.at("banana").value(), -7)
    h.assert_eq[U64](a.at("currant").value(), 8)
    h.assert_eq[U64](try a("date")?.value() else 0xDEAD end, 0xDEAD)
    h.assert_eq[String](a.string(), b.string())
    h.assert_eq[String](b.string(), c.string())
    h.assert_eq[String](c.string(), a.string())

    a_delta = CKeyspace[String, CCounter](0)
    b_delta = CKeyspace[String, CCounter](0)
    c_delta = CKeyspace[String, CCounter](0)

    a.at("date").increment(9, a_delta.at("date"))
    b.remove("date", b_delta)
    c.remove("currant", c_delta)
    a.remove("banana", a_delta)
    b.at("banana").increment(10, b_delta.at("banana"))

    h.assert_true(a.converge(b_delta))
    h.assert_true(a.converge(c_delta))
    h.assert_true(b.converge(c_delta))
    h.assert_true(b.converge(a_delta))
    h.assert_true(c.converge(a_delta))
    h.assert_true(c.converge(b_delta))

    h.assert_eq[U64](a.at("apple").value(), 5)
    h.assert_eq[U64](a.at("banana").value(), 3)
    h.assert_eq[U64](try a("currant")?.value() else 0xDEAD end, 0xDEAD)
    h.assert_eq[U64](a.at("date").value(), 9)
    h.assert_eq[String](a.string(), b.string())
    h.assert_eq[String](b.string(), c.string())
    h.assert_eq[String](c.string(), a.string())

    b_delta = CKeyspace[String, CCounter](0)

    b.clear(b_delta)

    h.assert_true(a.converge(b_delta))
    h.assert_false(b.converge(b_delta))
    h.assert_true(c.converge(b_delta))

    h.assert_eq[U64](try a("apple")?.value() else 0xDEAD end, 0xDEAD)
    h.assert_eq[U64](try a("banana")?.value() else 0xDEAD end, 0xDEAD)
    h.assert_eq[U64](try a("currant")?.value() else 0xDEAD end, 0xDEAD)
    h.assert_eq[U64](try a("date")?.value() else 0xDEAD end, 0xDEAD)

class TestCKeyspaceTokens is UnitTest
  new iso create() => None
  fun name(): String => "crdt.CKeyspace (tokens)"

  fun apply(h: TestHelper) =>
    None // TODO
