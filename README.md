# LcSeg

An elixir-based implementation of the LcSeg (Lexical Cohesion Segmentation) algorithim
outlined in "Discourse Segmentation of Multi-Party Conversation" (Galley, 2003)

# Development

## 1. Clone large transcript files

Before cloning, ensure you have [installed Git large file storage (lfs)](https://git-lfs.github.com/):

`$ git lfs install`

This is necessary due to the size of the example transcripts within the `test/fixtures/transcripts` directory

If you have already cloned the repository, after installing git lfs, run:

`$ git lfs fetch`

`$ git lfs pull`

## 2. Run livebook

First, install Livebook. Then:

`$ cd lc_seg`

`$ livebook server`

Open `lc_seg.livemd` and run it using the Mix standalone option in livebook.
