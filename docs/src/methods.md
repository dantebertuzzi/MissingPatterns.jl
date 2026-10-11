# Methods

Every number the package reports, written out. Throughout, a table has ``n``
rows and ``p`` columns, and its *missingness mask* is

```math
m_{ij} = \begin{cases} 1 & \text{if } \mathrm{isna}_j(x_{ij}) \\ 0 & \text{otherwise,} \end{cases}
```

where ``\mathrm{isna}_j`` is the predicate for column ``j`` — `ismissing` by
default, or the one given for that column through `isna`. Every count below is
a sum over ``m``. Sources are listed on the [References](@ref) page.

## Heatmap (`plotmissing`, `missinghtml`)

**Compression.** With display limits ``R`` rows and ``C`` columns, each block
spans

```math
r = \begin{cases} \lceil n/R \rceil & n > R \\ 1 & \text{otherwise} \end{cases}
\qquad
c = \begin{cases} \lceil p/C \rceil & p > C \\ 1 & \text{otherwise} \end{cases}
```

rows and columns, giving a ``\lceil n/r \rceil \times \lceil p/c \rceil`` grid.
Block ``(I, J)`` — row set ``I``, column set ``J`` — shows its missing fraction

```math
\pi_{IJ} = \frac{1}{|I|\,|J|} \sum_{i \in I} \sum_{j \in J} m_{ij},
```

and the header over column group ``J`` shows ``100 \cdot \sum_{i=1}^{n}
\sum_{j \in J} m_{ij} / (n\,|J|)``. In the compact layout each text line holds
two grid rows, so ``R`` becomes ``2(L - 5)`` for a budget of ``L`` lines.

**Glyphs.** ``\pi = 0`` and ``\pi = 1`` draw the present and missing
characters; in between, `·` for ``\pi \le 0.05``, `░` for ``\le 0.15``, `▒` for
``\le 0.30``, `▓` for ``\le 0.50`` and `█` above.

**Color.** For ``\pi > 0`` the blend weight is

```math
t(\pi) = 0.30 + 0.70\,\sqrt{\pi},
```

and the color is ``\mathbf{c} = \mathbf{a} + t\,(\mathbf{b} - \mathbf{a})``
per RGB channel — from the full color toward dark gray under
`emphasis=:present`, the reverse under `:missing`. The floor of ``0.30`` means a
single missing cell among thousands still renders visibly different from a
complete block.

**Grouping.** With `by`, rows are grouped by value ``g`` of the `by` column
instead of by position. With ``n_g`` rows in group ``g`` and groups merged into
blocks ``G`` when there are more than ``R``,

```math
\pi_{GJ} = \frac{\sum_{g \in G} \sum_{i \in g} \sum_{j \in J} m_{ij}}{|J| \sum_{g \in G} n_g},
```

so unequal group sizes weigh correctly. With `period=:week` the key is the
ISO 8601 week, and its year is the calendar year of that week's Thursday:
``\mathrm{year}(d + (4 - \mathrm{dow}(d))\ \text{days})``, with
``\mathrm{dow}`` running Monday = 1 to Sunday = 7.

## Per-column summary (`missingsummary`, `missingstats`)

Column ``j`` has ``n_j = \sum_i m_{ij}`` missing values, ``100\,n_j/n`` percent.
The sparkline splits the rows into bins of ``b = \lceil n/B \rceil`` rows; a bin
with missing fraction ``q > 0`` draws bar level ``\min(8, \max(1, \lceil 8q
\rceil))`` of `▁▂▃▄▅▆▇█`, and ``q = 0`` draws a blank.

## Patterns (`missingpatterns`, `missingpatternstats`)

Row ``i``'s pattern is its mask ``(m_{i1}, \dots, m_{ip})``, stored as the
integer ``\sum_j m_{ij}\,2^{j-1}`` (in ``\lceil p/64 \rceil`` machine words). The
table lists each distinct pattern with its count, sorted by count descending,
ties by first appearance. This is `md.pattern()` from R's `mice` (van Buuren &
Groothuis-Oudshoorn, 2011); the frequency bars follow UpSet (Lex et al., 2014).

