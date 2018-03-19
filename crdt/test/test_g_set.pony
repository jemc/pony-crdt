use "ponytest"
use ".."

class TestGSet is UnitTest
  new iso create() => None
  fun name(): String => "crdt.GSet"

  fun apply(h: TestHelper) =>
    let a = GSet[String]
    let b = GSet[String]
    let c = GSet[String]

    a.set("apple")
    b.set("banana")
    c.set("currant")

    h.assert_eq[USize](a.size(), 1)
    h.assert_eq[USize](b.size(), 1)
    h.assert_eq[USize](c.size(), 1)
    h.assert_ne[GSet[String]](a, b)
    h.assert_ne[GSet[String]](b, c)
    h.assert_ne[GSet[String]](c, a)

    h.assert_false(a.converge(a))

    h.assert_true(a.converge(b))
    h.assert_true(a.converge(c))
    h.assert_true(b.converge(c))
    h.assert_true(b.converge(a))
    h.assert_true(c.converge(a))
    h.assert_false(c.converge(b))

    h.assert_eq[USize](a.size(), 3)
    h.assert_eq[USize](b.size(), 3)
    h.assert_eq[USize](c.size(), 3)
    h.assert_eq[GSet[String]](a, b)
    h.assert_eq[GSet[String]](b, c)
    h.assert_eq[GSet[String]](c, a)

class TestGSetDelta is UnitTest
  new iso create() => None
  fun name(): String => "crdt.GSet (ẟ)"

  fun apply(h: TestHelper) =>
    let a = GSet[String]
    let b = GSet[String]
    let c = GSet[String]

    let a_delta = a.set("apple")
    let b_delta = b.set("banana")
    let c_delta = c.set("currant")

    h.assert_eq[USize](a.size(), 1)
    h.assert_eq[USize](b.size(), 1)
    h.assert_eq[USize](c.size(), 1)
    h.assert_ne[GSet[String]](a, b)
    h.assert_ne[GSet[String]](b, c)
    h.assert_ne[GSet[String]](c, a)

    h.assert_false(a.converge(a_delta))

    h.assert_true(a.converge(b_delta))
    h.assert_true(a.converge(c_delta))
    h.assert_true(b.converge(c_delta))
    h.assert_true(b.converge(a_delta))
    h.assert_true(c.converge(a_delta))
    h.assert_true(c.converge(b_delta))

    h.assert_eq[USize](a.size(), 3)
    h.assert_eq[USize](b.size(), 3)
    h.assert_eq[USize](c.size(), 3)
    h.assert_eq[GSet[String]](a, b)
    h.assert_eq[GSet[String]](b, c)
    h.assert_eq[GSet[String]](c, a)
