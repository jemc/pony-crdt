use "ponytest"

actor Main is TestList
  new create(env: Env) => PonyTest(env, this)

  fun tag tests(test: PonyTest) =>
    test(TestGSet)
    test(TestGSetDelta)
    test(TestP2Set)
    test(TestP2SetDelta)
    test(TestTSet)
    test(TestTSetDelta)
    test(TestTReg)
    test(TestTRegDelta)
    test(TestTLog)
    test(TestTLogDelta)
    test(TestGCounter)
    test(TestGCounterDelta)
    test(TestPNCounter)
    test(TestPNCounterDelta)
    test(TestCCounter)
    test(TestCCounterDelta)
    test(TestAWORSet)
    test(TestAWORSetDelta)
    test(TestRWORSet)
    test(TestRWORSetDelta)
    test(TestUJSON)
    test(TestUJSONDelta)
    test(TestUJSONNode)