## Co-occurrence (`missingcooccurrence`, `missingpairstats`)

For columns ``a`` and ``b`` let ``n_a = \sum_i m_{ia}``, ``n_b`` likewise, and
``n_{ab} = \sum_i m_{ia} m_{ib}`` — read off the pattern table, so the cost is
in the number of distinct patterns, not of rows. The ϕ coefficient (Yule, 1912)
of the two masks is

```math
\phi_{ab} = \frac{n_{ab}\,(n - n_a - n_b + n_{ab}) - (n_a - n_{ab})(n_b - n_{ab})}
                 {\sqrt{n_a\,(n - n_a)\,n_b\,(n - n_b)}},
```

undefined (`NaN`) when either column is entirely missing or entirely present.
The Jaccard index (Jaccard, 1912) of the missing-row sets is

```math
J_{ab} = \frac{n_{ab}}{n_a + n_b - n_{ab}},
```

undefined when neither column has a missing value.

## Column ordering (`order`)

`:missing` sorts by ``n_j`` descending; `:name` alphabetically. `:cluster` is a
greedy nearest-neighbour seriation (Hahsler et al., 2008) of the columns with
``n_j > 0``: start at ``\pi_1 = \arg\max_j n_j``, then repeatedly append

```math
\pi_k = \arg\max_{c \text{ not placed}} \bigl(\phi_{\pi_{k-1}c},\ n_c,\ -c\bigr)
```

in lexicographic order, with an undefined ϕ counted as 0. Columns with
``n_j = 0`` have no pattern and are appended last, in table order.

## Row completeness (`missingrows`, `missingrowstats`)

The histogram ``h_k = \#\{\, i : \sum_j m_{ij} = k \,\}`` for ``k = 0, \dots,
p``; ``h_0`` is what complete-case analysis (listwise deletion) keeps.

## Column-drop path (`missingdrop`, `missingdropstats`)

Working on the pattern table, with ``A`` the columns still kept and pattern
``q`` having ``\rho_q = \sum_{j \in A} m_{qj}`` kept columns missing, a step
drops

```math
c^\ast = \arg\max_{c \in A} \Bigl(\ \sum_{q:\ \rho_q = 1,\ m_{qc} = 1} \mathrm{count}_q,\ \ n_c,\ \ -c \Bigr),
```

the column that is the last missing one of the most rows. The complete-row
count after the step grows by that sum, and `cells` is complete rows ``\times
|A|``, whose maximum is the step flagged in the display.

## Before/after diff (`plotmissingdiff`)

Each block shows ``\Delta_{IJ} = \pi^{\text{after}}_{IJ} -
\pi^{\text{before}}_{IJ}``, colored by ``t(|\Delta|)`` toward the missing color
when positive and the filled color when negative. The summary counts cells
exactly, from the row-aligned masks:

```math
\text{resolved} = \sum_{ij} m^{\text{before}}_{ij}\,(1 - m^{\text{after}}_{ij}),
\qquad
\text{introduced} = \sum_{ij} (1 - m^{\text{before}}_{ij})\,m^{\text{after}}_{ij}.
```

With `on`, rows are paired by key value instead of position before the masks
are compared.

## Little's MCAR test (`missingmcar`)

Over the ``p`` selected numeric columns, rows are grouped into the missingness
patterns ``s = 1, \dots, S`` that observe at least one value. Pattern ``s`` has
``n_s`` rows, observed columns ``O_s`` (``p_s = |O_s|``) and observed mean
vector ``\bar{\mathbf{y}}_s``. Little's (1988) statistic is

```math
d^2 = \sum_{s=1}^{S} n_s\,(\bar{\mathbf{y}}_s - \hat{\boldsymbol\mu}_{O_s})^{\top}\,
      \hat{\boldsymbol\Sigma}_{O_sO_s}^{-1}\,(\bar{\mathbf{y}}_s - \hat{\boldsymbol\mu}_{O_s}),
```

