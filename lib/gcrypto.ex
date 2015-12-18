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


  def check_keys(config, uids \\ nil) do
    if Cfg.convert_value(config["general"]["encrypt-attachments"]) == true do
      # make sure we have gpg keys for all recipients
      if !uids do
        uids = GCrypto.get_valid_uids()
      end
      recipients = Dict.keys(config["recipients"])
      missing_keys = Set.difference(Enum.into(recipients, HashSet.new),
                                    Enum.into(uids, HashSet.new))
      if Set.size(missing_keys) > 0 do
        error = "No gpg keys for:\n" <> Enum.reduce(Enum.map(missing_keys, fn x -> "  #{x}\n" end), "", fn a, b -> a <> b end)
        {:error, error}
      else
        {:ok, "all set!"}
      end
    else
      {:ok, "attachments not crypted"}
    end
  end
end
