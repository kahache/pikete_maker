# Attribution — bundled sample photos

Almost every image in this repository is the author's own (synthetic test
images in `samples/test_outfit*.png` and `samples/product-synth/`, own
photos elsewhere). The exceptions are the Creative Commons / Unsplash test
photos below, sourced via the [Fashionpedia](https://fashionpedia.github.io/home/)
dataset metadata (which records each image's original Flickr/Unsplash source
and license).

| File | Source | License |
|---|---|---|
| `samples/g0/g0-01-multicolor.jpg` | [Flickr](http://farm8.staticflickr.com/7084/7183563021_055c3fc5a4_n.jpg) | [CC BY 2.0](https://creativecommons.org/licenses/by/2.0/) |
| `samples/g0/g0-02-total-black.jpg` | [Flickr](http://farm6.staticflickr.com/5655/19919527953_6df4f95bcb_n.jpg) | [CC BY-SA 2.0](https://creativecommons.org/licenses/by-sa/2.0/) |
| `samples/g0/g0-05-medio-cuerpo-piel-oscura.jpg` | [Unsplash](https://unsplash.com) | [Unsplash License](https://unsplash.com/license) |
| `samples/g0/g0-07-rayas.jpg` | [Flickr](http://farm4.staticflickr.com/3820/13251521873_6e68330a39_n.jpg) | [CC BY 2.0](https://creativecommons.org/licenses/by/2.0/) |
| `samples/g0/g0-08-print-piel-oscura.jpg` | [Flickr](http://farm2.staticflickr.com/1712/25546184953_4313963e7b_n.jpg) | [CC BY-SA 2.0](https://creativecommons.org/licenses/by-sa/2.0/) |

## README screenshot

| File | Source | License |
|---|---|---|
| `docs/screenshots/04.png` (left half, and the photo inside the app screen on the right) | Photo by [Vika Glitter](https://www.pexels.com/@vika-glitter-392079/) on Pexels — ["Model in Tied Orange Blouse and Yellow Shorts"](https://www.pexels.com/photo/model-in-tied-orange-blouse-and-yellow-shorts-17091660/), photo ID 17091660 | [Pexels License](https://www.pexels.com/license/) (free use, attribution not required; credited anyway) |

The stock photo itself is not stored in this repository; only the
screenshot composite is. The recolored shorts on the right are produced by the
app on-device.

Notes:

- The Flickr URLs above are the thumbnail URLs recorded in the Fashionpedia
  metadata; each photo's author is recoverable from its Flickr photo ID.
- The CC BY-SA photos are included unmodified for algorithm testing; the
  share-alike condition applies to those photos, not to this repository's
  code.
- The MediaPipe segmentation model attribution lives in [`NOTICE`](NOTICE).
- No evaluation-dataset photos (Fashionpedia raw batches, labeled sets,
  personal photos used for gate measurements) are distributed in this
  repository.
