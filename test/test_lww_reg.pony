use "ponytest"
use "../crdt"

class TestLWWReg is UnitTest
  new iso create() => None
  fun name(): String => "crdt.LWWReg"
  
  fun apply(h: TestHelper) =>
    let a = LWWReg[String]("apple", 3)
    let b = LWWReg[String]("banana", 2)
    let c = LWWReg[String]("currant", 1)
    
    h.assert_eq[String](a.value(), "apple")
    h.assert_eq[String](b.value(), "banana")
    h.assert_eq[String](c.value(), "currant")
    h.assert_eq[U64](a.timestamp(), 3)
    h.assert_eq[U64](b.timestamp(), 2)
    h.assert_eq[U64](c.timestamp(), 1)
    
    a.>converge(b).>converge(c)
    b.>converge(c).>converge(a)
    c.>converge(a).>converge(b)
    
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
    
    a.>converge(b).>converge(c)
    b.>converge(c).>converge(a)
    c.>converge(a).>converge(b)
    
    h.assert_eq[String](a.value(), "currant")
    h.assert_eq[String](b.value(), "currant")
    h.assert_eq[String](c.value(), "currant")
    h.assert_eq[U64](a.timestamp(), 5)
    h.assert_eq[U64](b.timestamp(), 5)
    h.assert_eq[U64](c.timestamp(), 5)

class TestLWWRegDelta is UnitTest
  new iso create() => None
  fun name(): String => "crdt.LWWReg (ẟ)"
  
  fun apply(h: TestHelper) =>
    let a = LWWReg[String]("apple", 3)
    let b = LWWReg[String]("banana", 2)
    let c = LWWReg[String]("currant", 1)
    
    h.assert_eq[String](a.value(), "apple")
    h.assert_eq[String](b.value(), "banana")
    h.assert_eq[String](c.value(), "currant")
    h.assert_eq[U64](a.timestamp(), 3)
    h.assert_eq[U64](b.timestamp(), 2)
    h.assert_eq[U64](c.timestamp(), 1)
    
    a.>converge(b).>converge(c)
    b.>converge(c).>converge(a)
    c.>converge(a).>converge(b)
    
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
    
    a.>converge(b_delta).>converge(c_delta)
    b.>converge(c_delta).>converge(a_delta)
    c.>converge(a_delta).>converge(b_delta)
    
    h.assert_eq[String](a.value(), "currant")
    h.assert_eq[String](b.value(), "currant")
    h.assert_eq[String](c.value(), "currant")
    h.assert_eq[U64](a.timestamp(), 5)
    h.assert_eq[U64](b.timestamp(), 5)
    h.assert_eq[U64](c.timestamp(), 5)
