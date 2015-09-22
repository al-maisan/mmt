defmodule GCrypto do
  @moduledoc """
  key / crypto functions
  """

  @list_uids_cmd 'gpg --batch --no-tty --status-fd 2 --with-colons --list-public-keys --fixed-list-mode'

  def get_valid_uids(cmd \\ @list_uids_cmd) do
    :os.cmd(cmd)
    |> to_string
    |> filter_uids
  end


  def filter_uids(uids) do
    uids
    |> String.split("\n")
    # filter valid UIDs
    |> Enum.filter(fn x -> Regex.match?(~r/^uid:[-oqmfuws]:/, x) end)
    # filter UIDs that are based on email addresses
    |> Enum.filter(fn x -> Regex.match?(~r/<[^>]+@[^>]+>:$/, x) end)
    # extract the email addresses
    |> Enum.map(fn x -> Regex.replace(~r/^.+<([^>]+)>:$/, x, "\\1") end)
    # make unique
    |> Enum.into(HashSet.new)
    |> Set.to_list
    # .. and sort
    |> Enum.sort
  end
end
