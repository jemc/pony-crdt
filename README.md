# pony-crdt

Delta-State Convergent Replicated Data Types (ẟ-CRDTs) for the Pony language.

CRDTs are a special class of data types that can be replicated in a highly-available, partition-tolerant distributed system to yield results that are eventually consistent. That is, with enough message passing, replicas will eventually converge to the same result, even faced with arbitrary partitions.

In order to acheive commutativity and idempotence, these data structures all impose certain constraints that are often more limiting than typical localized data structures, but if you can model all the state in your application in terms of CRDTs, then you can get eventually consistent replication "for free". In practice, this kind of consideration is often a critical step to scaling a highly-available stateful service.

Delta-State CRDTs are special CRDTs that can produce delta-states as a by-product of each mutable operation, where the delta-state may be shipped and converged between peers instead of shipping and converging the entire state, and the convergence of the delta-states retains the same guarantees of eventual consistency. This approach has the benefit of reducing the size of the state that must be transported between peers, making CRDTs more practical for real-world applications.

This package provides CRDTs which may be freely converged using either the full-state or delta-state approach, based on the needs of the application. Every mutable operation returns the corresponding delta-state, and at any time the full-state may be fetched from the data type. So, the application may use the full-state replication approach by ignoring the delta-state return values, or may replicate the delta-state return values in lieu of fetching and replicating the full-state.

This implementation of ẟ-CRDTs is inspired and informed by the following prior work:
* [This 2016 academic paper](https://arxiv.org/abs/1603.01529) (***Delta State Replicated Data Types*** – *Almeida et al. 2016*).
* [This informal summary of the paper](https://blog.acolyer.org/2016/04/25/delta-state-replicated-data-types/).
* [This C++ reference implementation of the paper](https://blog.acolyer.org/2016/04/25/delta-state-replicated-data-types/).
