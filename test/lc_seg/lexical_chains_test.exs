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

  describe "all_chains/1" do
    @tag preexisting_chain_for_term: "banana"
    test "retreives all chains tracked across the document", %{document_chains: dc} do
      {:ok, _chain, dc} = LexicalChains.find_or_create_chain(dc, "another")
      chains = LexicalChains.all_chains(dc)
      assert length(chains) == 2

      assert [%{term: "banana"}, %{term: "another"}] =
               chains
               |> Enum.map(&%{term: &1.term})
    end
  end

  describe "current_chains/1" do
    @tag preexisting_chain_for_term: "banana"
    test "returns all chains in current_chain_ids on document chains", %{
      document_chains: dc,
      chain: chain
    } do
      chains = LexicalChains.current_chains(dc)
      assert length(chains) == 1
      assert [^chain] = chains
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
    test "will create a new chain if there is no chain in current chains for the given term", %{
      document_chains: dc
    } do
      assert {:ok, chain, _dc} = LexicalChains.find_or_create_chain(dc, "banana")

      assert chain.id
      assert %Chain{term: "banana", length: 0, term_freq: 0, score: nil} = chain
    end

    @tag preexisting_chain_for_term: "banana"
    test "will return an existing chain if it exists", %{
      document_chains: dc,
      chain: existing_chain
    } do
      assert {:ok, chain, _dc} = LexicalChains.find_or_create_chain(dc, "banana")
      assert ^chain = existing_chain
    end

    @tag preexisting_chain_for_term: "banana"
    test "if there is already a chain for the term in the catalog, but there is not a current chain for the term, creates a new chain",
         %{document_chains: dc} do
      dc = Map.put(dc, :current_chain_ids, [])

      assert [%{term: "banana", id: id1}] = LexicalChains.all_chains(dc)

      {:ok, _chain, dc} = LexicalChains.find_or_create_chain(dc, "banana")

      assert [%{term: "banana", id: ^id1}, %{term: "banana", id: id2}] =
               LexicalChains.all_chains(dc)

      assert id1 != id2
    end

    test "adds newly create chain's id to current chain ids", %{
      document_chains: dc
    } do
      assert [] = dc.current_chain_ids

      assert {:ok, chain, %DocumentChains{current_chain_ids: chain_ids}} =
               LexicalChains.find_or_create_chain(dc, "banana")

      assert chain.id in chain_ids
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
    test "it sets hiatus of the chain to zero",
         %{document_chains: dc, chain: chain} do
      dc = LexicalChains.update_hiatuses(dc, %{})

      banana_chain = LexicalChains.current_chains(dc) |> List.first()
      assert banana_chain.hiatus == 1

      assert {:ok, banana_chain, dc} = LexicalChains.increment_chain(dc, chain, 3)
      assert %{hiatus: 0} = banana_chain
      assert %{hiatus: 0} = dc.catalog[banana_chain.id]
    end

    test "if chain does not exist, returns error", %{document_chains: dc} do
      chain = build(:chain, %{term: "pineapple"})
      assert {:error, :chain_not_found} = LexicalChains.increment_chain(dc, chain, 3)
    end
  end

  describe "terminate_chain/2" do
    @tag preexisting_chain_for_term: "mango"
    test "removes chain from current chain ids", %{
      document_chains: dc,
      chain: chain
    } do
      assert chain.id in dc.current_chain_ids

      {:ok, chain, dc} = LexicalChains.increment_chain(dc, chain, 2)
      assert {:ok, chain, dc} = LexicalChains.terminate_chain(dc, chain)

      refute chain.id in dc.current_chain_ids
    end

    test "if chain does not exist, returns error", %{document_chains: dc} do
      chain = build(:chain, %{term: "pineapple"})
      assert {:error, :chain_not_found} = LexicalChains.terminate_chain(dc, chain)
    end
  end

  describe "score_all_chains/1" do
    @tag preexisting_chain_for_term: "banana"
    test "should compute the score for all chains that have length greater than zero and term frequency",
         %{
           document_chains: dc,
           chain: chain
         } do
      {:ok, chain2, dc} = LexicalChains.find_or_create_chain(dc, "pineapple")

      {:ok, chain, dc} = LexicalChains.increment_chain(dc, chain, 3)
      {:ok, chain2, dc} = LexicalChains.increment_chain(dc, chain2, 2)

      {:ok, chain} = LexicalChains.get_chain(dc, chain.id)
      assert is_nil(chain.score)
      {:ok, chain2} = LexicalChains.get_chain(dc, chain2.id)
      assert is_nil(chain.score)

      dc = LexicalChains.score_all_chains(dc)

      {:ok, chain} = LexicalChains.get_chain(dc, chain.id)
      refute is_nil(chain.score)
      assert chain.score > 0
      {:ok, chain2} = LexicalChains.get_chain(dc, chain2.id)
      refute is_nil(chain2.score)
      assert chain2.score > 0
    end
  end

  @tag preexisting_chain_for_term: "banana"
  test "any chain with length 0 will get assigned a score of zero", %{
    document_chains: dc,
    chain: chain
  } do
    dc = LexicalChains.score_all_chains(dc)
    {:ok, chain} = LexicalChains.get_chain(dc, chain.id)
    assert chain.score == 0
  end
end
