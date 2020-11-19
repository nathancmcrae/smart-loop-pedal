Given two impulse sequences $x_i$, $y_i$ ($\forall i, x_i < x_{i + 1}$, same for $y$), what is the minimum shift $\Delta t$ such that for some $j$, $x_j = y_j + \Delta t$, i.e. we get impulses to overlap?

For $i$, what is the minimum shift $\Delta t$, such that $\exists j, x_j = y_i + \Delta t$? 

It's easier if we know that $x_i = y_i$, we just find the smallest $x_j - x_{j-1}$.

So to do this with $x_i$ we:

- Create $d_j = x_j - x_{j-1}$ (dealing with ranges reasonably), and $n_j = j + 1$.
- for $d_k = \underset{j}{min}(d_j)$, 
  - $d_k := x_{n_k + 1} - x_{n_k}$
  - $n_k := n_k + 1$
  - $\forall l \ne k, d_l := d_l - d_k$
    - if $d_l = 0$, then $n_l := n_l + 1$
  - Now $d_j$ is how much *more* of a shift of $x_j $ would cause overlap with another impulse and $n_j$ corresponds to *which* impulse.
  - Repeat to find the next impulse overlap.



- [x] It would be smart to have a cold-start version of this algorithm, and then an update version for successive checks.

