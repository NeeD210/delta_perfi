defmodule PerfiDelta.Accounts.Cleanup do
  @moduledoc """
  Handles cleanup of stale data in the Accounts context.
  
  This module provides functions to:
  - Delete unconfirmed accounts older than a specified number of days
  - Clean up expired tokens
  """

  import Ecto.Query, warn: false
  alias PerfiDelta.Repo
  alias PerfiDelta.Accounts.{User, UserToken}

  @doc """
  Deletes all unconfirmed users that were created more than `days_old` days ago.
  
  Default is 7 days. This prevents the database from filling up with abandoned
  registrations and allows users to re-register with the same email if they
  never confirmed their account.
  
  ## Examples
  
      iex> delete_unconfirmed_users(days: 7)
      {5, nil}  # Deleted 5 unconfirmed users
      
  """
  def delete_unconfirmed_users(opts \\ []) do
    days = Keyword.get(opts, :days, 7)
    cutoff_date = DateTime.utc_now() |> DateTime.add(-days, :day)

    query =
      from u in User,
        where: is_nil(u.confirmed_at),
        where: u.inserted_at < ^cutoff_date

    Repo.delete_all(query)
  end

  @doc """
  Deletes expired tokens from the database.
  
  Tokens are considered expired based on their context:
  - "session" tokens: expire after 60 days
  - "login" tokens: expire after 7 days  
  - Email change tokens: expire after 7 days
  
  ## Examples
  
      iex> delete_expired_tokens()
      {23, nil}  # Deleted 23 expired tokens
      
  """
  def delete_expired_tokens do
    now = DateTime.utc_now()
    
    # Session tokens expire after 60 days
    session_cutoff = DateTime.add(now, -60, :day)
    
    # Login and email change tokens expire after 7 days
    email_cutoff = DateTime.add(now, -7, :day)

    session_query =
      from t in UserToken,
        where: t.context == "session",
        where: t.inserted_at < ^session_cutoff

    email_query =
      from t in UserToken,
        where: t.context in ["login", ^"change:"],
        where: t.inserted_at < ^email_cutoff

    {session_count, _} = Repo.delete_all(session_query)
    {email_count, _} = Repo.delete_all(email_query)

    {session_count + email_count, nil}
  end

  @doc """
  Runs all cleanup tasks.
  
  This is a convenience function that runs both user cleanup and token cleanup.
  Suitable for running as a periodic task (e.g., daily cron job).
  
  ## Examples
  
      iex> run_all_cleanup()
      %{users_deleted: 5, tokens_deleted: 23}
      
  """
  def run_all_cleanup(opts \\ []) do
    {users_deleted, _} = delete_unconfirmed_users(opts)
    {tokens_deleted, _} = delete_expired_tokens()

    %{
      users_deleted: users_deleted,
      tokens_deleted: tokens_deleted
    }
  end
end
