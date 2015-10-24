defmodule Cfg do
  @moduledoc """
  Config file functionality
  """


  @doc """
  Read the configuration file and return a Map where the keys are the email
  addresses and the values are the full names.
  """
  def read_config(config) do
    { :ok, rx } = Regex.compile(~S"\[(\w+)\]([^[]*)", "ums")
    content = Regex.scan(rx, config, [capture: :all_but_first])

    general = case (for [k, v] <- content, k == "general", do: v) do
      [] -> %{}
      [gdata] -> read_single_config_section("general", gdata)
    end

    [recipients] = for [k, v] <- content, k == "recipients", do: v
    recipients = read_single_config_section("recipients", recipients)

    %{"general" => general, "recipients" => recipients}
  end


  def read_single_config_section(section, content) do
    String.split(content, "\n")
    |> Enum.map(fn(x) -> Regex.replace(~R/\s*#.*$/, x, "") end)
    |> Enum.filter(&String.contains?(&1, "="))
    |> Enum.map(
      fn line ->
        [key, value] = String.split(line, ~r{\s*=\s*})
        case section do
          "recipients" ->
            [id, key] = String.split(key, ~r{\s*;\s*}, parts: 2, trim: true)
            value = String.split(value, ~r{\s+}, parts: 2, trim: true)
            {key, {id, value}}
          _ -> {String.strip(key), convert_value(String.strip(value))}
        end
      end)
    |> Enum.into(Map.new)
  end


  @doc """
  Converts booleans, integers and floats to their proper values; returns other
  strings unmodified
  """
  def convert_value(string) do
    case Regex.run(~r/^\s*(true|false|\d+|\d+\.\d+)\s*$/, string) do
      nil -> string
      [_, "false"] -> false
      [_, "true"] -> true
      [_, num] ->
        case String.contains?(num, ".") do
          true ->
            case Float.parse(num) do
              :error -> :error
              {float, _} -> float
            end
          false ->
            case Integer.parse(num) do
              :error -> :error
              {int, _} -> int
            end
        end
    end
  end


  @doc """
  Returns :ok for correct config files and {:error, [messages]} for broken
  config files.
  """
  def check_config(config) do
    { :ok, rx } = Regex.compile(~S"\[(\w+)\]([^[]*)", "ums")
    content = Regex.scan(rx, config, [capture: :all_but_first])
    sections = for [k, _v] <- content, do: k
    errors = []

    {_, counts} = Enum.map_reduce(
      sections, HashDict.new,
      fn(x, acc) -> {x, Dict.put(acc, x, Dict.get(acc, x, 0) + 1)} end)

    # Check for missing sections
    missing = (for k <- ["recipients"], counts[k] == nil, do: k)
      |> Enum.sort
    if Enum.count(missing) > 0 do
      error = "missing sections: '" <> Enum.join(missing, ", ") <> "'"
      errors = [error | errors]
    end

    # Check for repeating sections
    repeating = Enum.filter(counts, fn({_k, v}) -> v > 1 end)
    if Enum.count(repeating) > 0 do
      repeating = (for {k, _v} <- repeating, do: k) |> Enum.sort
      error = "repeating sections: '" <> Enum.join(repeating, ", ") <> "'"
      errors = [error | errors]
    end

    if Enum.count(errors) > 0 do
      {:error, errors |> Enum.sort}
    else
      :ok
    end
  end
end
