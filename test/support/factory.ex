defmodule Test.LcSeg.Factory do
  def build(:transcript_line) do
    %LcSeg.TranscriptLine{text: "Hi there", start: 0.10, end: 0.20}
  end

  def build(factory_name, attributes) do
    factory_name |> build() |> struct!(attributes)
  end
end
