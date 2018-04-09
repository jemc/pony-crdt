
use "ponycheck"
use ".."
use "collections"

class GCounterIncProperty is Property1[(USize, Array[_CmdOnReplica[U64]])]
  """
  verify that a set of CCounter replicas that are only incremented
  behave like a single U64 counter once completely converged.
  """

  fun name(): String => "crdt.prop.GCounter"

  fun gen(): Generator[(USize, Array[_CmdOnReplica[U64]])] =>
    """
    generate a random sequence of increment commands on random replicas
    """
    let num_replica_gen = Generators.usize(2, 10)
    let replica_cmd_gen = num_replica_gen.flat_map[Array[_CmdOnReplica[U64]]](
      {(num_replicas) =>
        Generators.seq_of[_CmdOnReplica[U64], Array[_CmdOnReplica[U64]]](
          Generators.map2[USize, U64, _CmdOnReplica[U64]](
            Generators.usize(0, num_replicas-1),
            Generators.u64(),
            {(replica, inc) =>
              _CmdOnReplica[U64](replica, inc) }
          )
        )
      })
    Generators.zip2[USize, Array[_CmdOnReplica[U64]]](num_replica_gen, replica_cmd_gen)

  fun property(sample: (USize, Array[_CmdOnReplica[U64]]), h: PropertyHelper) =>
    """
    validate that an array of commands against random replicas
    converges to the same value as a U64 counter exposed to the same commands.
    """
    (let num_replicas, let commands) = sample
    let replicas: Array[GCounter] = replicas.create(num_replicas)
    for x in Range[U64](0, num_replicas.u64()) do
      replicas.push(GCounter(x))
    end

    var expected: U64 = 0
    let deltas = Array[GCounter](commands.size())

    for command in commands.values() do
      let inc = command.cmd
      h.log("executing +" + inc.string(), true)

      try
        deltas.push(
          replicas(command.replica(num_replicas))?.increment(inc))
      else
        h.fail("error happened")
      end
      expected = expected + inc

      let observer = GCounter(U64.max_value())
      for replica in replicas.values() do
        observer.converge(replica)
      end
      if not h.assert_eq[U64](observer.value(), expected) then return end
    end


    h.log(deltas.size().string() + " deltas collected")
    let delta_observer = GCounter(U64.max_value() - 1)
    for delta in deltas.values() do
      delta_observer.converge(delta)
    end
    h.assert_eq[U64](expected, delta_observer.value())

