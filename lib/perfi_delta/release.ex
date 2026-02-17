defmodule PerfiDelta.Release do
  @moduledoc """
  Used for executing DB release tasks when run in production without Mix installed.
  """
  @app :perfi_delta

  require Logger

  def migrate do
    # Explicitly start dependencies
    Application.ensure_all_started(:ssl)
    Application.ensure_all_started(:postgrex)
    Application.ensure_all_started(:ecto_sql)

    load_app()

    for repo <- repos() do
      path = Application.app_dir(:perfi_delta, "priv/repo/migrations")
      Logger.info("Running migrations from path: #{path}")

      if File.exists?(path) do
        Logger.info("Migration path exists. Files:")
        case File.ls(path) do
          {:ok, files} -> Enum.each(files, &Logger.info(" - #{&1}"))
          {:error, reason} -> Logger.error("Failed to list files in #{path}: #{inspect(reason)}")
        end
      else
        Logger.error("Migration path does NOT exist: #{path}")
        # Try to list the priv directory to see what's there
        priv_path = Application.app_dir(:perfi_delta, "priv")
        Logger.info("Listing priv directory #{priv_path}:")
        case File.ls(priv_path) do
           {:ok, files} -> Enum.each(files, &Logger.info(" - #{&1}"))
           {:error, reason} -> Logger.error("Failed to list priv: #{inspect(reason)}")
        end
      end

      {:ok, _, _} = Ecto.Migrator.with_repo(repo, &Ecto.Migrator.run(&1, path, :up, all: true))
    end
  end

  def rollback(repo, version) do
    load_app()
    {:ok, _, _} = Ecto.Migrator.with_repo(repo, &Ecto.Migrator.run(&1, :down, to: version))
  end

  defp repos do
    Application.fetch_env!(@app, :ecto_repos)
  end

  defp load_app do
    Application.load(@app)
  end
end
