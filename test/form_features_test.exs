defmodule FormFeaturesTest do
  use ExUnit.Case

  import Test.LcSeg.Factory

  describe "silences/1" do
    test "returns a list of silence durations" do
      transcript = [
        build(:transcript_line, %{start: 1.0, end: 2.2}),
        build(:transcript_line, %{start: 3.0, end: 4.5})
      ]

      silences = FormFeatures.silences(transcript)

      assert [
               %{start: 0.0, duration: 1.0},
               %{start: 2.2, duration: 0.8}
             ] = silences
    end

    test "when there are overlapping transcripts, still returns proper silences" do
      transcript = [
        build(:transcript_line, %{start: 1.0, end: 2.2}),
        build(:transcript_line, %{start: 1.3, end: 4.5}),
        build(:transcript_line, %{start: 2.2, end: 4.1}),
        build(:transcript_line, %{start: 5.5, end: 6.5}),
        build(:transcript_line, %{start: 6.9, end: 7.5})
      ]

      silences = FormFeatures.silences(transcript)

      assert [
               %{start: 0.0, duration: 1.0},
               %{start: 4.5, duration: 1.0},
               %{start: 6.5, duration: 0.4}
             ] = silences
    end

    test "when gaps in talking are preceeded by a question, do not create a silence span " do
      transcript = [
        build(:transcript_line, %{text: "Hello?", start: 1.0, end: 2.2}),
        build(:transcript_line, %{text: "Hi!", start: 4.5, end: 7.5}),
        build(:transcript_line, %{text: "How are you?", start: 8.0, end: 9.2})
      ]

      silences = FormFeatures.silences(transcript)

      assert [
               %{start: 0.0, duration: 1.0},
               %{start: 7.5, duration: 0.5}
             ] = silences
    end
  end

  describe "combine_overlaps/1" do
    test "combines overlapping speaker segments" do
      transcript = [
        build(:transcript_line, %{start: 1.0, end: 2.2}),
        build(:transcript_line, %{start: 1.3, end: 4.5}),
        build(:transcript_line, %{start: 2.2, end: 4.1}),
        build(:transcript_line, %{start: 5.5, end: 6.5})
      ]

      overlaps = FormFeatures.combine_overlaps(transcript)

      assert [
               %{start: 1.0, combined_lines: _, end: 4.5},
               %{start: 5.5, combined_lines: _, end: 6.5}
             ] = overlaps
    end
  end
end
