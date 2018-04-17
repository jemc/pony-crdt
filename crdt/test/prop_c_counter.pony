use "ponycheck"
use ".."
use "collections"

primitive _INC
primitive _DEC
type _CounterOp is (_DEC|_INC)

class val _CCounterCmd is Stringable
  let u_cmd: {(U64): U64 } val
  let cc_cmd: {(CCounter): CCounter^ } val
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

class _CmdOnReplica[T = _CCounterCmd]
  let replica: USize
  let cmd: T

  new create(r: USize, c: T) =>
    replica = r
    cmd = consume c

  fun string(): String iso^ =>
    let str = iftype T <: Stringable #read then cmd.string() else "cmd" end
    recover
      String()
        .>append("_Cmd(")
        .>append(str)
        .>append(",")
        .>append(replica.string())
        .>append(")")
    end

trait CCounterProperty is Property1[(USize, Array[_CmdOnReplica])]
  fun property(sample: (USize, Array[_CmdOnReplica]), h: PropertyHelper) ? =>
    """
    validate that an array of commands against random replicas
    converges to the same value as a U64 counter exposed to the same commands.
    """
    (let num_replicas, let commands) = sample
    let replicas: Array[CCounter] = replicas.create(num_replicas)
    for x in Range[U64](0, num_replicas.u64()) do
      replicas.push(CCounter(x))
    end

    var expected: U64 = 0
    let deltas = Array[CCounter](commands.size())
    for command in commands.values() do
      let cmd = command.cmd
      h.log("executing " +  cmd.string(), true)

      deltas.push(
        cmd.cc_cmd(replicas(command.replica)?)
      )
      expected = cmd.u_cmd(expected)

      let observer = CCounter(U64.max_value())
      for replica in replicas.values() do
        observer.converge(replica)
      end
      if not h.assert_eq[U64](expected, observer.value()) then return end
    end
    let delta_observer = CCounter(U64.max_value() - 1)
    for delta in deltas.values() do
      delta_observer.converge(delta)
    end
    h.assert_eq[U64](expected, delta_observer.value())


class CCounterIncProperty is CCounterProperty
  """
  verify that a set of CCounter replicas that are only incremented
  behave like a single U64 counter once completely converged.
  """

  fun name(): String => "crdt.prop.CCounter.Inc"

  fun gen(): Generator[(USize, Array[_CmdOnReplica])] =>
    Generators.usize(2, 10).flat_map[(USize, Array[_CmdOnReplica])]({
      (num_replicas) =>
        let cmds_gen = Generators.array_of[_CmdOnReplica](
          Generators.map2[USize, U64, _CmdOnReplica](
            Generators.usize(0, num_replicas-1),
            Generators.u64(),
            {(replica, inc) => _CmdOnReplica(replica, _CCounterCmd(inc, _INC)) }
          )
        )
        Generators.zip2[USize, Array[_CmdOnReplica]](
          Generators.unit[USize](num_replicas), cmds_gen)
      })


class CCounterIncDecProperty is CCounterProperty
  """
  verify that a set of CCounter replicas that are incremented and decremented
  behave like a single U64 counter once completely converged.
  """

  fun name(): String => "crdt.prop.CCounter"

  fun gen(): Generator[(USize, Array[_CmdOnReplica])] =>
    Generators.usize(2, 10).flat_map[(USize, Array[_CmdOnReplica])]({
      (num_replicas) =>
        let cmds_gen =
          Generators.array_of[_CmdOnReplica](
            Generators.map2[USize, _CCounterCmd, _CmdOnReplica](
              Generators.usize(0, num_replicas-1),
              Generators.u64().flat_map[_CCounterCmd]({
                (u) =>
                  try
                    Generators.one_of[_CCounterCmd]([
                       _CCounterCmd(u, _INC)
                       _CCounterCmd(u, _DEC)
                    ])?
                  else
                    // shouldn't happen
                    Generators.unit[_CCounterCmd](_CCounterCmd(u, _INC))
                  end
              }),
              {(replica, cmd) => _CmdOnReplica(replica, cmd) }
          )
        )
        Generators.zip2[USize, Array[_CmdOnReplica]](
          Generators.unit[USize](num_replicas),
          cmds_gen)
      })

