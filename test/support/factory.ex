defmodule Test.LcSeg.Factory do
  alias LcSeg.LexicalChains.DocumentChains
  alias LcSeg.LexicalChains.Chain

  def build(:transcript_line) do
    %LcSeg.TranscriptLine{text: "Hi there", start: 0.10, end: 0.20}
  end

  def build(:document_chains) do
    %DocumentChains{document_length: 21}
  end

  def build(:chain) do
    %Chain{term: "orange"}
  end

  def build(factory_name, attributes) do
    factory_name |> build() |> struct!(attributes)
  end
end
