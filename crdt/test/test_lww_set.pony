use "ponytest"
use ".."

class TestLWWSet is UnitTest
  new iso create() => None
  fun name(): String => "crdt.LWWSet"

  fun apply(h: TestHelper) =>
    let a = LWWSet[String]
    let b = LWWSet[String]
    let c = LWWSet[String]

    a.set("apple", 5)
    b.set("banana", 5)
    c.set("currant", 5)

    h.assert_eq[USize](a.size(), 1)
    h.assert_eq[USize](b.size(), 1)
    h.assert_eq[USize](c.size(), 1)
    h.assert_ne[LWWSet[String]](a, b)
    h.assert_ne[LWWSet[String]](b, c)
    h.assert_ne[LWWSet[String]](c, a)

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
    h.assert_eq[LWWSet[String]](a, b)
    h.assert_eq[LWWSet[String]](b, c)
    h.assert_eq[LWWSet[String]](c, a)

    c.unset("currant", 6)
    h.assert_true(a.converge(c))
    h.assert_true(b.converge(c))

    h.assert_eq[USize](a.size(), 2)
    h.assert_eq[USize](b.size(), 2)
    h.assert_eq[USize](c.size(), 2)
    h.assert_eq[LWWSet[String]](a, b)
    h.assert_eq[LWWSet[String]](b, c)
    h.assert_eq[LWWSet[String]](c, a)

    c.unset("banana", 4)
    c.unset("apple", 5)
    h.assert_false(a.converge(c))
    h.assert_false(b.converge(c))

    h.assert_eq[USize](a.size(), 2)
    h.assert_eq[USize](b.size(), 2)
    h.assert_eq[USize](c.size(), 2)
    h.assert_eq[LWWSet[String]](a, b)
    h.assert_eq[LWWSet[String]](b, c)
    h.assert_eq[LWWSet[String]](c, a)

    c.unset("banana", 7)
    c.unset("apple", 8)
    h.assert_true(a.converge(c))
    h.assert_true(b.converge(c))

    h.assert_eq[USize](a.size(), 0)
    h.assert_eq[USize](b.size(), 0)
    h.assert_eq[USize](c.size(), 0)
    h.assert_eq[LWWSet[String]](a, b)
    h.assert_eq[LWWSet[String]](b, c)
    h.assert_eq[LWWSet[String]](c, a)

class TestLWWSetDelta is UnitTest
  new iso create() => None
  fun name(): String => "crdt.LWWSet (ẟ)"

  fun apply(h: TestHelper) =>
    let a = LWWSet[String]
    let b = LWWSet[String]
    let c = LWWSet[String]

    var a_delta = a.set("apple", 5)
    var b_delta = b.set("banana", 5)
    var c_delta = c.set("currant", 5)

    h.assert_eq[USize](a.size(), 1)
    h.assert_eq[USize](b.size(), 1)
    h.assert_eq[USize](c.size(), 1)
    h.assert_ne[LWWSet[String]](a, b)
    h.assert_ne[LWWSet[String]](b, c)
    h.assert_ne[LWWSet[String]](c, a)

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
    h.assert_eq[LWWSet[String]](a, b)
    h.assert_eq[LWWSet[String]](b, c)
    h.assert_eq[LWWSet[String]](c, a)

    c_delta = c.unset("currant", 6)
    h.assert_true(a.converge(c_delta))
    h.assert_true(b.converge(c_delta))

    h.assert_eq[USize](a.size(), 2)
    h.assert_eq[USize](b.size(), 2)
    h.assert_eq[USize](c.size(), 2)
    h.assert_eq[LWWSet[String]](a, b)
    h.assert_eq[LWWSet[String]](b, c)
    h.assert_eq[LWWSet[String]](c, a)

    c_delta = c.unset("banana", 4)
    c_delta = c.unset("apple", 5, consume c_delta)
    h.assert_false(a.converge(c_delta))
    h.assert_false(b.converge(c_delta))

    h.assert_eq[USize](a.size(), 2)
    h.assert_eq[USize](b.size(), 2)
    h.assert_eq[USize](c.size(), 2)
    h.assert_eq[LWWSet[String]](a, b)
    h.assert_eq[LWWSet[String]](b, c)
    h.assert_eq[LWWSet[String]](c, a)

    c_delta = c.unset("banana", 7)
    c_delta = c.unset("apple", 8, consume c_delta)
    h.assert_true(a.converge(c_delta))
    h.assert_true(b.converge(c_delta))

    h.assert_eq[USize](a.size(), 0)
    h.assert_eq[USize](b.size(), 0)
    h.assert_eq[USize](c.size(), 0)
    h.assert_eq[LWWSet[String]](a, b)
    h.assert_eq[LWWSet[String]](b, c)
    h.assert_eq[LWWSet[String]](c, a)
