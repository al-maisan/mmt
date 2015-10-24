defmodule GCrypto do
  @moduledoc """
  key / crypto functions
  """

  def get_valid_uids() do
    {uids, ec} = System.cmd("gpg", ["--charset", "utf-8", "--display-charset", "utf-8", "--batch", "--no-tty", "--status-fd", "2", "--with-colons", "--list-public-keys", "--fixed-list-mode"], [into: [], stderr_to_stdout: true])
    case ec do
      0 -> {:ok, filter_uids(uids)}
      _ -> {:error, {uids, ec}}
    end
  end


  def filter_uids(uids) do
    uids
    |> Enum.join
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


  def encrypt(path, recipient) do
    {out, ec} = System.cmd("gpg", ["--batch", "--no-tty", "--status-fd", "2", "-r", recipient, "-e", path], [into: [], stderr_to_stdout: true])
    case ec do
      0 -> {:ok, path <> ".gpg"}
      _ -> {:error, {out, ec}}
    end
  end
end
