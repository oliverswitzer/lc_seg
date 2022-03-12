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
  Increments the "hiatus" for any chain in current chains that does not occur within the passed in terms 
  """
  @spec update_hiatuses(
          doc_chains :: DocumentChains.t(),
          terms :: [String.t()]
        ) ::
          DocumentChains.t()
  def update_hiatuses(doc_chains, terms) do
    doc_chains.current_chain_ids
    |> Enum.reduce(doc_chains, fn chain_id, doc_chains ->
      {:ok, chain} = get_chain(doc_chains, chain_id)

      if chain.term in terms do
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
  Incrments the chain's length by 1. Adds result to catalog. 

  Sets the given chain's hiatus back to 0, since incrementing its length assumes it was just seen.
  """
  @spec increment_chain(DocumentChains.t(), Chain.t()) ::
          {:ok, Chain.t(), DocumentChains.t()}
  def increment_chain(doc_chains, chain) do
    if doc_chains.catalog[chain.id] do
      updated_chain =
        chain
        |> Map.put(:length, chain.length + 1)
        |> Map.put(:hiatus, 0)

      {:ok, updated_chain, update_chain_catalog(doc_chains, updated_chain)}
    else
      {:error, :chain_not_found}
    end
  end

  @doc """
  Removes the chain from the documents `current_chain_ids`
  """
  @spec terminate_chain(DocumentChains.t(), Chain.t()) ::
          {:ok, Chain.t(), DocumentChains.t()}
  def terminate_chain(doc_chains, chain) do
    if doc_chains.catalog[chain.id] do
      updated_doc_chains =
        doc_chains
        |> Map.put(:current_chain_ids, List.delete(doc_chains.current_chain_ids, chain.id))

      {:ok, chain, updated_doc_chains}
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

  @type term_frequency :: number()
  @spec score_chain(DocumentChains.t(), Chain.t(), term_frequency()) :: Chain.t()
  def score_chain(doc_chains, %{length: chain_length} = chain, term_frequency)
      when chain_length > 0 and not is_nil(term_frequency) do
    score = term_frequency * :math.log(doc_chains.document_length / chain_length)
    Map.put(chain, :score, score)
  end

  def score_chain(_doc_chains, chain, _term_frequency) do
    Map.put(chain, :score, 0)
  end

  defp update_chain_catalog(doc_chains, chain) do
    updated_catalog = doc_chains.catalog |> Map.put(chain.id, chain)
    Map.put(doc_chains, :catalog, updated_catalog)
  end

  defp add_to_current_chains(doc_chains, chain) do
    updated_chain_ids = doc_chains.current_chain_ids ++ [chain.id]
    Map.put(doc_chains, :current_chain_ids, updated_chain_ids)
  end
end
