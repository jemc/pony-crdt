
use "ponycheck"
use ".."
use "collections"

class val _PNCounterCmd is Stringable
  let u_cmd: {(U64): U64 } val
  let cc_cmd: {(PNCounter)} val
  let diff: U64
  let op: _CounterOp

  new val create(diff': U64, op': _CounterOp = _INC) =>
    diff = diff'
    op = op'
    cc_cmd = {(cc) => if op is _INC then cc.increment(diff) else cc.decrement(diff) end } val
    u_cmd = {(t) => if op is _INC then t + diff else t - diff end } val

  fun string(): String iso^ =>
    recover
      String()
        .>append(if op is _INC then "+" else "-" end + diff.string())
    end

trait PNCounterProperty is Property1[(USize, Array[_CmdOnReplica[_PNCounterCmd]])]
  fun property(sample: (USize, Array[_CmdOnReplica[_PNCounterCmd]]), h: PropertyHelper) ? =>
    """
    validate that an array of commands against random replicas
    converges to the same value as a U64 counter exposed to the same commands.
    """
    (let num_replicas, let commands) = sample
    let replicas: Array[PNCounter] = replicas.create(num_replicas)
    for x in Range[U64](0, num_replicas.u64()) do
      replicas.push(PNCounter(x))
    end

    var expected: U64 = 0
    for command in commands.values() do
      let cmd = command.cmd
      h.log("executing " +  cmd.string(), true)

      cmd.cc_cmd(replicas(command.replica)?)
      expected = cmd.u_cmd(expected)

      let observer = PNCounter(U64.max_value())
      for replica in replicas.values() do
        observer.converge(replica)
      end
      if not h.assert_eq[U64](observer.value(), expected) then return end
    end


class PNCounterIncProperty is PNCounterProperty
  """
  verify that a set of PNCounter replicas that are only incremented
  behave like a single U64 counter once completely converged.
  """

  fun name(): String => "crdt.prop.PNCounter.Inc"

  fun gen(): Generator[(USize, Array[_CmdOnReplica[_PNCounterCmd]])] =>
    Generators.usize(2, 10).flat_map[(USize, Array[_CmdOnReplica[_PNCounterCmd]])]({
      (num_replicas) =>
        let cmds_gen = Generators.array_of[_CmdOnReplica[_PNCounterCmd]](
          Generators.map2[USize, U64, _CmdOnReplica[_PNCounterCmd]](
            Generators.usize(0, num_replicas-1),
            Generators.u64(),
            {(replica, inc) => _CmdOnReplica[_PNCounterCmd](replica, _PNCounterCmd(inc, _INC)) }
          )
        )
        Generators.zip2[USize, Array[_CmdOnReplica[_PNCounterCmd]]](
          Generators.unit[USize](num_replicas), cmds_gen
        )
    })


class PNCounterIncDecProperty is PNCounterProperty
  """
  verify that a set of PNCounter replicas that are incremented and decremented
  behave like a single U64 counter once completely converged.
  """

  fun name(): String => "crdt.prop.PNCounter"

  fun gen(): Generator[(USize, Array[_CmdOnReplica[_PNCounterCmd]])] =>
    Generators.usize(2, 10).flat_map[(USize, Array[_CmdOnReplica[_PNCounterCmd]])]({
      (num_replicas) =>
        let cmds_gen = Generators.array_of[_CmdOnReplica[_PNCounterCmd]](
          Generators.map2[USize, _PNCounterCmd, _CmdOnReplica[_PNCounterCmd]](
            Generators.usize(0, num_replicas-1),
            Generators.u64().flat_map[_PNCounterCmd]({
              (u) =>
                Generators.one_of[_PNCounterCmd]([
                   _PNCounterCmd(u, _INC)
                   _PNCounterCmd(u, _DEC)
                ])

            }),
            {(replica, cmd) => _CmdOnReplica[_PNCounterCmd](replica, cmd) }
          )
        )
        Generators.zip2[USize, Array[_CmdOnReplica[_PNCounterCmd]]](
          Generators.unit[USize](num_replicas), cmds_gen
        )
    })

