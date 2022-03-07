defmodule LcSeg.LexicalChainsTest do
  use ExUnit.Case

  alias LcSeg.LexicalChains
  alias LcSeg.LexicalChains.Chain
  alias LcSeg.LexicalChains.DocumentChains

  import Test.LcSeg.Factory

  setup context do
    term = context[:preexisting_chain_for_term]

    if term do
      chain = build(:chain, %{term: term})

      document_chains =
        build(:document_chains, %{
          current_chain_ids: [chain.id],
          catalog: %{chain.id => chain}
        })

      [chain: chain, document_chains: document_chains]
    else
      [document_chains: build(:document_chains)]
    end
  end

  describe "update_hiatuses/2" do
    test "will increment the hiatus count for any chains in current chains that do not occur in the term frequencies map",
         %{
           document_chains: dc
         } do
      assert {:ok, %Chain{hiatus: 0}, dc} = LexicalChains.find_or_create_chain(dc, "banana")
      assert {:ok, %Chain{hiatus: 0}, dc} = LexicalChains.find_or_create_chain(dc, "mango")
      assert {:ok, %Chain{hiatus: 0}, dc} = LexicalChains.find_or_create_chain(dc, "apple")

      term_frequencies = %{
        "banana" => 1,
        "mango" => 2
      }

      updated_dc = LexicalChains.update_hiatuses(dc, term_frequencies)

      assert {:ok, %Chain{hiatus: 0}, _dc} =
               LexicalChains.find_or_create_chain(updated_dc, "banana")

      assert {:ok, %Chain{hiatus: 0}, _dc} =
               LexicalChains.find_or_create_chain(updated_dc, "mango")

      assert {:ok, %Chain{hiatus: 1}, _dc} =
               LexicalChains.find_or_create_chain(updated_dc, "apple")
    end
  end

  describe "find_or_create_chain/2" do
    test "will create a new chain if it does not exist for the given term", %{
      document_chains: dc
    } do
      assert {:ok, chain, _dc} = LexicalChains.find_or_create_chain(dc, "banana")

      assert chain.id
      assert %Chain{term: "banana", length: 0, term_freq: 0, score: nil} = chain
    end

    test "adds newly create chain's id to current chain ids", %{
      document_chains: dc
    } do
      assert [] = dc.current_chain_ids

      assert {:ok, chain, %DocumentChains{current_chain_ids: chain_ids}} =
               LexicalChains.find_or_create_chain(dc, "banana")

      assert chain.id in chain_ids
    end

    @tag preexisting_chain_for_term: "banana"
    test "will return an existing chain if it exists", %{
      document_chains: dc,
      chain: existing_chain
    } do
      assert {:ok, chain, _dc} = LexicalChains.find_or_create_chain(dc, "banana")
      assert ^chain = existing_chain
    end
  end

  describe "increment_chain/3" do
    @tag preexisting_chain_for_term: "banana"
    test "it increments the length of the chain by 1 and its term frequencies by passed in amount",
         %{document_chains: dc, chain: chain} do
      assert %{term_freq: 0, length: 0} = chain
      assert {:ok, chain, dc} = LexicalChains.increment_chain(dc, chain, 3)

      assert %{term_freq: 3, length: 1} = chain
      assert %{term_freq: 3, length: 1} = dc.catalog[chain.id]
    end

    @tag preexisting_chain_for_term: "banana"
    test "it sets hiatus to zero",
         %{document_chains: dc, chain: chain} do
      assert false
    end

    test "if chain does not exist, returns error", %{document_chains: dc} do
      chain = build(:chain, %{term: "pineapple"})
      assert {:error, :chain_not_found} = LexicalChains.increment_chain(dc, chain, 3)
    end
  end

  describe "terminate_and_score_chain/2" do
    @tag preexisting_chain_for_term: "mango"
    test "removes chain from current chain ids and calculates chain score", %{
      document_chains: dc,
      chain: chain
    } do
      assert chain.id in dc.current_chain_ids

      {:ok, chain, dc} = LexicalChains.increment_chain(dc, chain, 2)
      assert {:ok, chain, dc} = LexicalChains.terminate_and_score_chain(dc, chain)
      assert chain.score > 0
      refute chain.id in dc.current_chain_ids
    end

    test "if chain does not exist, returns error", %{document_chains: dc} do
      chain = build(:chain, %{term: "pineapple"})
      assert {:error, :chain_not_found} = LexicalChains.terminate_and_score_chain(dc, chain)
    end
  end
end
