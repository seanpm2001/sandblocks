# Sandblocks
A block-based editor for Squeak/Smalltalk.

> This is a research prototype. Hiccups during usage are very much expected. Save often.

![The sandblocks editor](https://raw.githubusercontent.com/tom95/sandblocks/master/screenshots/sandblocks.png)

### Installing
Make sure you're running on a Squeak-trunk image. Then run:
```smalltalk
Metacello new
  baseline: 'Sandblocks';
  repository: 'github://tom95/Sandblocks:master/packages';
  load: #tutorial.

SBEditor openExample.

" extend the default browser with a block display mode: "
CodeHolder addSandblocks.
```

### Publications
To cite this work, please use the [workshop paper presented at PX'20](https://doi.org/10.1145/3397537.3397560).

#### 2020
* Tom Beckmann, Stefan Ramson, Patrick Rein, and Robert Hirschfeld. 2020. Visual design for a tree-oriented projectional editor. In Conference Companion of the 4th International Conference on Art, Science, and Engineering of Programming (‹Programming› '20). Association for Computing Machinery, New York, NY, USA, 113–119. [![doi][px20_doi]][px20_paper] [![Preprint][preprint]][px20_pdf]
* Tom Beckmann. 2020. Efficient editing in a tree-oriented projectional editor. In Conference Companion of the 4th International Conference on Art, Science, and Engineering of Programming (‹Programming› '20). Association for Computing Machinery, New York, NY, USA, 215–216. [![doi][px20_doi]][px20_paper]

[preprint]: https://img.shields.io/badge/preprint-download-blue.svg
[px20_doi]: https://img.shields.io/badge/doi-10.1145/3397537.3397560-blue.svg
[px20_pdf]: https://www.hpi.uni-potsdam.de/hirschfeld/publications/media/BeckmannRamsonReinHirschfeld_2020_VisualDesignForATreeOrientedProjectionalEditor_AcmDL.pdf
[px20_paper]: https://doi.org/10.1145/3397537.3397560
[px20_src_doi]: https://img.shields.io/badge/doi-10.1145/3397537.3398477-blue.svg
[px20_src_paper]: https://doi.org/10.1145/3397537.3398477