asymptotically ``\chi^2`` under MCAR with ``\mathrm{df} = \sum_s p_s - p``
degrees of freedom; the p-value is ``P(\chi^2_{\mathrm{df}} > d^2)``.

**EM.** ``\hat{\boldsymbol\mu}`` and ``\hat{\boldsymbol\Sigma}`` are the
maximum-likelihood estimates under a multivariate normal model, found by EM
(Dempster et al., 1977). Each pattern is reduced to its sufficient statistics,
the sum ``\mathbf{s}_s = \sum_{i \in s} \mathbf{y}_{i,O}`` and cross-product
``\mathbf{S}_s = \sum_{i \in s} \mathbf{y}_{i,O}\mathbf{y}_{i,O}^{\top}`` of its
observed values. With ``O`` and ``M`` the observed and missing columns of a
pattern, the E-step regresses the missing values on the observed ones,

```math
\mathbf{B} = \boldsymbol\Sigma_{MO}\boldsymbol\Sigma_{OO}^{-1},\qquad
\mathbf{c} = \boldsymbol\mu_M - \mathbf{B}\boldsymbol\mu_O,\qquad
\hat{\mathbf{y}}_{i,M} = \mathbf{c} + \mathbf{B}\mathbf{y}_{i,O},
```

and accumulates ``T_1 = \sum_i \hat{\mathbf{y}}_i`` and ``T_2 = \sum_i
\bigl(\hat{\mathbf{y}}_i\hat{\mathbf{y}}_i^{\top} + \mathbf{C}_i\bigr)``, where
``\mathbf{C}_i`` is zero except for the block ``\boldsymbol\Sigma_{MM} -
\mathbf{B}\boldsymbol\Sigma_{OM}`` on the missing columns. Per pattern these are

```math
\begin{aligned}
T_{1,O} &\mathrel{+}= \mathbf{s}_s, \\
T_{1,M} &\mathrel{+}= n_s\,\mathbf{c} + \mathbf{B}\mathbf{s}_s, \\
T_{2,OO} &\mathrel{+}= \mathbf{S}_s, \\
T_{2,OM} &\mathrel{+}= \mathbf{s}_s\,\mathbf{c}^{\top} + \mathbf{S}_s\mathbf{B}^{\top}
  \quad (\text{and its transpose into } T_{2,MO}), \\
T_{2,MM} &\mathrel{+}= n_s\mathbf{c}\mathbf{c}^{\top} + \mathbf{c}(\mathbf{B}\mathbf{s}_s)^{\top}
  + (\mathbf{B}\mathbf{s}_s)\mathbf{c}^{\top} + \mathbf{B}\mathbf{S}_s\mathbf{B}^{\top}
  + n_s(\boldsymbol\Sigma_{MM} - \mathbf{B}\boldsymbol\Sigma_{OM}),
\end{aligned}
```

so an iteration costs ``O(S\,p^3)`` whatever ``n``. The M-step is
``\boldsymbol\mu \leftarrow T_1/N`` and ``\boldsymbol\Sigma \leftarrow T_2/N -
\boldsymbol\mu\boldsymbol\mu^{\top}``, ``N = \sum_s n_s``. EM starts from the
available-case means and variances (a diagonal ``\boldsymbol\Sigma``) and stops
when no parameter moves by more than ``\mathrm{tol} \cdot \max(1,
\max|\boldsymbol\mu|, \max|\boldsymbol\Sigma|)``. For a monotone pattern the
result matches the closed form of Anderson (1957), which the test suite checks.

**χ² tail.** ``P(\chi^2_\nu > x) = Q(\nu/2,\, x/2)``, the regularized upper
incomplete gamma function. Below ``x/2 < \nu/2 + 1`` it is computed as ``1 -
P``, from the series

```math
P(a, z) = \frac{e^{-z} z^{a}}{\Gamma(a)} \sum_{k=0}^{\infty} \frac{z^k}{a(a+1)\cdots(a+k)},
```

