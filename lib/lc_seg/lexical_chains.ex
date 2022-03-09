defmodule LcSeg.LexicalChains do
  alias LcSeg.LexicalChains.DocumentChains
  alias LcSeg.LexicalChains.Chain

  @doc """
  Retrieves all Chains in the catalog
  """
  @spec all_chains(DocumentChains.t()) :: [Chain.t()]
  def all_chains(doc_chains) do
    doc_chains.catalog
    |> Enum.map(&elem(&1, 1))
  end

  @doc """
  Retrieves all Chain structs for current chain ids tracked in DocumentChains
  """
  @spec current_chains(DocumentChains.t()) :: [Chain.t()]
  def current_chains(%{current_chain_ids: chain_ids} = doc_chains) do
    chain_ids
    |> Enum.map(&Map.get(doc_chains.catalog, &1))
  end

  @doc """
  Increments the "hiatus" for any chain in current chains that does not occur within the passed in term_frequencies
  """
  @spec update_hiatuses(
          doc_chains :: DocumentChains.t(),
          term_frequencies :: %{String.t() => number()}
        ) ::
          DocumentChains.t()
  def update_hiatuses(doc_chains, term_frequencies) do
    doc_chains.current_chain_ids
    |> Enum.reduce(doc_chains, fn chain_id, doc_chains ->
      {:ok, chain} = get_chain(doc_chains, chain_id)

      if chain.term in Map.keys(term_frequencies) do
        # Do not update hiatus, since the term was seen
        doc_chains
      else
        update_chain_catalog(doc_chains, %Chain{chain | hiatus: chain.hiatus + 1})
      end
    end)
  end

  @doc """
  Finds an existing chain from the current chain ids tracked in the document, or creates a new one for the term if one does not exist
  """
  @spec find_or_create_chain(DocumentChains.t(), String.t()) ::
          {:ok, Chain.t(), DocumentChains.t()}
  def find_or_create_chain(doc_chains, term) do
    existing_chain =
      doc_chains.current_chain_ids
      |> Enum.map(fn chain_id -> get_chain(doc_chains, chain_id) end)
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
  Incrments the chain's frequency by `term_frequency` and length by 1. Adds 
  result to catalog. 

  Sets the given chain's hiatus back to 0, since incrementing its length assumes it was just seen.

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
        |> Map.put(:hiatus, 0)

      {:ok, updated_chain, update_chain_catalog(doc_chains, updated_chain)}
    else
      {:error, :chain_not_found}
    end
  end

  @doc """
  Removes the chain from the documents `current_chain_ids`, as well as
  computes the final score for that chain and add it to the catalog
  """
  @spec terminate_chain(DocumentChains.t(), Chain.t()) ::
          {:ok, Chain.t(), DocumentChains.t()}
  def terminate_chain(doc_chains, chain) do
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
  Returns a chain from the catalog associated to the passed in chain_id
  """
  @spec get_chain(DocumentChains.t(), String.t()) :: {:ok, Chain.t()} | {:error, :chain_not_found}
  def get_chain(doc_chains, chain_id) do
    chain = doc_chains.catalog[chain_id]

    if chain do
      {:ok, chain}
    else
      {:error, :chain_not_found}
    end
  end

  @spec score_all_chains(DocumentChains.t()) :: DocumentChains.t()
  def score_all_chains(doc_chains) do
    doc_chains.catalog
    |> Enum.reduce(doc_chains, fn {_chain_id, chain}, doc_chains ->
      scored_chain = Map.put(chain, :score, score(doc_chains, chain))
      update_chain_catalog(doc_chains, scored_chain)
    end)
  end

  defp update_chain_catalog(doc_chains, chain) do
    updated_catalog = doc_chains.catalog |> Map.put(chain.id, chain)
    Map.put(doc_chains, :catalog, updated_catalog)
  end

  defp add_to_current_chains(doc_chains, chain) do
    updated_chain_ids = doc_chains.current_chain_ids ++ [chain.id]
    Map.put(doc_chains, :current_chain_ids, updated_chain_ids)
  end

  defp score(doc_chains, %{length: chain_length} = chain) when chain_length > 0 do
    chain.term_freq * :math.log(doc_chains.document_length / chain_length)
  end

  defp score(_doc_chains, _chain) do
    0
  end
end
