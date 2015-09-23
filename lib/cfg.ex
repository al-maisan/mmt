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
    [sender] = for [k, v] <- content, k == "sender", do: v
    [recipients] = for [k, v] <- content, k == "recipients", do: v
    sender = read_single_config_section("sender", sender)
    recipients = read_single_config_section("recipients", recipients)
    %{"sender" => sender, "recipients" => recipients}
  end


  def read_single_config_section(section, content) do
    String.split(content, "\n")
    |> Enum.map(fn(x) -> Regex.replace(~R/\s*#.*$/, x, "") end)
    |> Enum.filter(&String.contains?(&1, "="))
    |> Enum.map(
      fn line ->
        [key, value] = String.split(line, "=")
        key = String.strip(key)
        value = case section do
          "recipients" -> String.split(value, ~r{\s}, parts: 2, trim: true)
          _ -> String.strip(value)
        end
        {key, value}
      end)
    |> Enum.into(Map.new)
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
    missing = (for k <- ["sender", "recipients"], counts[k] == nil, do: k)
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

    # Check for single sender value
    if not "sender" in repeating && not "sender" in missing do
      [sender_value] = for [k, v] <- content, k == "sender", do: v
      senders = String.split(sender_value, "\n")
      |> Enum.map(fn(x) -> Regex.replace(~R/\s*#.*$/, x, "") end)
      |> Enum.filter(&String.contains?(&1, "="))
      |> Enum.count
      if senders != 1 do
        errors = ["the sender section requires exactly one entry" | errors]
      end
    end

    if Enum.count(errors) > 0 do
      {:error, errors |> Enum.sort}
    else
      :ok
    end
  end
end
