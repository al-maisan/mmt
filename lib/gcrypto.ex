defmodule GCrypto do
  @moduledoc """
  key / crypto functions

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

  def get_valid_uids(homedir \\ "test/keyring") do
    {uids, ec} = System.cmd("gpg2", ["--homedir", homedir, "--no-permission-warning", "--charset", "utf-8", "--display-charset", "utf-8", "--batch", "--no-tty", "--status-fd", "2", "--with-colons", "--list-public-keys", "--fixed-list-mode"], [into: [], stderr_to_stdout: true])
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
    |> Enum.filter(fn x -> Regex.match?(~r/<[^>]+@[^>]+>:*$/, x) end)
    # extract the email addresses
    |> Enum.map(fn x -> Regex.replace(~r/^.+<([^>]+)>:*$/, x, "\\1") end)
    # make unique
    |> Enum.into(MapSet.new)
    |> MapSet.to_list
    # .. and sort
    |> Enum.sort
  end


  def encrypt(path, recipient, args \\ []) do
    defaultargs = ["--batch", "--no-tty", "--status-fd", "2", "-r", recipient, "-e", path]
    {out, ec} = System.cmd("gpg2", List.flatten([args, defaultargs]), [into: [], stderr_to_stdout: true])
    case ec do
      0 -> {:ok, path <> ".gpg"}
      _ -> {:error, {out, ec}}
    end
  end


  def check_keys(config, uids \\ nil) do
    # make sure we have gpg keys for all recipients
    uids = case uids do
      nil ->
        {:ok, uids} = GCrypto.get_valid_uids(System.get_env("HOME"))
        uids
      _ -> uids
    end
    recipients = Map.keys(config["recipients"])
    missing_keys = MapSet.difference(Enum.into(recipients, MapSet.new),
                                     Enum.into(uids, MapSet.new))
      |> MapSet.to_list
      |> Enum.sort
      |> Enum.reverse
      |> Enum.map(fn x -> "  #{x}\n" end)

    if Enum.count(missing_keys) > 0 do
      error = "No gpg keys for:\n" <> Enum.reduce(missing_keys, "", fn a, b -> a <> b end)
      {:error, error}
    else
      {:ok, "all set!"}
    end
  end
end
