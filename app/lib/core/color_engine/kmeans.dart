import 'dart:math' as math;
import 'dart:typed_data';

/// Home-grown K-means for the on-device port of the color core (D15, #32).
///
/// There is no sklearn in Dart, so we reimplement the classic Lloyd algorithm
/// with k-means++ initialization, specialized to 3 dimensions (RGB). It is
/// deterministic: the RNG is seeded with [kKmeansSeed], so the same photo
/// always produces the same palette (reproducible demo, same spirit as the
/// `random_state=42` of palette.py).
///
/// CAREFUL about Python parity: Dart's random SEQUENCE is not numpy's, so the
/// clusters match sklearn's by CONVERGENCE (same optima on separated clouds,
/// verified by tolerance in the parity tests against golden fixtures), not
/// bit for bit.

/// Fixed RNG seed (mirror of palette.py's `random_state=42`).
const int kKmeansSeed = 42;

/// Restarts with different initializations, keeping the one with the lowest
/// inertia (mirror of palette.py's `n_init=4`): avoids bad local optima
/// without paying for sklearn's default 10 restarts.
const int kKmeansNInit = 4;

/// Cap on Lloyd iterations per restart (sklearn default: 300).
const int kKmeansMaxIter = 300;

/// Stopping criterion: stops when the total squared displacement of the
/// centers falls below `tol * mean variance of the data` (same RELATIVE
/// criterion sklearn uses, default 1e-4).
const double kKmeansTol = 1e-4;

/// Result of one K-means run over RGB pixels.
class KmeansResult {
  /// Creates a K-means result from its [centers], [labels] and [inertia].
  const KmeansResult(this.centers, this.labels, this.inertia);

  /// Flattened centers [k*3] (r, g, b per cluster), in creation order.
  final Float64List centers;

  /// Cluster assigned to each pixel [n].
  final Int32List labels;

  /// Sum of squared distances of each pixel to its center (lower = better).
  final double inertia;
}

/// K-means over flattened RGB pixels `[r0,g0,b0, r1,g1,b1, ...]`.
///
/// Runs [nInit] restarts (k-means++ + Lloyd) and returns the one with the
/// lowest inertia. `k` must be >= 1 and <= number of pixels.
KmeansResult kmeans(
  Float64List pixels,
  int k, {
  int nInit = kKmeansNInit,
  int seed = kKmeansSeed,
}) {
  final int n = pixels.length ~/ 3;
  assert(pixels.length == n * 3, 'pixels must be flattened [n*3]');
  assert(k >= 1 && k <= n, 'k=$k out of range for $n pixels');

  // A single seeded RNG shared by the restarts: deterministic global
  // sequence (as sklearn does with its random_state).
  final math.Random rng = math.Random(seed);
  final double absoluteTol = kKmeansTol * _meanVariance(pixels, n);

  KmeansResult? best;
  for (int restart = 0; restart < nInit; restart++) {
    final KmeansResult result = _singleRun(pixels, n, k, rng, absoluteTol);
    if (best == null || result.inertia < best.inertia) {
      best = result;
    }
  }
  return best!;
}

/// Mean variance per component (sklearn's relative tolerance criterion).
double _meanVariance(Float64List pixels, int n) {
  final List<double> mean = <double>[0, 0, 0];
  for (int i = 0; i < n; i++) {
    for (int d = 0; d < 3; d++) {
      mean[d] += pixels[i * 3 + d];
    }
  }
  for (int d = 0; d < 3; d++) {
    mean[d] /= n;
  }
  double variance = 0;
  for (int i = 0; i < n; i++) {
    for (int d = 0; d < 3; d++) {
      final double delta = pixels[i * 3 + d] - mean[d];
      variance += delta * delta;
    }
  }
  return variance / (3 * n);
}

double _dist2(Float64List pixels, int i, Float64List centers, int c) {
  final double dr = pixels[i * 3] - centers[c * 3];
  final double dg = pixels[i * 3 + 1] - centers[c * 3 + 1];
  final double db = pixels[i * 3 + 2] - centers[c * 3 + 2];
  return dr * dr + dg * dg + db * db;
}

