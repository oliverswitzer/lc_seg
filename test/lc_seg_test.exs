defmodule LcSegTest do
  use ExUnit.Case
  doctest LcSeg

  import Euclid.Assertions
  import Test.LcSeg.Factory

  alias LcSeg
  alias LcSeg.DocumentCleaner

  describe "lexical_chains/1" do
    test "finds and scores all lexical chains in the given transcript" do
      transcript =
        [
          "Hi President Johnson. How are those bananas?",
          "The bananas are great! As President I enjoy them.",
          "Great Mr. President",
          "Johnson?"
        ]
        |> to_transcript_lines()

      johnson_chain = %{term: DocumentCleaner.clean("Johnson"), length: 1}
      second_johnson_chain = %{term: DocumentCleaner.clean("Johnson"), length: 1}
      banana_chain = %{term: DocumentCleaner.clean("banana"), length: 2}
      president_chain = %{term: DocumentCleaner.clean("President"), length: 3}
      enjoy_chain = %{term: DocumentCleaner.clean("enjoy"), length: 1}

      assert chains = LcSeg.lexical_chains(transcript)

      {first_line, first_chains} = Enum.at(chains, 0)
      assert %{text: "Hi President Johnson. How are those bananas?"} = first_line

      assert_eq(
        [johnson_chain, president_chain, banana_chain],
        term_and_length(first_chains),
        ignore_order: true
      )

      {second_line, second_chains} = Enum.at(chains, 1)
      assert %{text: "The bananas are great! As President I enjoy them."} = second_line

      assert_eq(
        [johnson_chain, banana_chain, president_chain, enjoy_chain],
        term_and_length(second_chains),
        ignore_order: true
      )

      {third_line, third_chains} = Enum.at(chains, 2)
      assert %{text: "Great Mr. President"} = third_line

      # Johnson chain disappears in third line because it has not been seen for 1 transcript line, which is the default config specified by allowed_hiatus
      assert_eq(
        [president_chain, enjoy_chain, banana_chain],
        term_and_length(third_chains),
        ignore_order: true
      )

      {fourth_line, fourth_chains} = Enum.at(chains, 3)
      assert %{text: "Johnson?"} = fourth_line

      # Johnson chain reappears in fourth line with only a length of 1, since this is a new chain for Johnson.
      assert_eq(
        [second_johnson_chain, president_chain],
        term_and_length(fourth_chains),
        ignore_order: true
      )

      # All chains should have a score
      assert [] =
               chains
               |> Enum.filter(fn {_tr_line, tr_chains} ->
                 Enum.any?(tr_chains, &is_nil(&1.score))
               end)
    end

    defp term_and_length(chains) do
      chains
      |> Enum.map(&%{term: &1.term, length: &1.length})
    end
  end

  defp to_transcript_lines(raw_transcripts) do
    raw_transcripts
    |> Enum.map(&build(:transcript_line, %{text: &1}))
  end
end
