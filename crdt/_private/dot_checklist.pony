class DotChecklist
  """
  This small class is used to integrate non-causal CRDTs with CKeyspace,
  where they expect to be used within a shared DotContext.
  
  The DotChecklist gives them a way to contribute to that causal history
  in a minimal way, where every write operation the CRDT results in a
  call to the `write` method of the checklist, which inserts a dot into history.
  
  Once integrated thus, the DotContext in a CKeyspace for a non-causal CRDT can
  be used to detect when there are local changes to any value, just like it
  already can do when used with causal CRDT values. This in turn allows for
  efficient anti-entropy mechanisms operating over the keyspace.
  """
  let _ctx: DotContext
  new ref create(ctx': DotContext) => _ctx = ctx'
  fun ref write() => _ctx.next_dot()
