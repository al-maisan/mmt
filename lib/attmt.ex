defmodule Attmt do
  @moduledoc """
  Functionality revolving around attachments
  """

  @doc """
  Make sure
   * the configuration relating to attachments is correct
   * all required attachment files exist and we can read them
  Return a tuple of `{:ok, "all set!"}`, or `{:error, error_msg}`
  """
  def check_attachments(_config) do
  end


  @doc """
  Make sure the configuration relating to attachments is correct.
  Return a tuple of `{:ok, "all set!"}`, or `{:error, error_msg}`
  """
  def check_config(_config) do
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
end