and above it from the continued fraction for ``Q`` by Lentz's method (Press et
al., 2007, §6.2). Since ``\nu`` is an integer, ``\log\Gamma(\nu/2)`` is exact:
``\log (k-1)!`` for ``\nu = 2k``, and ``\tfrac12\log\pi + \sum_{j=1}^{k}
\log(j - \tfrac12)`` for ``\nu = 2k + 1``.

## Predictors of missingness (`missingpredictors`)

For a target column ``t``, rows split into group 1 (``m_{it} = 1``) and group 2
(``m_{it} = 0``). Each other column is compared between the two groups, using
only the rows where that column is itself observed.

**Numeric and date columns.** With group sizes ``n_g``, means ``\bar{x}_g`` and
sample variances ``s_g^2`` (dates as days, or milliseconds for date-times),
Welch's (1947) statistic and degrees of freedom are

```math
t = \frac{\bar{x}_1 - \bar{x}_2}{\sqrt{s_1^2/n_1 + s_2^2/n_2}},
\qquad
\nu = \frac{\bigl(s_1^2/n_1 + s_2^2/n_2\bigr)^2}
           {\dfrac{(s_1^2/n_1)^2}{n_1 - 1} + \dfrac{(s_2^2/n_2)^2}{n_2 - 1}},
```

with the two-sided p-value

```math
P(|T_\nu| > |t|) = I_{\nu/(\nu + t^2)}\!\left(\tfrac{\nu}{2}, \tfrac12\right),
```

``I_x(a, b)`` the regularized incomplete beta function, evaluated by its
continued fraction (Press et al., 2007, §6.4) with ``\log\Gamma`` from the
Lanczos (1964) approximation. The effect is the standardized mean difference
(Cohen, 1988)

```math
d = \frac{\bar{x}_1 - \bar{x}_2}{\sqrt{(s_1^2 + s_2^2)/2}}.
```

**Other columns.** The values form ``k`` levels (absence in the predictor is a
level of its own; beyond `max_levels`, the rarest are pooled). With
``O_{g\ell}`` the count of level ``\ell`` in group ``g``, ``N_g`` the group
totals, ``n_\ell`` the level totals and ``N`` the grand total, Pearson's (1900)
statistic is

```math
\chi^2 = \sum_{g=1}^{2} \sum_{\ell=1}^{k} \frac{(O_{g\ell} - E_{g\ell})^2}{E_{g\ell}},
\qquad E_{g\ell} = \frac{n_\ell N_g}{N},
```

with ``k - 1`` degrees of freedom, and the effect is Cramér's (1946) ``V =
\sqrt{\chi^2 / (N(\min(2, k) - 1))} = \sqrt{\chi^2/N}``. The level reported in
`detail` maximizes ``O_{1\ell}/N_1 - O_{2\ell}/N_2``.

## Sentinel detection (`missingsentinels`)

These rules are this package's heuristic, not a published test. Text is
proposed when ``\mathrm{lowercase}(\mathrm{strip}(x))`` is in the token list. A
numeric code ``c`` seen at least `min_count` times is proposed when, with
``x_{\max}`` and ``x_{\min}`` the extremes of the values that are not candidate
codes and ``g = 2`` if those are all integers (``g = 1`` otherwise),

```math
c > 0 \ \text{and}\ c - x_{\max} \ge g
\qquad\text{or}\qquad
c < 0 \ \text{and}\ x_{\min} - c \ge g,
```

or, failing that, when its count stands out from its integer neighbours:

```math
\frac{\#\{x = c\}}{\max\Bigl(1,\ \tfrac{1}{|K|}\sum_{k \in K} \#\{x = c + k\}\Bigr)} \ge \texttt{spike},
\qquad K = \{\pm1, \dots, \pm5\} \setminus \{\text{codes}\}.
```

A text column is judged numerically when at least 90% of its values that are
not absent-looking text parse as numbers.
