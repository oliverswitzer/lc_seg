defmodule LcSeg.LexicalChains do
  alias LcSeg.LexicalChains.DocumentChains
  alias LcSeg.LexicalChains.Chain

  @spec update_hiatuses(
          doc_chains :: DocumentChains.t(),
          term_frequencies :: %{String.t() => number()}
        ) ::
          DocumentChains.t()
  def update_hiatuses(doc_chains, term_frequencies) do
    doc_chains.current_chain_ids
    |> Enum.reduce(doc_chains, fn chain_id, doc_chains ->
      chain = get_chain(doc_chains, chain_id)

      if chain.term in Map.keys(term_frequencies) do
        doc_chains
      else
        update_chain_catalog(doc_chains, %Chain{chain | hiatus: chain.hiatus + 1})
      end
    end)
  end

  @doc """
  Finds an existing chain the catalog by the term that is passed, or creates a
  new one and adds it to the catalog. Adds chain to the documents `current_chain_ids`
  """
  @spec find_or_create_chain(DocumentChains.t(), String.t()) ::
          {:ok, LexicalChains.Chain.t(), DocumentChains.t()}
  def find_or_create_chain(doc_chains, term) do
    existing_chain =
      doc_chains.catalog
      |> Enum.find(&match?(%{term: ^term}, elem(&1, 1)))

    chain =
      if existing_chain,
        do: {:existing, elem(existing_chain, 1)},
        else: {:new, %Chain{term: term, id: UUID.uuid1()}}

    doc_chains =
      case chain do
        {:existing, _chain} ->
          doc_chains

        {:new, chain} ->
          doc_chains
          |> add_to_current_chains(chain)
          |> update_chain_catalog(chain)
      end

    {:ok, elem(chain, 1), doc_chains}
  end

  @doc """
  Removes the chain from the documents `current_chain_ids`, as well as
  computes the final score for that chain and add it to the catalog
  """
  @spec terminate_and_score_chain(DocumentChains.t(), Chain.t()) ::
          {:ok, Chain.t(), DocumentChains.t()}
  def terminate_and_score_chain(doc_chains, chain) do
    if doc_chains.catalog[chain.id] do
      updated_chain = Map.put(chain, :score, score(doc_chains, chain))

      updated_doc_chains =
        doc_chains
        |> update_chain_catalog(updated_chain)
        |> Map.put(:current_chain_ids, List.delete(doc_chains.current_chain_ids, chain.id))

      {:ok, updated_chain, updated_doc_chains}
    else
      {:error, :chain_not_found}
    end
  end

  @doc """
  Increments the chain's frequency by `term_frequency` and length by 1. Adds 
  result to catalog. 

  NOTE: Does not remove this chain from the `current_chain_ids`, since it assumes
  you are still building this chain given that you are incrementing it
  """
  @spec increment_chain(DocumentChains.t(), Chain.t(), number()) ::
          {:ok, Chain.t(), DocumentChains.t()}
  def increment_chain(doc_chains, chain, term_frequency) do
    if doc_chains.catalog[chain.id] do
      updated_chain =
        chain
        |> Map.put(:length, chain.length + 1)
        |> Map.put(:term_freq, chain.term_freq + term_frequency)

      {:ok, updated_chain, update_chain_catalog(doc_chains, updated_chain)}
    else
      {:error, :chain_not_found}
    end
  end

  defp update_chain_catalog(doc_chains, chain) do
    updated_catalog = doc_chains.catalog |> Map.put(chain.id, chain)
    Map.put(doc_chains, :catalog, updated_catalog)
  end

  defp add_to_current_chains(doc_chains, chain) do
    updated_chain_ids = doc_chains.current_chain_ids ++ [chain.id]
    Map.put(doc_chains, :current_chain_ids, updated_chain_ids)
  end

  defp get_chain(doc_chains, chain_id) do
    doc_chains.catalog[chain_id]
  end

  defp score(doc_chains, chain) do
    chain.term_freq * :math.log(doc_chains.document_length / chain.length)
  end
end
