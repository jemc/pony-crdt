use "ponycheck"
use ".."
use "collections"
use "itertools"
use "time"

primitive _INC
primitive _DEC
type _CCounterOp is (_DEC|_INC)

class val _CCounterCmd is Stringable
  let u_cmd: {(U64): U64 } val
  let cc_cmd: {(CCounter)} val
  let diff: U64
  let op: _CCounterOp

  new val create(diff': U64, op': _CCounterOp = _INC) =>
    diff = diff'
    op = op'
    cc_cmd = {(cc) =>
      if op is _INC then cc.increment(diff) else cc.decrement(diff) end } val
    u_cmd = {(t) =>
      if op is _INC then t + diff else t - diff end } val

  fun string(): String iso^ =>
    recover
      String()
        .>append(if op is _INC then "+" else "-" end + diff.string())
    end

class CCounterIncProperty is Property1[Array[_CCounterCmd]]

  fun name(): String => "crdt.prop.CCounter.Inc"

  fun gen(): Generator[Array[_CCounterCmd]] =>
    Generators.seq_of[_CCounterCmd, Array[_CCounterCmd]](
      Generators.u64(0, 100).flat_map[_CCounterCmd]({(u) =>
        Generators.unit[_CCounterCmd](_CCounterCmd(u, _INC))
      })
    )

  fun property(commands: Array[_CCounterCmd], h: PropertyHelper) ? =>
    var expected: U64 = 0
    let num_replicas = (commands.size() % 10).max(2)
    let replicas: Array[CCounter] = replicas.create(num_replicas)
    for x in Range(0, num_replicas) do
      replicas.push(CCounter(0))
    end
    let replica_iter = Iter[CCounter](replicas.values()).cycle()

    for command in commands.values() do
      h.log("executing " +  command.string(), true)

      command.cc_cmd(replica_iter.next()?)
      expected = command.u_cmd(expected)

      let observer = CCounter(0)
      for replica in replicas.values() do
        observer.converge(replica)
      end
      if not h.assert_eq[U64](observer.value(), expected) then return end
    end

class CCounterProperty is Property1[Array[_CCounterCmd]]

  fun name(): String => "crdt.prop.CCounter"

  fun gen(): Generator[Array[_CCounterCmd]] =>
    Generators.seq_of[_CCounterCmd, Array[_CCounterCmd]](
      Generators.u64(0, 10).flat_map[_CCounterCmd](
        {(u: U64): Generator[_CCounterCmd] =>
          try
            Generators.one_of[_CCounterCmd]([
               _CCounterCmd(u, _INC)
               _CCounterCmd(u, _DEC)
            ])?
          else
            // shouldn't happen
            Generators.repeatedly[_CCounterCmd]({()(u) =>
              _CCounterCmd(u, _INC)
            })
          end
        })
    )

  fun property(commands: Array[_CCounterCmd], h: PropertyHelper) ? =>

    var expected: U64 = 0
    let num_replicas = (commands.size() % 10).max(2)
    let replicas: Array[CCounter] = replicas.create(num_replicas)
    for x in Range(0, num_replicas) do
      replicas.push(CCounter(0))
    end
    let replica_iter = Iter[CCounter](replicas.values()).cycle()

    for command in commands.values() do
      h.log("executing " +  command.string(), true)

      command.cc_cmd(replica_iter.next()?)
      expected = command.u_cmd(expected)

      let observer = CCounter(0)
      for replica in replicas.values() do
        observer.converge(replica)
      end
      if not h.assert_eq[U64](observer.value(), expected) then return end
    end