/// k-means++ initialization: the first center at random and the next ones
/// with probability proportional to the squared distance to the closest
/// already-chosen center. That way minority-but-distant colors (the outfit's
/// "pop") almost always get their own center, which is exactly what the LAB
/// merge needs.
Float64List _initKmeansPlusPlus(
    Float64List pixels, int n, int k, math.Random rng) {
  final Float64List centers = Float64List(k * 3);
  final int first = rng.nextInt(n);
  for (int d = 0; d < 3; d++) {
    centers[d] = pixels[first * 3 + d];
  }

  // d2[i] = squared distance from pixel i to the closest chosen center.
  final Float64List d2 = Float64List(n);
  for (int i = 0; i < n; i++) {
    d2[i] = _dist2(pixels, i, centers, 0);
  }

  for (int c = 1; c < k; c++) {
    double total = 0;
    for (int i = 0; i < n; i++) {
      total += d2[i];
    }
    int chosen;
    if (total <= 0) {
      // Every pixel coincides with some center: any choice works.
      chosen = rng.nextInt(n);
    } else {
      final double r = rng.nextDouble() * total;
      double cumulative = 0;
      chosen = n - 1; // in case rounding leaves r above the total
      for (int i = 0; i < n; i++) {
        cumulative += d2[i];
        if (cumulative >= r) {
          chosen = i;
          break;
        }
      }
    }
    for (int d = 0; d < 3; d++) {
      centers[c * 3 + d] = pixels[chosen * 3 + d];
    }
    for (int i = 0; i < n; i++) {
      final double next = _dist2(pixels, i, centers, c);
      if (next < d2[i]) {
        d2[i] = next;
      }
    }
  }
  return centers;
}

/// Assigns each pixel to its closest center. Returns the inertia.
double _assign(
    Float64List pixels, int n, Float64List centers, int k, Int32List labels) {
  double inertia = 0;
  for (int i = 0; i < n; i++) {
    double bestDist = double.infinity;
    int bestCluster = 0;
    for (int c = 0; c < k; c++) {
      final double dist = _dist2(pixels, i, centers, c);
      if (dist < bestDist) {
        bestDist = dist;
        bestCluster = c;
      }
    }
    labels[i] = bestCluster;
    inertia += bestDist;
  }
  return inertia;
}

/// Recomputes centers as the mean of their pixels. An empty cluster is
/// relocated to the pixel farthest from its assigned center (sklearn's
/// strategy) so no cluster out of the k requested is lost.
Float64List _recomputeCenters(Float64List pixels, int n, int k,
    Int32List labels, Float64List previousCenters) {
  final Float64List next = Float64List(k * 3);
  final Int32List counts = Int32List(k);
  for (int i = 0; i < n; i++) {
    final int c = labels[i];
    counts[c]++;
    for (int d = 0; d < 3; d++) {
      next[c * 3 + d] += pixels[i * 3 + d];
    }
  }

  final List<int> empty = <int>[];
  for (int c = 0; c < k; c++) {
    if (counts[c] == 0) {
      empty.add(c);
    } else {
      for (int d = 0; d < 3; d++) {
        next[c * 3 + d] /= counts[c];
      }
    }
  }

  if (empty.isNotEmpty) {
    // Pixels farthest from their current center → new centers for the empty
    // clusters.
    final List<int> indices = List<int>.generate(n, (int i) => i);
    indices.sort((int a, int b) => _dist2(pixels, b, previousCenters, labels[b])
        .compareTo(_dist2(pixels, a, previousCenters, labels[a])));
    for (int v = 0; v < empty.length && v < n; v++) {
      final int pixel = indices[v];
      for (int d = 0; d < 3; d++) {
        next[empty[v] * 3 + d] = pixels[pixel * 3 + d];
      }
    }
  }
  return next;
}

KmeansResult _singleRun(
    Float64List pixels, int n, int k, math.Random rng, double absoluteTol) {
  Float64List centers = _initKmeansPlusPlus(pixels, n, k, rng);
  final Int32List labels = Int32List(n);

  for (int iter = 0; iter < kKmeansMaxIter; iter++) {
    _assign(pixels, n, centers, k, labels);
    final Float64List next = _recomputeCenters(pixels, n, k, labels, centers);
    double displacement = 0;
    for (int j = 0; j < k * 3; j++) {
      final double delta = next[j] - centers[j];
      displacement += delta * delta;
    }
    centers = next;
    if (displacement <= absoluteTol) {
      break;
    }
  }

  // Final assignment against the definitive centers (like fit_predict).
  final double inertia = _assign(pixels, n, centers, k, labels);
  return KmeansResult(centers, labels, inertia);
}
