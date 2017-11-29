use "ponytest"
use ".."

class TestP2Set is UnitTest
  new iso create() => None
  fun name(): String => "crdt.P2Set"
  
  fun apply(h: TestHelper) =>
    let a = P2Set[String]
    let b = P2Set[String]
    let c = P2Set[String]
    
    a.set("apple")
    b.set("banana")
    c.set("currant")
    
    h.assert_eq[USize](a.size(), 1)
    h.assert_eq[USize](b.size(), 1)
    h.assert_eq[USize](b.size(), 1)
    h.assert_ne[P2Set[String]](a, b)
    h.assert_ne[P2Set[String]](b, c)
    h.assert_ne[P2Set[String]](c, a)
    
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
    h.assert_eq[P2Set[String]](a, b)
    h.assert_eq[P2Set[String]](b, c)
    h.assert_eq[P2Set[String]](c, a)
    
    c.unset("currant")
    h.assert_true(a.converge(c))
    h.assert_true(b.converge(c))
    
    h.assert_false(a.converge(b))
    
    h.assert_eq[USize](a.size(), 2)
    h.assert_eq[USize](b.size(), 2)
    h.assert_eq[USize](b.size(), 2)
    h.assert_eq[P2Set[String]](a, b)
    h.assert_eq[P2Set[String]](b, c)
    h.assert_eq[P2Set[String]](c, a)
    
    c.unset("banana")
    c.unset("apple")
    h.assert_true(a.converge(c))
    h.assert_true(b.converge(c))
    
    h.assert_false(a.converge(b))
    
    h.assert_eq[USize](a.size(), 0)
    h.assert_eq[USize](b.size(), 0)
    h.assert_eq[USize](b.size(), 0)
    h.assert_eq[P2Set[String]](a, b)
    h.assert_eq[P2Set[String]](b, c)
    h.assert_eq[P2Set[String]](c, a)

class TestP2SetDelta is UnitTest
  new iso create() => None
  fun name(): String => "crdt.P2Set (ẟ)"
  
  fun apply(h: TestHelper) =>
    let a = P2Set[String]
    let b = P2Set[String]
    let c = P2Set[String]
    
    var a_delta = a.set("apple")
    var b_delta = b.set("banana")
    var c_delta = c.set("currant")
    
    h.assert_eq[USize](a.size(), 1)
    h.assert_eq[USize](b.size(), 1)
    h.assert_eq[USize](b.size(), 1)
    h.assert_ne[P2Set[String]](a, b)
    h.assert_ne[P2Set[String]](b, c)
    h.assert_ne[P2Set[String]](c, a)
    
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
    h.assert_eq[P2Set[String]](a, b)
    h.assert_eq[P2Set[String]](b, c)
    h.assert_eq[P2Set[String]](c, a)
    
    c_delta = c.unset("currant")
    h.assert_true(a.converge(c_delta))
    h.assert_true(b.converge(c_delta))
    
    h.assert_false(c.converge(c_delta))
    
    h.assert_eq[USize](a.size(), 2)
    h.assert_eq[USize](b.size(), 2)
    h.assert_eq[USize](b.size(), 2)
    h.assert_eq[P2Set[String]](a, b)
    h.assert_eq[P2Set[String]](b, c)
    h.assert_eq[P2Set[String]](c, a)
    
    c_delta = c.unset("banana")
    c_delta = c.unset("apple", consume c_delta)
    h.assert_true(a.converge(c_delta))
    h.assert_true(b.converge(c_delta))
    
    h.assert_false(c.converge(c_delta))
    
    h.assert_eq[USize](a.size(), 0)
    h.assert_eq[USize](b.size(), 0)
    h.assert_eq[USize](b.size(), 0)
    h.assert_eq[P2Set[String]](a, b)
    h.assert_eq[P2Set[String]](b, c)
    h.assert_eq[P2Set[String]](c, a)
