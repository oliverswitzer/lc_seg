defmodule Measures do
  @spec local_minima_and_maxima([float()]) :: %{minima: [number()], maxima: [number()]}
  def local_minima_and_maxima(input) do
    input
    |> Enum.with_index()
    |> Enum.reduce(%{minima: [], maxima: []}, fn {num, i}, acc ->
      next = Enum.at(input, i + 1, nil)
      # For some reason when you pass a third agument to Enum.at/3 to specify 
      # what to return when index is out of bounds, it still returns the element 
      # at the negative index (ie toward the end of the array), rather than the 
      # default you specified.
      prev = if i - 1 >= 0, do: Enum.at(input, i - 1), else: nil

      case min_or_max(prev, num, next) do
        :min -> Map.put(acc, :minima, acc.minima ++ [i])
        :max -> Map.put(acc, :maxima, acc.maxima ++ [i])
        _ -> acc
      end
    end)
  end

  defp min_or_max(prev, num, next) when is_nil(prev) and num > next, do: :max
  defp min_or_max(prev, num, next) when is_nil(prev) and num < next, do: :min

  defp min_or_max(prev, num, next) when is_nil(next) and num > prev, do: :max
  defp min_or_max(prev, num, next) when is_nil(next) and num < prev, do: :min

  defp min_or_max(prev, num, next) when num > prev and num > next, do: :max
  defp min_or_max(prev, num, next) when num < prev and num < next, do: :min
  defp min_or_max(_prev, _num, _next), do: nil
end
