defmodule Cfg do
  @moduledoc """
  Config file functionality

  mmt is a simple utility that allows the automated sending of emails
  using a configuration file and a template for the email body. It was
  written in Elixir and used mainly on linux systems like Arch Linux
  and Ubuntu.
  Copyright (C) 2015-2016  Muharem Hrnjadovic <muharem@linux.com>

  This program is free software; you can redistribute it and/or modify
  it under the terms of the GNU General Public License as published by
  the Free Software Foundation; either version 2 of the License, or
  (at your option) any later version.

  This program is distributed in the hope that it will be useful,
  but WITHOUT ANY WARRANTY; without even the implied warranty of
  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
  GNU General Public License for more details.

  You should have received a copy of the GNU General Public License along
  with this program; if not, write to the Free Software Foundation, Inc.,
  51 Franklin Street, Fifth Floor, Boston, MA 02110-1301 USA.
  """


  @doc """
  Read the configuration file and return a map where the keys are the ini
  file section names and the values are maps with configuration key/value
  pairs.
  """
  def read_config(config) do
    { :ok, rx } = Regex.compile(~S"\[(\w+)\]([^[]*)", "ums")

    Regex.scan(rx, config, [capture: :all_but_first])
    |> Enum.map(fn([k, v]) -> {k, read_single_config_section(v)} end)
    |> Enum.into(Map.new)
  end


  def read_single_config_section(content) do
    String.split(content, "\n")
    |> Enum.map(fn(x) -> Regex.replace(~R/\s*#.*$/, x, "") end)
    |> Enum.filter(&String.contains?(&1, "="))
    |> Enum.map(
      fn line ->
        [key, value] = String.split(line, ~r{\s*=\s*})
        {String.trim(key), String.trim(value)}
      end)
    |> Enum.into(Map.new)
  end


  @doc """
  Converts booleans, integers and floats to their proper values; returns other
  strings unmodified
  """
  def convert_value(v) when is_binary(v) do
    case Regex.run(~r/^\s*(true|false|\d+|\d+\.\d+)\s*$/, v) do
      nil -> v
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

  def convert_value(v) do v end


  @doc """
  Returns :ok for correct config files and {:error, [messages]} for broken
  config files.
  """
  def check_config(config) do
    { :ok, rx } = Regex.compile(~S"\[(\w+)\]([^[]*)", "ums")
    content = Regex.scan(rx, config, [capture: :all_but_first])
    sections = for [k, _v] <- content, do: k

    {_, counts} = Enum.map_reduce(
      sections, Map.new,
      fn(x, acc) -> {x, Map.put(acc, x, Map.get(acc, x, 0) + 1)} end)

    # Check for missing sections
    missing = (for k <- ["recipients"], counts[k] == nil, do: k)
      |> Enum.sort
    errors = if Enum.count(missing) > 0 do
      ["missing sections: '" <> Enum.join(missing, ", ") <> "'"]
    else
      []
    end

    # Check for repeating sections
    repeating = Enum.filter(counts, fn({_k, v}) -> v > 1 end)
    errors = if Enum.count(repeating) > 0 do
      repeating = (for {k, _v} <- repeating, do: k) |> Enum.sort
      error = "repeating sections: '" <> Enum.join(repeating, ", ") <> "'"
      [error | errors]
    else
      errors
    end

    if Enum.count(errors) > 0 do
      {:error, errors |> Enum.sort}
    else
      :ok
    end
  end
end
