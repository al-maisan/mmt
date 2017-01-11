defmodule Attmt do
  @moduledoc """
  Functionality revolving around attachments

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
  Check whether we are supposed to handle attachments in first place.
  Return `true` or `false`.
  """
  def attachments_present?(config) do
    atmts = config["attachments"]
    case atmts do
      nil -> false
      _ -> true
    end
  end


  @doc """
  Make sure the configuration relating to attachments is correct.
  Return a tuple of `{:ok, "all set!"}`, or `{:error, error_msg}`
  """
  def check_config(config) do
    if attachments_present?(config) == true do
      atp = config["general"]["attachment-path"]
      allow_datts = config["general"]["allow-duplicate-attachments"]
      case atp do
        nil -> {:error, "check config: no attachment path defined"}
        _ ->
          atmts = config["attachments"]
          # check for attachment definition clashes first
          case atmts do
            nil -> {:error, "No attachments defined at all"}
            _ ->
              atdefs = Map.values(atmts)
              counts = Enum.map(Enum.uniq(atdefs), fn x -> {x, 0} end)
                |> Enum.into(Map.new)
              dups = Enum.reduce(
                atdefs, counts, fn(m, cs) -> %{cs | m => cs[m]+1} end)
                |> Enum.filter(fn {_, v} -> v > 1 end)
                |> Keyword.keys
                |> Enum.sort
              if Enum.empty?(dups) or allow_datts do
                if Map.keys(atmts) === Map.keys(config["recipients"]) do
                  {:ok, "all set!"}
                else
                  ats = Enum.into(Map.keys(atmts), MapSet.new)
                  rps = Enum.into(Map.keys(config["recipients"]), MapSet.new)
                  if Enum.count(ats) < Enum.count(rps) do
                    missing = Enum.join(Enum.sort(MapSet.difference(rps, ats)), ", ")
                    {:error, "No attachments defined for: #{missing}"}
                  else
                    missing = Enum.join(Enum.sort(MapSet.difference(ats, rps)), ", ")
                    {:error, "Unlisted recipients: #{missing}"}
                  end
                end
              else
                dups = Enum.join(dups, ", ")
                {:error, "Attachment(s) (#{dups}) used for more than one email"}
              end
          end
      end
    else
      {:ok, "all set!"}
    end
  end


  @doc """
  Make sure all required attachment files exist and we can read them.
  Return a tuple of `{:ok, "all set!"}`, or `{:error, error_msg}`
  """
  def check_files(config) do
    atp = config["general"]["attachment-path"]
    case atp do
      nil -> {:error, "check files: no attachment path defined"}
      _ ->
        case dir_readable?(atp) do
          false ->
            errmsg = "Missing or unreadable attachment path: #{atp}"
            {:error, errmsg}
          true ->
            case config["attachments"] do
              nil -> {:ok, "all set!"}
              afs ->
                missing = Enum.filter(Map.values(afs), fn af ->
                  afp = atp <> "/" <> af
                  not file_readable?(afp) end)
                if Enum.empty?(missing) do
                  {:ok, "all set!"}
                else
                  errmsg = "Missing or unreadable attachment(s) in the #{atp} directory:"
                  emas = Enum.map(missing, fn mf -> "    #{mf}" end)
                  {:error, Enum.join(List.flatten([[errmsg], emas]), "\n")}
                end
            end
        end
    end
  end


  def dir_readable?(path) do
    case File.stat(path) do
      {:error, _} -> false
      {:ok, sd} -> (sd.type === :directory) and ((sd.access === :read) or (sd.access === :read_write))
    end
  end


  def file_readable?(path) do
    case File.stat(path) do
      {:error, _} -> false
      {:ok, sd} -> (sd.type === :regular) and ((sd.access === :read) or (sd.access === :read_write))
    end
  end


  @doc """
  If we are to send out attachments, make sure they are all there and we can
  read them. Also, if they are to be crypted make sure we have all the keys
  and encrypt the attachments.
  Return a tuple of `{:ok, "all set!"}`, or `{:error, error_msg}`
  """
  def prepare_attachments(config) do
    atmts_present = attachments_present?(config)
    do_encrypt = Cfg.convert_value(config["general"]["encrypt-attachments"])

    if atmts_present do
      {failed, error} = if do_encrypt == true do
        case GCrypto.check_keys(config) do
          {:ok, _} -> {nil, nil}
          errordata -> {true, errordata}
        end
      end
      {failed, error} = if not failed do
        case check_config(config) do
          {:ok, _} -> {nil, nil}
          errordata -> {true, errordata}
        end
      end
      {failed, error} = if not failed do
        case check_files(config) do
          {:ok, _} -> {nil, nil}
          errordata -> {true, errordata}
        end
      end
      {failed, error} = if (not failed) and do_encrypt do
        case encrypt_attachments(config) do
          {:ok, _} -> {nil, nil}
          errordata -> {true, errordata}
        end
      end
      if not failed do
        {:ok, "all set!"}
      else
        error
      end
    else
      {:ok, "all set!"}
    end
  end


  @doc """
  Encrypt the attachment files. Assume the config data is OK and all
  attachments are in place and readable.
  Every attachment is encrypted using a separate Erlang process.
  Return a tuple of `{:ok, "all set!"}`, or `{:error, error_msg}`
  """
  def encrypt_attachments(config, gpgargs \\ [], efunc \\ &GCrypto.encrypt/3) do
    me = self()
    atp = config["general"]["attachment-path"]
    errors = Enum.map(config["attachments"], fn {eaddr, atf} ->
        spawn_link fn ->
          case efunc.(atp <> "/" <> atf, eaddr, gpgargs) do
            {:ok, _} -> send me, nil
            {:error, {errordata, _}} -> send me, Enum.join(errordata, "")
          end
        end
      end)
    |> Enum.map(fn(_) -> receive do result -> result end end)
    |> Enum.filter(fn x -> x != nil end)
    if Enum.count(errors) == 0 do
      {:ok, "all set!"}
    else
      {:error, Enum.join(Enum.sort(errors), "\n")}
    end
  end
end
