# References

The methods this package implements, and the work it follows. Each entry says
where in the package it is used.

**Missing-data mechanisms**

- Rubin, D. B. (1976). Inference and missing data. *Biometrika*, 63(3),
  581–592. <https://doi.org/10.1093/biomet/63.3.581> — the MCAR / MAR / MNAR
  distinction the diagnostics are read against.
- Little, R. J. A., & Rubin, D. B. (2019). *Statistical Analysis with Missing
  Data* (3rd ed.). Wiley. <https://doi.org/10.1002/9781119482260> — the
  standard reference for the field, including listwise deletion
  (`missingrows`, `missingdrop`) and maximum-likelihood estimation under
  missing data.

**Little's MCAR test** (`missingmcar`)

- Little, R. J. A. (1988). A test of missing completely at random for
  multivariate data with missing values. *Journal of the American Statistical
  Association*, 83(404), 1198–1202.
  <https://doi.org/10.1080/01621459.1988.10478722> — the test statistic and its
  χ² reference distribution.
- Dempster, A. P., Laird, N. M., & Rubin, D. B. (1977). Maximum likelihood from
  incomplete data via the EM algorithm. *Journal of the Royal Statistical
  Society: Series B*, 39(1), 1–22.
  <https://doi.org/10.1111/j.2517-6161.1977.tb01600.x> — the EM estimates of
  the mean and covariance the test compares against.
- Anderson, T. W. (1957). Maximum likelihood estimates for a multivariate
  normal distribution when some observations are missing. *Journal of the
  American Statistical Association*, 52(278), 200–203.
  <https://doi.org/10.1080/01621459.1957.10501379> — the closed-form estimates
  for a monotone pattern, which the test suite checks EM against.
- Press, W. H., Teukolsky, S. A., Vetterling, W. T., & Flannery, B. P. (2007).
  *Numerical Recipes: The Art of Scientific Computing* (3rd ed.), §6.2.
  Cambridge University Press. — the series and continued-fraction evaluation of
  the incomplete gamma function behind the p-value.

**Patterns and co-occurrence** (`missingpatterns`, `missingcooccurrence`, `order=:cluster`)

- van Buuren, S., & Groothuis-Oudshoorn, K. (2011). mice: Multivariate
  imputation by chained equations in R. *Journal of Statistical Software*,
  45(3). <https://doi.org/10.18637/jss.v045.i03> — `md.pattern()`, the
  pattern table `missingpatterns` reproduces.
- Lex, A., Gehlenborg, N., Strobelt, H., Vuillemot, R., & Pfister, H. (2014).
  UpSet: Visualization of intersecting sets. *IEEE Transactions on
  Visualization and Computer Graphics*, 20(12), 1983–1992.
  <https://doi.org/10.1109/TVCG.2014.2346248> — the frequency bars beside each
  pattern.
- Yule, G. U. (1912). On the methods of measuring association between two
  attributes. *Journal of the Royal Statistical Society*, 75(6), 579–652.
  <https://doi.org/10.2307/2340126> — the ϕ coefficient of two binary
  attributes, here the missingness masks.
- Jaccard, P. (1912). The distribution of the flora in the alpine zone. *New
  Phytologist*, 11(2), 37–50.
  <https://doi.org/10.1111/j.1469-8137.1912.tb05611.x> — the Jaccard index of
  the missing-row sets.
- Hahsler, M., Hornik, K., & Buchta, C. (2008). Getting things in order: An
  introduction to the R package seriation. *Journal of Statistical Software*,
  25(3). <https://doi.org/10.18637/jss.v025.i03> — seriation, of which
  `order=:cluster` is a greedy nearest-neighbour instance.

**Related software**

- Tierney, N., & Cook, D. (2023). Expanding tidy data principles to facilitate
  missing data exploration, visualization and assessment of imputations.
  *Journal of Statistical Software*, 105(7).
  <https://doi.org/10.18637/jss.v105.i07> — `naniar`, the R package for the
  same exploration, including a Little's test (`mcar_test`).
