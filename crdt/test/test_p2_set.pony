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
    
    a.>converge(b).>converge(c)
    b.>converge(c).>converge(a)
    c.>converge(a).>converge(b)
    
    h.assert_eq[USize](a.size(), 3)
    h.assert_eq[USize](b.size(), 3)
    h.assert_eq[USize](b.size(), 3)
    h.assert_eq[P2Set[String]](a, b)
    h.assert_eq[P2Set[String]](b, c)
    h.assert_eq[P2Set[String]](c, a)
    
    c.unset("currant")
    a.>converge(c)
    b.>converge(c)
    
    h.assert_eq[USize](a.size(), 2)
    h.assert_eq[USize](b.size(), 2)
    h.assert_eq[USize](b.size(), 2)
    h.assert_eq[P2Set[String]](a, b)
    h.assert_eq[P2Set[String]](b, c)
    h.assert_eq[P2Set[String]](c, a)
    
    c.unset("banana")
    c.unset("apple")
    a.>converge(c)
    b.>converge(c)
    
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
    
    a.>converge(b_delta).>converge(c_delta)
    b.>converge(c_delta).>converge(a_delta)
    c.>converge(a_delta).>converge(b_delta)
    
    h.assert_eq[USize](a.size(), 3)
    h.assert_eq[USize](b.size(), 3)
    h.assert_eq[USize](b.size(), 3)
    h.assert_eq[P2Set[String]](a, b)
    h.assert_eq[P2Set[String]](b, c)
    h.assert_eq[P2Set[String]](c, a)
    
    c_delta = c.unset("currant")
    a.>converge(c_delta)
    b.>converge(c_delta)
    
    h.assert_eq[USize](a.size(), 2)
    h.assert_eq[USize](b.size(), 2)
    h.assert_eq[USize](b.size(), 2)
    h.assert_eq[P2Set[String]](a, b)
    h.assert_eq[P2Set[String]](b, c)
    h.assert_eq[P2Set[String]](c, a)
    
    c_delta = c.unset("banana")
    c_delta = c.unset("apple", consume c_delta)
    a.>converge(c_delta)
    b.>converge(c_delta)
    
    h.assert_eq[USize](a.size(), 0)
    h.assert_eq[USize](b.size(), 0)
    h.assert_eq[USize](b.size(), 0)
    h.assert_eq[P2Set[String]](a, b)
    h.assert_eq[P2Set[String]](b, c)
    h.assert_eq[P2Set[String]](c, a)
