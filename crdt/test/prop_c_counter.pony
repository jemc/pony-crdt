use "ponycheck"
use ".."
use "collections"

primitive _INC
primitive _DEC
type _CounterOp is (_DEC|_INC)

class val _CCounterCmd is Stringable
  let u_cmd: {(U64): U64 } val
  let cc_cmd: {(CCounter)} val
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
  let _replica: USize
  let cmd: T

  new create(r: USize, c: T) =>
    _replica = r
    cmd = consume c

  fun replica(max: USize): USize => _replica % max

trait CCounterProperty is Property1[Array[_CmdOnReplica]]
  fun property(commands: Array[_CmdOnReplica], h: PropertyHelper) ? =>
    """
    validate that an array of commands against random replicas
    converges to the same value as a U64 counter exposed to the same commands.
    """
    let num_replicas = (commands.size() % 10).max(2)
    let replicas: Array[CCounter] = replicas.create(num_replicas)
    for x in Range[U64](0, num_replicas.u64()) do
      replicas.push(CCounter(x))
    end

    var expected: U64 = 0
    for command in commands.values() do
      let cmd = command.cmd
      h.log("executing " +  cmd.string(), true)

      cmd.cc_cmd(replicas(command.replica(num_replicas))?)
      expected = cmd.u_cmd(expected)

      let observer = CCounter(U64.max_value())
      for replica in replicas.values() do
        observer.converge(replica)
      end
      if not h.assert_eq[U64](observer.value(), expected) then return end
    end


class CCounterIncProperty is CCounterProperty
  """
  verify that a set of CCounter replicas that are only incremented
  behave like a single U64 counter once completely converged.
  """

  fun name(): String => "crdt.prop.CCounter.Inc"

  fun gen(): Generator[Array[_CmdOnReplica]] =>
    Generators.seq_of[_CmdOnReplica, Array[_CmdOnReplica]](
      Generators.map2[USize, U64, _CmdOnReplica](
        Generators.usize(),
        Generators.u64(),
        {(replica, inc) => _CmdOnReplica(replica, _CCounterCmd(inc, _INC)) }
      )
    )


class CCounterIncDecProperty is CCounterProperty
  """
  verify that a set of CCounter replicas that are incremented and decremented
  behave like a single U64 counter once completely converged.
  """

  fun name(): String => "crdt.prop.CCounter"

  fun gen(): Generator[Array[_CmdOnReplica]] =>
    Generators.seq_of[_CmdOnReplica, Array[_CmdOnReplica]](
      Generators.map2[USize, _CCounterCmd, _CmdOnReplica](
        Generators.usize(),
        Generators.u64().flat_map[_CCounterCmd](
          {(u) =>
            try
              Generators.one_of[_CCounterCmd]([
                 _CCounterCmd(u, _INC)
                 _CCounterCmd(u, _DEC)
              ])?
            else
              // shouldn't happen
              Generators.repeatedly[_CCounterCmd]({()(u) => _CCounterCmd(u, _INC) })
            end
          }),
        {(replica, cmd) => _CmdOnReplica(replica, cmd) })
    )

