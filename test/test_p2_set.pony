use "ponytest"
use "../crdt"

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
    
    a.>converge(b.data()).>converge(c.data())
    b.>converge(c.data()).>converge(a.data())
    c.>converge(a.data()).>converge(b.data())
    
    h.assert_eq[USize](a.size(), 3)
    h.assert_eq[USize](b.size(), 3)
    h.assert_eq[USize](b.size(), 3)
    h.assert_eq[P2Set[String]](a, b)
    h.assert_eq[P2Set[String]](b, c)
    h.assert_eq[P2Set[String]](c, a)
    
    c.unset("currant")
    a.>converge(c.data())
    b.>converge(c.data())
    
    h.assert_eq[USize](a.size(), 2)
    h.assert_eq[USize](b.size(), 2)
    h.assert_eq[USize](b.size(), 2)
    h.assert_eq[P2Set[String]](a, b)
    h.assert_eq[P2Set[String]](b, c)
    h.assert_eq[P2Set[String]](c, a)
    
    c.unset("banana")
    c.unset("apple")
    a.>converge(c.data())
    b.>converge(c.data())
    
    h.assert_eq[USize](a.size(), 0)
    h.assert_eq[USize](b.size(), 0)
    h.assert_eq[USize](b.size(), 0)
    h.assert_eq[P2Set[String]](a, b)
    h.assert_eq[P2Set[String]](b, c)
    h.assert_eq[P2Set[String]](c, a)
