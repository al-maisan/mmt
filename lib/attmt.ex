defmodule Attmt do
  @moduledoc """
  Functionality revolving around attachments
  """

  @doc """
  Make sure the configuration relating to attachments is correct.
  Return a tuple of `{:ok, "all set!"}`, or `{:error, error_msg}`
  """
  def check_config(config) do
    atp = config["general"]["attachment-path"]
    case atp do
      nil -> {:error, "no attachment path defined"}
      _ ->
        atmts = config["attachments"]
        # check for attachment definition clashes first
        case atmts do
          nil -> {:error, "No attachments defined at all"}
          _ ->
            atdefs = Dict.values(atmts)
            counts = Enum.map(Enum.uniq(atdefs), fn x -> {x, 0} end)
              |> Enum.into(Map.new)
            dups = Enum.reduce(
              atdefs, counts, fn(m, cs) -> %{cs | m => cs[m]+1} end)
              |> Enum.filter(fn {_, v} -> v > 1 end)
              |> Dict.keys
              |> Enum.sort
            if Enum.empty?(dups) do
              if Dict.keys(atmts) === Dict.keys(config["recipients"]) do
                {:ok, "all set!"}
              else
                ats = Enum.into(Dict.keys(atmts), HashSet.new)
                rps = Enum.into(Dict.keys(config["recipients"]), HashSet.new)
                if Enum.count(ats) < Enum.count(rps) do
                  missing = Enum.join(Enum.sort(Set.difference(rps, ats)), ", ")
                  {:error, "No attachments defined for: #{missing}"}
                else
                  missing = Enum.join(Enum.sort(Set.difference(ats, rps)), ", ")
                  {:error, "Unlisted recipients: #{missing}"}
                end
              end
            else
              dups = Enum.join(dups, ", ")
              {:error, "Attachment(s) (#{dups}) used for more than one email"}
            end
        end
    end
  end


  @doc """
  Make sure all required attachment files exist and we can read them.
  Return a tuple of `{:ok, "all set!"}`, or `{:error, error_msg}`
  """
  def check_files(config) do
    atp = config["general"]["attachment-path"]
    case atp do
      nil -> {:error, "no attachment path defined"}
      _ ->
        case dir_readable?(atp) do
          false ->
            errmsg = "Missing or unreadable attachment path: #{atp}"
            {:error, errmsg}
          true ->
            case config["attachments"] do
              nil -> {:ok, "all set!"}
              afs ->
                missing = Enum.filter(Dict.values(afs), fn af ->
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
    failed = false
    error = nil
    do_encrypt = Cfg.convert_value(config["general"]["encrypt-attachments"])

    if do_encrypt == true do
      case GCrypto.check_keys(config) do
        {:ok, _} -> nil
        errordata ->
          failed = true
          error = errordata
      end
    end
    if not failed do
      case check_config(config) do
        {:ok, _} -> nil
        errordata ->
          failed = true
          error = errordata
      end
    end
    if not failed do
      case check_files(config) do
        {:ok, _} -> nil
        errordata ->
          failed = true
          error = errordata
      end
    end
    if (not failed) and do_encrypt do
      case encrypt_attachments(config) do
        {:ok, _} -> nil
        errordata ->
          failed = true
          error = errordata
      end
    end
    if not failed do
      {:ok, "all set!"}
    else
      error
    end
  end


  @doc """
  Encrypt the attachment files. Assume the config data is OK and all
  attachments are in place and readable.
  Return a tuple of `{:ok, "all set!"}`, or `{:error, error_msg}`
  """
  def encrypt_attachments(config, efunc \\ &GCrypto.encrypt/2) do
    atp = config["general"]["attachment-path"]
    errors = Enum.map(config["attachments"], fn {email, atf} ->
        case efunc.(atp <> "/" <> atf, email) do
          {:ok, _} -> nil
          {:error, {[errordata], _}} -> errordata
        end
      end)
    |> Enum.filter(fn x -> x != nil end)
    if Enum.count(errors) == 0 do
      {:ok, "all set!"}
    else
      {:error, Enum.join(errors, "\n")}
    end
  end
end
