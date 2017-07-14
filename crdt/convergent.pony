trait Convergent[A: Convergent[A] #read]
  fun ref converge(that: box->A)
