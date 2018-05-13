interface Causal[A: Causal[A] ref] is (Convergent[A] & Replicated)
  new ref create(id: ID)
  fun ref clear[D: A ref = A](delta': D = recover D(0) end): D
