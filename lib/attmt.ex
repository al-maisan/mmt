defmodule Attmt do
  @moduledoc """
  Functionality revolving around attachments
  """

  @doc """
  Make sure
   * the configuration relating to attachments is correct
   * all required attachment files exists and we are authorised to read them
  Return a tuple of `{:ok, "all set!"}`, or `{:error, error_msg}`
  """
  def check_attachments(config) do
  end


  @doc """
  Make sure the configuration relating to attachments is correct
  Return a tuple of `{:ok, "all set!"}`, or `{:error, error_msg}`
  """
  def check_config(config) do
  end


  @doc """
  Make sure all required attachment files exists and we are authorised
  to read them.
  Return a tuple of `{:ok, "all set!"}`, or `{:error, error_msg}`
  """
  def check_files(config) do
  end
end
