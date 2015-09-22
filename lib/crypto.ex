defmodule Crypto do
  @moduledoc """
  key / crypto functions
  """

  def get_valid_uids() do
    :os.cmd('gpg --batch --no-tty --status-fd 2 --with-colons --list-public-keys --fixed-list-mode')
    |> to_string
    |> filter_uids
  end


  def filter_uids(uids) do
    uids
    |> String.split("\n")
    |> Enum.filter(fn x -> Regex.match?(~r/^uid:[-oqmfuws]:/, x) end)
    |> Enum.filter(fn x -> Regex.match?(~r/>:$/, x) end)
    |> Enum.map(fn x -> Regex.replace(~r/^.+<([^>]+)>:$/, x, "\\1") end)
    |> Enum.into(HashSet.new)
    |> Set.to_list
    |> Enum.sort
  end
end
