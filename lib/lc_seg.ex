defmodule LcSeg do
  @moduledoc """
  Documentation for `LcSeg`.
  """

  defmodule LexicalChain do
    @enforce_keys [:term, :length]
    defstruct [:term, :length]
  end

  @type lexical_chains_option :: {:allowed_hiatus, number()}
  @spec lexical_chains([TranscriptLine.t()], [lexical_chains_option()]) ::
          [%{TranscriptLine.t() => [LexicalChain.t()]}]
  def lexical_chains(transcript_lines, opts) do
    allowed_hiatus = Keyword.get(opts, :allowed_hiatus, 1)

    # all_chains =
    #   %{
    #       chain_id => %{term: "president", length: 2}
    #   }
    # repeated_terms = repeated_terms(transcript_lines)

    transcript_lines
    |> Enum.map(fn %{text: text} = tr ->
      Map.put(tr, :text, clean_document(text))
    end)
    |> Enum.reduce({[], [], %{}}, fn
      tr, {output, current_chains, all_chains} ->
        # See if there are any new terms for which a chain should exist
        #
        # terms = tr.text |> String.split(" ")
        # terms
        # |> Enum.each(fn term ->
        #   if repeated_terms[term] do
        #     create_a_local_chain(term)
        #   end
        # end)

        current_chains
        |> Enum.each(fn %{id: id} ->
          chain = chains[id]

          cond do
            String.contains?(tr.text, chain.term) ->
              # Increment length of chain
              "bar"

            chain.current_hiatus > allowed_hiatus ->
              # Remove chain from current chains
              # 
              "foo"

            true ->
              nil
          end
        end)

        tr.text
    end)
    # [
    #   tr => ["123abc", "456def"]
    # ]
    |> IO.inspect()

    []
  end

  def remove_stopwords(text) do
    String.split(text, " ")
    |> Enum.filter(fn w -> String.trim(w) == "president" || String.trim(w) == "today" end)
    |> Enum.join(" ")
  end

  @spec repeated_terms([TranscriptLine.t()]) :: %{String.t() => number()}
  def repeated_terms(transcript_lines) do
    transcript_lines
    |> Enum.map_join(" ", fn tr -> clean_document(tr.text) end)
    |> String.split(" ")
    |> Enum.frequencies()
  end

  defp clean_document(text) do
    # Steal from Standuops (remove grammer, port stem, etc)
  end
end
