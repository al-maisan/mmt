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
          false -> {:error, "attachment path non-existent or not readable"}
          true ->
            case config["attachments"] do
              nil -> {:ok, "all set!"}
              afs ->
                missing = Enum.filter(Dict.values(afs), fn af ->
                  afp = atp <> "/" <> af
                  not file_readable?(afp) end)
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
