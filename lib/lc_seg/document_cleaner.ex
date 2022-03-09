defmodule LcSeg.DocumentCleaner do
  @doc """
  Removes stop-words, punctiation and return characters from the given string
  """
  @spec clean(document :: String.t()) :: String.t()
  def clean(document) do
    document
    |> remove_return_chars()
    |> remove_stopwords()
    |> remove_punctuation()
    |> stem()
    |> String.trim()
  end

  def remove_return_chars(document) do
    String.replace(document, "\n\n", " ")
  end

  def remove_stopwords(document) do
    escaped_regex =
      stopwords()
      |> Enum.map(fn sw -> String.replace(sw, ".", "\.") end)

    regex = ~r/(?:^|\s+)(?:#{Enum.join(escaped_regex, "|")})(?=\s+|,|\.|\?|\!|$)/i

    String.replace(document, regex, "")
  end

  defp stopwords do
    File.read!("stopwords.txt")
    |> String.split(" ")
  end

  defp stem(document) do
    String.split(document, " ")
    |> Enum.map(&LcSeg.PorterStemmer.stem/1)
    |> Enum.join(" ")
  end

  defp remove_punctuation(document) do
    document
    |> String.replace(~r([^\w\s]), "")
  end
end
