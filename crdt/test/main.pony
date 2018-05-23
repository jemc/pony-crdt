use "ponytest"
use "ponycheck"

actor Main is TestList
  new create(env: Env) => PonyTest(env, this)

  fun tag tests(test: PonyTest) =>
    // TODO add unit tests for edge cases of DotContext, DotKernel, etc

    test(TestGSet)
    test(TestGSetDelta)
    test(TestGSetTokens)

    test(TestP2Set)
    test(TestP2SetDelta)
    test(TestP2SetTokens)

    test(TestTSet)
    test(TestTSetDelta)
    test(TestTSetTokens)

    test(TestTReg)
    test(TestTRegDelta)
    test(TestTRegTokens)

    test(TestTLog)
    test(TestTLogDelta)
    test(TestTLogTokens)

    test(TestGCounter)
    test(TestGCounterDelta)
    test(TestGCounterTokens)

    test(TestPNCounter)
    test(TestPNCounterDelta)
    test(TestPNCounterTokens)

    test(TestCCounter)
    test(TestCCounterDelta)
    test(TestCCounterTokens)

    test(TestAWORSet)
    test(TestAWORSetDelta)
    test(TestAWORSetTokens)

    test(TestRWORSet)
    test(TestRWORSetDelta)
    test(TestRWORSetTokens)

    test(TestUJSON)
    test(TestUJSONDelta)
    test(TestUJSONTokens)
    test(TestUJSONNode)

    test(TestCKeyspace)
    test(TestCKeyspaceDelta)
    test(TestCKeyspaceTokens)

    test(Property1UnitTest[(USize, Array[_CmdOnReplica])](CCounterIncProperty))
    test(Property1UnitTest[(USize, Array[_CmdOnReplica])](CCounterIncDecProperty))
    test(Property1UnitTest[(USize, Array[_CmdOnReplica[U64]])](GCounterIncProperty))
    test(Property1UnitTest[(USize, Array[_CmdOnReplica[_PNCounterCmd]])](PNCounterIncProperty))
    test(Property1UnitTest[(USize, Array[_CmdOnReplica[_PNCounterCmd]])](PNCounterIncDecProperty))
