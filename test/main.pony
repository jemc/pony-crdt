use "ponytest"
use "../crdt"

actor Main is TestList
  new create(env: Env) => PonyTest(env, this)
  
  fun tag tests(test: PonyTest) =>
    // TODO: add randomized testing of delta-convergence for all data types.
    test(TestGSet)
    test(TestGSetDelta)
    test(TestP2Set)
    test(TestP2SetDelta)
    test(TestLWWSet)
    test(TestLWWSetDelta)
    test(TestLWWReg)
    test(TestLWWRegDelta)
    test(TestGCounter)
    test(TestGCounterDelta)
