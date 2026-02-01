defmodule Mix.Tasks.Accounts.Cleanup do
  @moduledoc """
  Task to clean up stale accounts and tokens.
  
  This task should be run periodically (e.g., daily) to:
  - Delete unconfirmed accounts older than 7 days
  - Delete expired tokens
  
  ## Usage
  
      # Clean up with default settings (7 days)
      mix accounts.cleanup
      
      # Clean up unconfirmed accounts older than 30 days
      mix accounts.cleanup --days 30
      
  ## Scheduling
  
  You can schedule this task to run automatically:
  
  ### On Linux/Mac (cron):
  
      # Run daily at 3 AM
      0 3 * * * cd /path/to/app && mix accounts.cleanup
      
  ### On Windows (Task Scheduler):
  
      Create a scheduled task that runs:
      mix accounts.cleanup
      
  ### On Production (Quantum or Oban):
  
  Add to your scheduler configuration to run this automatically.
  """

  use Mix.Task

  alias PerfiDelta.Accounts.Cleanup

  @requirements ["app.start"]

  @impl Mix.Task
  def run(args) do
    {opts, _, _} = OptionParser.parse(args, strict: [days: :integer])

    Mix.shell().info("Starting accounts cleanup...")

    result = Cleanup.run_all_cleanup(opts)

    Mix.shell().info("✓ Deleted #{result.users_deleted} unconfirmed users")
    Mix.shell().info("✓ Deleted #{result.tokens_deleted} expired tokens")
    Mix.shell().info("Cleanup completed successfully!")
  end
end
